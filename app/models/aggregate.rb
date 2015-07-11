# -*- encoding : utf-8 -*-
class Aggregate < ActiveRecord::Base
  attr_protected

  extend UniversalHelpers
  belongs_to :user
  belongs_to :reseller, class_name: 'User', foreign_key: 'reseller_id'
  belongs_to :time_period
  has_one :destinationgroup

  def self.find_aggregates(start_time, end_time)
    one_second = 1.second
    cond = []
    valid_time_interval = start_time < end_time

    # --------- Hours ---------
    if valid_time_interval
      start_time_hour = start_time.hour.to_i
      end_time_hour = end_time.hour.to_i

      if start_time_hour > 0
        missing_hours = start_time + (24 - start_time_hour).hour
        hours_from_start = start_time
        hours_from_end = missing_hours - one_second
        start_time = missing_hours
      else
        hours_from_start, hours_from_end = start_time, start_time
      end

      if hours_from_end < end_time
        if end_time_hour < 23
          missing_hours = end_time - (end_time_hour + 1).hour
          hours_till_start = missing_hours + one_second
          hours_till_end = end_time
          end_time = missing_hours
        else
          hours_till_start, hours_till_end = end_time, end_time
        end

        if hours_from_start < hours_from_end
          cond << "(time_periods.period_type = 'hour' AND time_periods.from_date BETWEEN '#{hours_from_start}' AND '#{hours_from_end}')"
        end

        if hours_till_start < hours_till_end
          cond << "(time_periods.period_type = 'hour' AND time_periods.from_date BETWEEN '#{hours_till_start}' AND '#{hours_till_end}')"
        end
      else
        cond << "time_periods.period_type = 'hour' AND time_periods.from_date BETWEEN '#{hours_from_start}' AND '#{end_time}'"
      end

      # --------- Days ---------

      start_time_day = start_time.day.to_i
      end_time_day = end_time.day.to_i

      if start_time_day > 1
        missing_days = start_time + (start_time.end_of_month.day - start_time_day + 1).day
        days_from_start = start_time
        days_from_end = missing_days - one_second
        start_time = missing_days
      else
        days_from_start, days_from_end = start_time, start_time
      end

      if days_from_end < end_time
        if end_time_day < end_time.end_of_month.day
          missing_days = end_time - end_time_day.day
          days_till_start = missing_days + one_second
          days_till_end = end_time
          end_time = missing_days
        else
          days_till_start, days_till_end = end_time, end_time
        end

        if days_from_start < days_from_end
          cond << "(time_periods.period_type = 'day' AND time_periods.from_date BETWEEN '#{days_from_start}' AND '#{days_from_end}')"
        end

        if days_till_start < days_till_end
          cond << "(time_periods.period_type = 'day' AND time_periods.from_date BETWEEN '#{days_till_start}' AND '#{days_till_end}')"
        end
      else
        cond << "time_periods.period_type = 'day' AND time_periods.from_date BETWEEN '#{days_from_start}' AND '#{end_time}'"
      end

      # --------- Months ---------

      if start_time < end_time
        cond << "(time_periods.period_type = 'month' AND time_periods.from_date BETWEEN '#{start_time}' AND '#{end_time}')"
      end
    end
    cond
  end

  def self.agregate_order_by(options)
    opt_order_by = options[:order_by].to_s

    case opt_order_by
    when 'direction'
      order_by = 'aggregates.direction'
    when 'originator'
      order_by = 'nice_user'
    when 'terminator'
      order_by = 'terminators.name'
    when 'billed_orig'
      order_by = 'user_billed'
    when 'billed_orig_with_tax'
      order_by = 'user_billed_with_tax'
    when 'billed_term'
      order_by = 'terminator_billed'
    when 'billsec_orig'
      order_by = 'user_billed_billsec'
    when 'billsec_term'
      order_by = 'terminator_billed_billsec'
    when 'duration'
      order_by = 'billsec'
    when 'answered_calls'
      order_by = 'answered_calls'
    when 'prefix'
      order_by = 'prefix'
    when 'total_calls'
      order_by = 'total_calls'
    when 'asr'
      order_by = 'asr'
    when 'acd'
      order_by = 'acd'
    end
    order_desc = options[:order_desc]
    if order_by != ''
      order_by += ' ASC' if order_desc == 0
      order_by += ' DESC' if order_desc == 1
    end

    if opt_order_by == 'direction'
      order_by += ', aggregates.prefix ASC'
    end

    return order_by
  end

  def self.country_stats(options={}, current_user)
    reseller = (current_user.usertype == 'reseller')
    user_id, start_time, end_time, order_by = options[:user_id], options[:start], options[:end], options[:order_by]
    where_sentence = ['variation = 7']
    where_sentence << "aggregates.user_id = #{user_id}" if user_id && user_id != -1
    where_sentence << "(#{find_aggregates(start_time, end_time).join(' OR ')})" if start_time && end_time
    where_sentence << "(users.owner_id = #{current_user.id})" if reseller
    where_sentence = where_sentence.join(' AND ')

    filltered_aggregates = self.where(where_sentence).joins(:time_period).
        joins('JOIN destinations ON aggregates.prefix = destinations.prefix').
        joins('JOIN destinationgroups ON destinations.destinationgroup_id = destinationgroups.id')

    if reseller
      filltered_aggregates = filltered_aggregates.joins('JOIN users ON users.id = aggregates.user_id')
    end

    # select aggregates and destnations that fullfil search requirements
    aggregates = filltered_aggregates.select('
      aggregates.direction AS Direction, destinationgroups.desttype AS type,
      SUM(answered_calls) AS Calls, SUM(billsec) AS Time, Flag,
      SUM(terminator_billed) AS Price, SUM(user_billed) AS User_price,
      SUM((user_billed - terminator_billed)) AS Profit, aggregates.id
    ').group('Direction')

    if order_by
      type = (options[:order_desc].to_i == 1) ? 'DESC' : 'ASC'
      aggregates = aggregates.order(order_by  + ' ' + type)
    end

    # totals will be sums of all what is found
    totals = filltered_aggregates.select('
      SUM(answered_calls) AS Calls, SUM(billsec) AS Time, Flag,
      SUM(terminator_billed) AS Price, SUM(user_billed) AS User_price,
      SUM((user_billed - terminator_billed)) AS Profit
    ').first

    # splited in methods because reek is angry about code written in one method
    pies = find_pies(filltered_aggregates, totals)

    aggregates = format_aggregates(aggregates)

    return aggregates, totals, pies
  end


  private

  def self.format_aggregates(aggregates)
    aggregates.each do |call|
      call.Time = nice_time(call.Time)
      call.Price = Application.nice_number(call.Price)
      call.User_price = Application.nice_number(call.User_price)
      call.Profit = Application.nice_number(call.Profit)
    end
  end

  def self.find_pies(aggregates, totals)
    income = aggregates.select('Direction, SUM(user_billed) AS sum').group('Direction').order('sum DESC').limit(5).all
    profit = aggregates.select('Direction, SUM((user_billed - terminator_billed)) AS sum').group('Direction').order('sum DESC').limit(5).all
    time = aggregates.select('Direction, SUM(billsec) AS sum').group('Direction').order('sum DESC').limit(5).all

    pies = {}
    pies[:time] = find_pie(time, totals.Time)
    pies[:profit] = find_pie(profit, totals.Profit)
    pies[:income] = find_pie(income, totals.User_price)
    pies
  end

  def self.find_pie(aggregate, total_count)
    output = ""; all = 0;
    if aggregate.count > 0
      aggregate.each_with_index do |group, index|
        pull = (index == 1) ? 'true' : 'false'
        data = group.sum.to_d
        output += group.Direction + ';' + (Application.nice_number(data)).to_s + ";" + pull + "\\n"
        all += data
      end
      others = total_count.to_d - all
      output += _('Others') + ";" + Application.nice_number(others).to_s + ";false\\n" if others > 0
    else
      output += _('No_result') + ";1;false\\n"
    end
    '"' + output + '"'
  end

  def self.country_stats_csv(aggreagates, sep)
    # making headers for csv
    lines = []
    lines << find_country_stats_header(sep)

    # making csv values
    aggreagates.each do |aggregate|
      lines << find_country_stats_line(aggregate, sep)
    end

    # return csv_string
    lines = lines
    return lines
  end

  def self.find_country_stats_header(sep)
    line = []
    ['Direction', 'Type', 'Calls', 'Time', 'Price', 'User_price', 'Profit'].each do |key|
      line << _(key)
    end
    line
  end

  # splitted into methods, because reek doesn't like nested iterators
  def self.find_country_stats_line(aggregate, sep)
    line = []
    aggregate.attributes.each do |key, value|
      # nice_time method for billsecs
      next if ['id', 'Flag'].include?(key)
      #value = nice_time(value) if key == 'Time'
      line << value
    end
    line
  end
end