# -*- encoding : utf-8 -*-
class Stat < ActiveRecord::Base
  attr_protected

  def self.find_rates_and_tariffs_by_number(user_id, id, phrase, user_tariff_id = '')
    tariff_clause = user_tariff_id.present? ? " AND tariffs.id = #{user_tariff_id}" : ''
    sql = 'SELECT * FROM (SELECT tariffs.name AS tariffs_name, tariffs.purpose, tariffs.currency, tariffs.id AS tariffs_id, ' +
          'ratedetails.start_time, ratedetails.end_time, ratedetails.rate, ' +
          'destinations.prefix, destinations.direction_code, destinations.subcode, destinations.name, ' +
          'aratedetails.price, aratedetails.start_time AS arate_start_time, aratedetails.end_time AS arate_end_time, ' +
          'rates.id AS rate_id, rates.effective_from AS effective_from, ' +
          'IF(IFNULL(rates.effective_from, 0) = rates2.max_effective_from, 1, 0) AS active, ' +
          'ratedetails.id AS ratedetails_id, aratedetails.daytype AS arate_daytype ' +
          'FROM rates ' +
          'LEFT OUTER JOIN tariffs ON tariffs.id = rates.tariff_id ' +
          'LEFT OUTER JOIN ratedetails ON ratedetails.rate_id = rates.id ' +
          'LEFT OUTER JOIN aratedetails ON aratedetails.rate_id = rates.id ' +
          'LEFT OUTER JOIN destinations ON ' +
          '(destinations.id = rates.destination_id OR destinations.destinationgroup_id = rates.destinationgroup_id) ' +
          "AND destinations.prefix IN (#{phrase.join(",")}) " +
          'LEFT JOIN ' +
           '(SELECT rates.tariff_id, rates.destination_id, ' +
           'IFNULL(MAX(rates.effective_from), 0) AS max_effective_from ' +
           'FROM rates ' +
           'WHERE (rates.effective_from < now() OR rates.effective_from IS NULL) ' +
           'GROUP BY rates.tariff_id, rates.destination_id) ' +
           'rates2 ON (rates2.tariff_id = rates.tariff_id AND rates.destination_id = rates2.destination_id) ' +
          'WHERE ( ' +
          "(rates.destination_id IN (#{id.join(",")}) OR rates.destinationgroup_id IN " +
          "(SELECT destinationgroup_id FROM destinations WHERE id IN (#{id.join(",")}))) " +
          "AND tariffs.owner_id = #{user_id}#{tariff_clause}) ORDER BY LENGTH(prefix) DESC) AS v " +
          'ORDER BY purpose ASC, effective_from DESC'
    ActiveRecord::Base.connection.select_all(sql)
  end

  def self.find_sql_conditions_for_profit(reseller, session_user_id, user_id, responsible_accountant_id, session_from_datetime, session_till_datetime, up, pp)
    conditions, cond_did_owner_cost, user_sql2 = [[], [], '']
    user_id_not_equal_minus_one = (user_id.to_i != -1)

    if reseller
      conditions << "calls.reseller_id = #{session_user_id}"

      if user_id_not_equal_minus_one
        conditions << "calls.user_id = '#{user_id}'"
      end

      cond_did_owner_cost << conditions
    else
      if user_id && user_id_not_equal_minus_one
        conditions << "calls.user_id IN (SELECT id FROM users WHERE id = '#{user_id}' OR owner_id = #{user_id})"
        cond_did_owner_cost << "calls.dst_user_id IN (SELECT id FROM users WHERE id = '#{user_id}' OR owner_id = #{user_id})"
        user_sql2 = " AND subscriptions.user_id = '#{user_id}' "
      elsif responsible_accountant_id.to_s != "-1"
        conditions << "calls.user_id IN (SELECT id FROM users WHERE id IN " +
                      "(SELECT users.id FROM `users` JOIN users tmp ON(tmp.id = users.responsible_accountant_id) " +
                      "WHERE tmp.id = '#{responsible_accountant_id}') OR owner_id IN (SELECT users.id FROM `users` " +
                      "JOIN users tmp ON(tmp.id = users.responsible_accountant_id) " +
                      "WHERE tmp.id = '#{responsible_accountant_id}'))"
        cond_did_owner_cost << "calls.dst_user_id IN (SELECT id FROM users WHERE id IN " +
                      "(SELECT users.id FROM `users` JOIN users tmp ON(tmp.id = users.responsible_accountant_id) " +
                      "WHERE tmp.id = '#{responsible_accountant_id}') OR owner_id IN (SELECT users.id FROM `users` " +
                      "JOIN users tmp ON(tmp.id = users.responsible_accountant_id) " +
                      "WHERE tmp.id = '#{responsible_accountant_id}'))"
        user_sql2 = " AND subscriptions.user_id IN (SELECT users.id FROM `users` JOIN users tmp " +
                    "ON(tmp.id = users.responsible_accountant_id) WHERE tmp.id = '#{responsible_accountant_id}')"
      end
    end

    conditions << "calls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'"
    cond_did_owner_cost << "calls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'"
    select = ["SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) AS 'billsec'"]
    select += [SqlExport.replace_price("SUM(#{up})", {:reference => 'user_price'}), SqlExport.replace_price("SUM(#{pp})", {:reference => 'provider_price'})]
    select += ["SUM(calls.did_prov_price) AS 'did_prov_price'"]

    if reseller
      conditions << "calls.reseller_id = #{session_user_id}"
      cond_did_owner_cost << "calls.reseller_id = #{session_user_id}"
    end

    return conditions, cond_did_owner_cost, user_sql2, select
  end

  def self.find_services_for_profit(reseller, a1, a2, user_sql2)
    if !reseller
      price = 0
      sql = "SELECT users.id, subscriptions.*, " +
            "COUNT(calls.id) AS calls_size, services.servicetype, services.periodtype, services.quantity, " +
            "#{SqlExport.replace_price('(services.price - services.selfcost_price)', {:reference => 'price'})} " +
            "FROM subscriptions left join calls ON (calls.user_id = subscriptions.user_id) " +
            "JOIN services ON (services.id = subscriptions.service_id) " +
            "JOIN users ON (users.id = subscriptions.user_id) " +
            "WHERE ((activation_start < '#{a1}' AND (activation_end > '#{a1}' OR activation_end IS NULL)) OR " +
            "(activation_start BETWEEN '#{a1}' AND '#{a2}' AND (activation_end >'#{a1}' OR activation_end IS NULL)))" +
            "#{user_sql2} group by subscriptions.id"
      res = ActiveRecord::Base.connection.select_all(sql)
    else
      res = []
    end

    return res
  end

  def self.find_subs_params(res, a1, a2, sub_price)
    if res and res.size > 0
      res.each do |r|
        activation_start = r['activation_start']
        activation_start_to_date = r['activation_start'].to_date
        activation_end = r['activation_end']
        activation_end_to_date = r['activation_end'].try(:to_date)
        periodtype = r['periodtype'].to_s
        periodtype_is_day = (periodtype == 'day')
        periodtype_is_month = (periodtype == 'month')
        servicetype = r['servicetype'].to_s
        r_price = r['price'].to_d
        quantity_to_dec = r['quantity'].to_d
        price = 0

        if !activation_end_to_date.blank? && (activation_start_to_date > a1.to_date) && (activation_end_to_date < a2.to_date)
          sub_days = Stat.find_sub_days(activation_start, activation_end)
          price = Stat.find_price_if_day(price, sub_days, servicetype, r_price, quantity_to_dec) if periodtype_is_day
          price = Stat.find_price_if_month(price, servicetype, r_price, activation_start, activation_end, quantity_to_dec) if periodtype_is_month
        else
          use_start = (activation_start_to_date <= a1.to_date) ? a1.to_date : activation_start_to_date
          use_end = (activation_end_to_date.blank? || activation_end_to_date >= a2.to_date) ? a2.to_date : activation_end_to_date

          sub_days = Stat.find_sub_days(use_start, use_end)
          price = Stat.find_price_if_day(price, sub_days, servicetype, r_price, quantity_to_dec) if periodtype_is_day
          price = Stat.find_price_if_month(price, servicetype, r_price, use_start, use_end, quantity_to_dec) if periodtype_is_month
        end
        sub_price += price.to_d
      end
    end

    return sub_price
  end

  def self.find_price_if_day(price, sub_days, servicetype, r_price, quantity_to_dec)
    quantity = sub_days / quantity_to_dec
    days = sub_days % quantity_to_dec

    price = (r_price * quantity.to_i) if servicetype == 'activation_from_registration'
    price = r_price if servicetype == 'one_time_fee'
    price = ((r_price / quantity_to_dec) * days.to_i).to_d + ((r_price * quantity.to_d)).to_d if ((servicetype == 'periodic_fee') || (servicetype == 'flat_rate'))

    return price
  end

  def self.find_price_if_month(price, servicetype, r_price, activation_start, activation_end, quantity_to_dec)
    y = activation_end.to_time.year - activation_start.to_time.year
    m = activation_end.to_time.month - activation_start.to_time.month
    months = y.to_i * 12 + m.to_i
    quantity = months / quantity_to_dec
    days = (activation_end.to_time.day - activation_start.to_time.day) + 1

    price = r_price * quantity.to_i if servicetype == 'activation_from_registration'
    price = r_price if servicetype == 'one_time_fee'

    if (servicetype == 'periodic_fee') || (servicetype == 'flat_rate')
      if days < 0
        quantity = quantity - 1
        days = activation_start.to_time.day + days
      end

      price = ((r_price / activation_end.to_time.end_of_month().day.to_i.to_d) * days.to_i).to_d + ((r_price * quantity.to_d)).to_d
    end

    return price
  end

  def self.find_sub_days(sub_start, sub_end)
    sub_days = sub_end.to_time - sub_start.to_time
    sub_days = (((sub_days / 60) / 60) / 24)

    return sub_days
  end
end
