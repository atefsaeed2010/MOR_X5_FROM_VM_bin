# -*- encoding : utf-8 -*-
class Tariff < ActiveRecord::Base
  include CsvImportDb
  attr_protected

  has_many :rates
  has_many :providers
  has_many :users
  has_many :cardgroups
  has_many :common_use_providers
  has_many :locationrules
  has_many :origination_points, class_name: 'Device', foreign_key: 'op_tariff_id'
  has_many :termination_points, class_name: 'Device', foreign_key: 'tp_tariff_id'
  belongs_to :owner, class_name: 'User'

  validates_uniqueness_of :name, :message => _('Name_must_be_unique'), :scope => [:owner_id]
  validates_presence_of :name, :message => _('Name_cannot_be_blank')
  after_create :update_time

  def real_currency
    Currency.where(['name = ?', self.currency]).first
  end

  # select rates by their countries (directions) first letter for easier management
  def rates_by_st(st, per_page, prefix_cond)
    select = 'rates.id, rates.tariff_id, rates.destination_id, destinations.direction_code, prefix, city, state, ' +
             'lata, subcode, tier, ocn, destinations.name as destination_name'

    Rate.select(select)
        .from('destinations, rates, directions')
        .where(['rates.tariff_id = ? AND destinations.id = rates.destination_id', self.id])
        .where(['directions.code = destinations.direction_code AND directions.name like ?', st.to_s + '%'])
        .where(prefix_cond)
        .group('rates.id')
        .order('directions.name ASC, destinations.prefix ASC')
        .limit(per_page.to_s)
  end

  # destinations which have rate assigned for this tariff
  def destinations
    Destination.select('destinations.*')
    .from('destinations, tariffs, rates, directions')
    .where(['rates.tariff_id = ? AND destinations.id = rates.destination_id', self.id])
    .group('destinations.id')
    .order('destinations.prefix ASC')
  end

  # destinations which haven't rate assigned for this tariff by first letter
  def free_destinations_by_st(st, limit = nil, offset = 0)
    st = st.to_s
    destination_ids = self.destinations.where("directions.name like '#{st}%'").collect(&:id)

    query = Destination.select('destinations.*')
    .joins('JOIN directions ON (directions.code = destinations.direction_code)')
    .where("directions.name like '#{st}%'")

    query = query.where("destinations.id NOT IN (#{destination_ids.join(',')})") unless destination_ids.blank?

    adests = query.order('directions.name ASC, destinations.prefix ASC')
    .limit(limit || 1000000)
    .offset(offset).all

    actual_adest_count = query.count
    limit ? [adests, actual_adest_count] : adests
  end

=begin rdoc
  Returns destinations that have no assigned rates.

 *Params*:

 +direction+ - Direction, or Direction.id

 *Flash*:

 +notice+ - messages that are passed through flash[:notice]

 *Redirect*

 +action+ - where action redirects
=end

  def free_destinations_by_direction(direction, options ={})
    destinations = []
    extra = {}
    extra[:limit] = options[:limit].to_i if options[:limit] and options[:limit].to_i
    extra[:offset] = options[:offset].to_i if options[:offset] and options[:offset].to_i
    if direction.class == String
      destinations = Destination.select("destinations.*, directions.code AS 'dir_code', directions.name AS 'dir_name' ").
          joins("LEFT JOIN directions ON (directions.code = destinations.direction_code) LEFT JOIN (SELECT * FROM rates where tariff_id = #{self.id}) as rates  ON (rates.destination_id = destinations.id)").
          where(["destinations.direction_code = ? AND rates.id IS NULL", code])
      if extra.size == 2
        destinations = destinations.limit(extra[:limit]).offset(extra[:offset]).all
      elsif extra[:limit].present?
        destinations = destinations.limit(extra[:limit]).all
      elsif extra[:offset].present?
        destinations = destinations.offset(extra[:offset]).all
      else
        destinations = destinations.all
      end
    end
    if direction.class == Direction
      destinations = Destination.select("destinations.*, directions.code AS 'dir_code', directions.name AS 'dir_name' ").
          joins("LEFT JOIN directions ON (directions.code = destinations.direction_code) LEFT JOIN (SELECT * FROM rates where tariff_id = #{self.id}) as rates  ON (rates.destination_id = destinations.id)").
          where(["destinations.direction_code = ? AND rates.id IS NULL", direction.code])
      if extra.size == 2
        destinations = destinations.limit(extra[:limit]).offset(extra[:offset]).all
      elsif extra[:limit].present?
        destinations = destinations.limit(extra[:limit]).all
      elsif extra[:offset].present?
        destinations = destinations.offset(extra[:offset]).all
      else
        destinations = destinations.all
      end
    end
    options[:with_count] == true
    destinations
  end

  def add_new_rate(dest_id, rate_value, increment, min_time, connection_fee, ghost_percent = nil)
    success = false
    rate = Rate.new
    rate.tariff_id = self.id
    rate.destination_id = dest_id
    rate.ghost_min_perc = ghost_percent

    rate_det = Ratedetail.new
    rate_det.rate = rate_value.to_d
    rate_det.increment_s = increment.to_i < 1 ? 1 : increment.to_i
    rate_det.min_time = min_time.to_i < 0 ? 0 : min_time.to_i
    rate_det.connection_fee = connection_fee.to_d

    rate.ratedetails << rate_det

    if rate.save
      self.last_update_date = Time.now
      self.save
      success = true
    end
    success
  end


  def delete_all_rates

    if purpose != 'user'
      sql = "DELETE ratedetails, rates FROM ratedetails, rates WHERE ratedetails.rate_id = rates.id AND rates.tariff_id = '#{self.id.to_s}'"
      res = ActiveRecord::Base.connection.execute(sql)

      #just in case  - sometimes helps after crashed rate import from CSV file
      sql = "DELETE FROM rates WHERE rates.tariff_id = '#{self.id.to_s}'"
      res = ActiveRecord::Base.connection.execute(sql)
    else
      sql = "DELETE aratedetails, rates FROM aratedetails, rates WHERE aratedetails.rate_id = rates.id AND rates.tariff_id = '#{self.id.to_s}'"
      res = ActiveRecord::Base.connection.execute(sql)

      #just in case  - sometimes helps after crashed rate import from CSV file
      sql = "DELETE FROM rates WHERE rates.tariff_id = '#{self.id.to_s}'"
      res = ActiveRecord::Base.connection.execute(sql)
    end

    #      for rate in self.rates
    #        rate.destroy_everything
    #      end
  end


  def exchange_rate(cur = nil)
    if cur
      Currency.count_exchange_rate(cur, currency)
    else
      sql = "SELECT exchange_rate FROM currencies, tariffs WHERE currencies.name = tariffs.currency AND tariffs.id = '#{self.id}'"
      res = ActiveRecord::Base.connection.select_one(sql)
      res["exchange_rate"].to_d
    end
  end

  def make_wholesale_tariff(amount = 0, percent = 0, fee_amount = 0, fee_percent = 0, type = "provider")
    tname = "#{self.name}"
    tname += " + #{amount}" if amount
    tname += " + #{percent}%" if percent

    amount = amount.to_d
    percent = percent.to_d
    fee_amount = fee_amount.to_d
    fee_percent = fee_percent.to_d

    utariff = Tariff.new
    utariff.name = tname
    utariff.purpose = type
    utariff.currency = self.currency
    utariff.owner_id = self.owner_id

    Tariff.transaction do
      if utariff.save
        new_tariff_id = utariff.id

        count_details = 0
        ratedetails_sql = []
        rates_sql = "SELECT ratedetails.id, ratedetails.end_time, ratedetails.start_time, ratedetails.rate, ratedetails.connection_fee, ratedetails.rate_id, ratedetails.increment_s, ratedetails.min_time, ratedetails.daytype, rates.id, rates.tariff_id, rates.destination_id, rates.effective_from FROM ratedetails LEFT join rates ON (rates.id = ratedetails.rate_id) WHERE rates.tariff_id = #{self.id};"
        rates_array = ActiveRecord::Base.connection.execute(rates_sql)
        rates = {}
        rates_array.each { |line|
          rates[line[9]] = ActiveRecord::Base.connection.insert("INSERT INTO rates (`tariff_id`, `destination_id`, `destinationgroup_id`, `effective_from`) VALUES(#{new_tariff_id}, #{line[11]}, NULL, '#{line[12]}')").to_i if !rates[line[9]]

          # THIS WILL HELP TO FIND CORRECT LINES rd = {:id => line[0], :start_time => line[2], :end_time => line[1] , :rate  => line[3] , :connection_fee => line[4] , :rate_id  => line[5] , :increment_s => line[6] , :min_time => line[7] , :daytype => line[8], :effective_from => line[12]}
          connection_fee= line[4].to_d
          connection_fee += fee_amount
          connection_fee += connection_fee*fee_percent/100

          price = line[3].to_d
          price += amount
          price += price*percent/100
          count_details += 1
          ratedetails_sql << "'#{line[2].strftime("%Y%m%d%H%M%S")}','#{line[1].strftime("%Y%m%d%H%M%S")}', #{line[6]}, '#{line[8]}', #{price}, #{rates[line[9]]}, #{line[7]}, #{connection_fee}"
          if count_details > 2000
            ActiveRecord::Base.connection.insert("INSERT INTO ratedetails (`start_time`, `end_time`, `increment_s`, `daytype`, `rate`, `rate_id`, `min_time`, `connection_fee`) VALUES(#{ratedetails_sql.join("),(")})")
            count_details = 0
            ratedetails_sql = []
          end
        }
        ActiveRecord::Base.connection.insert("INSERT INTO ratedetails (`start_time`, `end_time`, `increment_s`, `daytype`, `rate`, `rate_id`, `min_time`, `connection_fee`) VALUES(#{ratedetails_sql.join("),(")})") if count_details > 0
      else
        return false
      end
    end
    return utariff
  end

=begin rdoc
  Makes new retail tariff from existing one.

  *Params*

  +amount+ - amount to add to rate price.
  +percent+ - amount to add to rate in percents.
  +fee_amount+ - amount to add to conncetion fee price.
  +fee_percent+ - amount to add to connection fee in percents.
  +owner+ - owner of new tariff.
=end

  def make_retail_tariff(amount = 0, percent = 0, fee_amount = 0, fee_percent = 0, owner = 0)
    trates = 0 # total_rates
    insert_header = "INSERT INTO aratedetails (`duration`, `price`, `end_time`, `from`, `artype`, `rate_id`, `round`, `start_time`)"
    tariff = Tariff.new
    Tariff.transaction do
      tname = "#{self.name}"
      tname += " + #{amount}" if amount != 0
      tname += " + #{percent}%" if percent != 0

      tariff.name = tname
      tariff.purpose = 'user'
      tariff.currency = self.currency
      tariff.owner_id = owner
      if tariff.save
        count_details = 0
        ratedetails_sql = []
        ActiveRecord::Base.connection.execute("DROP TEMPORARY TABLE IF EXISTS tmp_dest_groups;")

        sql = "CREATE TEMPORARY TABLE tmp_dest_groups SELECT destinations.destinationgroup_id AS id,
                                                             MAX(rate) AS rate
                                                      FROM destinations
                                                      JOIN rates ON (destinations.id = rates.destination_id)
                                                      JOIN ratedetails ON (ratedetails.rate_id = rates.id)
                                                      WHERE rates.tariff_id = #{self.id}
                                                            AND ratedetails.rate = (SELECT r.rate
                                                                                    FROM ratedetails AS r
                                                                                    WHERE rates.id = r.rate_id
                                                                                          AND (rates.effective_from <= NOW() OR rates.effective_from IS NULL)
                                                                                    ORDER BY rates.effective_from DESC, r.rate DESC LIMIT 1
                                                                                    )
                                                      GROUP BY destinations.destinationgroup_id;"
        res = ActiveRecord::Base.connection.execute(sql)

        sql = "create index tmp_id_index on tmp_dest_groups(id)"
        res = ActiveRecord::Base.connection.execute(sql)

        sql = "SELECT destinationgroups.id,
                      rates.destination_id,
                      rates.tariff_id,
                      ratedetails.rate,
                      ratedetails.increment_s,
                      ratedetails.connection_fee,
                      destinations.destinationgroup_id,
                      ratedetails.min_time,
                      rates.effective_from
               FROM destinationgroups
               JOIN destinations ON (destinations.destinationgroup_id = destinationgroups.id)
               JOIN rates ON (destinations.id = rates.destination_id)
               JOIN ratedetails ON (ratedetails.rate_id = rates.id)
               JOIN tmp_dest_groups ON (tmp_dest_groups.id = destinationgroups.id)
               WHERE rates.tariff_id = #{self.id}
                     AND tmp_dest_groups.rate = ratedetails.rate
               GROUP BY destinationgroups.id;"
        res = ActiveRecord::Base.connection.execute(sql)

        ActiveRecord::Base.connection.execute("DROP TEMPORARY TABLE IF EXISTS tmp_dest_groups;")

        res.each { |line|
          trates += 1
          new_rate = line[3].to_d
          new_increment = line[4].to_d
          new_connfee = line[5].to_d
          min_time = line[7].to_d

          new_rate += amount.to_d
          new_rate += new_rate/100 * percent.to_d
          new_rate = new_rate.round(15)

          new_connfee += fee_amount.to_d
          new_connfee += new_connfee/100 * fee_percent.to_d
          new_connfee = new_connfee.round(15)


          # `duration`, `price`, `end_time`, `from`, `artype`, `rate_id`, `round`, `start_time`
          rate_id = ActiveRecord::Base.connection.insert("INSERT INTO rates (`tariff_id`, `destination_id`, `destinationgroup_id`, `effective_from`) VALUES(#{tariff.id}, #{line[2]}, #{line[0]}, '#{line[8]}')").to_i

          if new_connfee != 0
            count_details += 1
            ratedetails_sql << "0, #{new_connfee}, '23:59:59', 1, 'event', #{rate_id}, 0, '00:00:00'"
          end

          if min_time != 0
            count_details += 1
            ratedetails_sql << "#{min_time}, #{new_rate}, '23:59:59', 1, 'minute', #{rate_id}, #{min_time}, '00:00:00'"
          end

          count_details += 1
          ratedetails_sql << "-1, #{new_rate}, '23:59:59', #{min_time + 1}, 'minute', #{rate_id}, #{new_increment}, '00:00:00'"
          if count_details > 2000
            #           "INSERT INTO aratedetails (`duration`, `price`, `end_time`, `from`, `artype`, `rate_id`, `round`, `start_time`)"
            ActiveRecord::Base.connection.insert("#{insert_header} VALUES (#{ratedetails_sql.join("),(")})")
            count_details = 0
            ratedetails_sql = []
          end
        }
        ActiveRecord::Base.connection.insert("#{insert_header} VALUES (#{ratedetails_sql.join("),(")})") if count_details > 0
      else
        return false
      end
    end
    return trates
  end

  def generate_user_rates_csv(session)
    sql = "SELECT rates.* FROM rates
            LEFT JOIN destinationgroups on (destinationgroups.id = rates.destinationgroup_id)
            WHERE rates.tariff_id ='#{id}'
            ORDER BY destinationgroups.name, destinationgroups.desttype ASC"
    rates = Rate.find_by_sql(sql)
    sep = Confline.get_value("CSV_Separator").to_s
    dec = Confline.get_value("CSV_Decimal").to_s


    csv_string = _('Destination') + sep + _('Subcode') + sep + _("Rate")+"("+session[:show_currency].to_s+")"+sep+_('Round') + "\n"

    exrate = Currency.count_exchange_rate(self.currency, session[:show_currency])
    for rate in rates
      arate_details, arate_cur = get_user_rate_details(rate, exrate)
      csv_string += !rate.destinationgroup ? "0#{sep}0#{sep}" : "#{rate.destinationgroup.name.to_s.gsub(sep, " ")}#{sep}#{rate.destinationgroup.desttype}#{sep}"
      csv_string += arate_details.size == 0 ? "0#{sep}0\n" : "#{nice_number(arate_cur, session).to_s.gsub(".", dec)}#{sep}#{arate_details[0]['round'].to_s.gsub(".", dec)}\n"
    end

    csv_string
  end

  def tariffs_api_wholesale
    sql = "SELECT directions.name as 'direction', destinations.name as 'destination', destinations.prefix, destinations.subcode, directions.code,
      ratedetails.start_time, ratedetails.end_time, ratedetails.rate, ratedetails.connection_fee, ratedetails.increment_s, ratedetails.min_time, ratedetails.daytype
      FROM rates
      LEFT JOIN ratedetails ON (rates.id = ratedetails.rate_id)
      LEFT JOIN destinations ON (rates.destination_id = destinations.id)
      LEFT JOIN directions ON (directions.code = destinations.direction_code)
      WHERE rates.tariff_id = #{self.id}
      ORDER BY directions.name ASC;"
    result = ActiveRecord::Base.connection.select_all(sql)
    return result
  end

  def tariffs_api_retail
    sql = "SELECT rates.id, destinationgroups.name, destinationgroups.desttype,
           aratedetails.price, aratedetails.round, aratedetails.duration, aratedetails.artype, aratedetails.start_time, aratedetails.end_time, aratedetails.daytype, aratedetails.from
           FROM rates
           LEFT JOIN destinationgroups on (destinationgroups.id = rates.destinationgroup_id)
           LEFT JOIN aratedetails on (aratedetails.rate_id = rates.id)
           WHERE rates.tariff_id ='#{id}'
           ORDER BY  destinationgroups.name, destinationgroups.desttype, aratedetails.from, aratedetails.daytype ,aratedetails.start_time, rates.id ASC"
    result = ActiveRecord::Base.connection.select_all(sql)
    return result
  end

  def generate_providers_rates_csv(session)
    s_prefix = session[:user_rates_prefix] ||= ''
    prefix_cond = s_prefix.present? ? " AND prefix LIKE '#{s_prefix.to_s}'" : ''
    @effective_from_active = (['admin', 'reseller'].include?(session[:usertype]) && (['provider', 'user_wholesale'].include?(self.purpose))) ? true : false
    if @effective_from_active
      sql = "SELECT directions.name as 'direction', destinations.name as 'destination', destinations.prefix, destinations.subcode, directions.code, ratedetails.start_time, ratedetails.end_time, ratedetails.rate, ratedetails.connection_fee, ratedetails.increment_s, ratedetails.min_time, ratedetails.daytype, IF(IFNULL(rates.effective_from, 0) = rates2.max_effective_from, 1, 0) AS active
             FROM `rates` INNER JOIN `destinations` ON `destinations`.`id` = `rates`.`destination_id` INNER JOIN `directions` ON `directions`.`code` = `destinations`.`direction_code` LEFT JOIN (SELECT tariff_id, destination_id, IFNULL(MAX(effective_from), 0) AS max_effective_from from rates
             WHERE (effective_from < now() OR effective_from IS NULL) AND rates.tariff_id = #{self.id} GROUP BY tariff_id,destination_id) rates2 ON rates2.tariff_id = rates.tariff_id AND rates.destination_id = rates2.destination_id LEFT JOIN ratedetails ON ratedetails.rate_id = rates.id
             WHERE rates.tariff_id = #{self.id} #{prefix_cond}
             GROUP BY rates.id
             ORDER BY directions.name ASC, rates.effective_from DESC"
    else
      sql = "SELECT directions.name as 'direction', destinations.name as 'destination', destinations.prefix, destinations.subcode, directions.code, ratedetails.start_time, ratedetails.end_time, ratedetails.rate, ratedetails.connection_fee, ratedetails.increment_s, ratedetails.min_time, ratedetails.daytype
             FROM rates LEFT JOIN ratedetails ON (rates.id = ratedetails.rate_id) LEFT JOIN destinations ON (rates.destination_id = destinations.id) LEFT JOIN directions ON (directions.code = destinations.direction_code)
             WHERE rates.tariff_id = #{self.id} #{prefix_cond}
             ORDER BY directions.name ASC"
    end
    res = Array(ActiveRecord::Base.connection.select_all(sql))
    res.delete_if {|r| r["active"] == 0} if @effective_from_active
    sep = Confline.get_value("CSV_Separator").to_s
    dec = Confline.get_value("CSV_Decimal").to_s

    # currencies
    exrate = Currency.count_exchange_rate(self.currency, session[:show_currency])

    csv_string = CSV.generate(:col_sep => sep) do |csv|
      csv << [
          _('Direction'), # r["direction"]
          _('Destination'), # r["destination"]
          _('Prefix'), # r["prefix"]
          _('Subcode'), # r["subcode"]
          _('Country_code'), # r["code"]
          _('Rate') + "("+session[:show_currency].to_s+")", # rate
          _('Connection_Fee') + "("+session[:show_currency].to_s+")", # con_fee
          _('Increment',), # r["increment_s"]
          _('Minimal_Time'), # r["min_time"]
          _('Start_Time'), # r["start_time"]
          _('End_Time'), # r["end_time"]
          _('Week_Day') # r["daytype"]
      ]
      for r in res

        rate, con_fee = Currency.count_exchange_prices({:exrate => exrate, :prices => [r["rate"].to_d, r["connection_fee"].to_d]})
        csv << [
            r["direction"].to_s.gsub(sep, " "),
            r["destination"].to_s.gsub(sep, " "),
            r["prefix"],
            r["subcode"],
            r["code"],
            nice_number(rate, session).gsub(".", dec),
            nice_number(con_fee, session).gsub(".", dec),
            r["increment_s"],
            r["min_time"],
            r['start_time'].blank? ? '' : r['start_time'].strftime('%H:%M:%S'),
            r['end_time'].blank? ? '' : r["end_time"].strftime('%H:%M:%S'),
            r["daytype"]
        ]
      end
    end
  end

  def generate_personal_wholesale_rates_csv(session)
    sql = "SELECT rates.* FROM rates, destinations, directions WHERE rates.tariff_id = #{id} AND rates.destination_id = destinations.id AND destinations.direction_code = directions.code ORDER by directions.name ASC;"
    rates = Rate.find_by_sql(sql)
    sep = Confline.get_value("CSV_Separator").to_s
    dec = Confline.get_value("CSV_Decimal").to_s

    csv_string = _('Direction') + sep + _('Prefix') +
            sep + _('Subcode') + sep + _('Rate') + "(" + (session[:show_currency]).to_s + ")" +
            sep + _('Connection_Fee') + "(" + (session[:show_currency]).to_s + ")" + sep + _('Increment') +
            sep + _('Minimal_Time') + "\n"

    exrate = Currency.count_exchange_rate(self.currency, session[:show_currency])

    for rate in rates
      rate_details, rate_cur = get_provider_rate_details(rate, exrate)

      csv_string += "#{rate.destination.direction.name.to_s.gsub(sep, " ")}" if rate.destination && rate.destination.direction
      csv_string += "#{sep}#{rate.destination.prefix}#{sep}#{rate.destination.subcode}#{sep}" if rate.destination
      csv_string += "0#{sep}0#{sep}0#{sep}" if !rate.destination

      csv_string += "#{rate_cur.to_s.gsub(".", dec)}#{sep}#{rate_details[0]['connection_fee'].to_s.gsub(".", dec)}#{sep}#{rate_details[0]['increment_s'].to_s.gsub(".", dec)}#{sep}" +
          "#{rate_details[0]['min_time'].to_s.gsub(".", dec)}\n" if rate_details.size > 0
      csv_string += "0#{sep}0#{sep}0#{sep}0\n" if rate_details.size == 0
    end

    return csv_string
  end

  def check_types_periods(options={})
    if options[:time_from]
      a1, a2 = options[:time_from][:hour].to_s + ":" + options[:time_from][:minute].to_s + ":" + options[:time_from][:second].to_s, options[:time_till][:hour].to_s + ":" + options[:time_till][:minute].to_s + ":" + options[:time_till][:second].to_s
    else
      a1, a2 = options[:time_from_hour].to_s + ":" + options[:time_from_minute].to_s + ":" + options[:time_from_second].to_s, options[:time_till_hour].to_s + ":" + options[:time_till_minute].to_s + ":" + options[:time_till_second].to_s
    end
    day_type = ["wd", "fd",].include?(options[:rate_day_type].to_s) ? options[:rate_day_type].to_s : ''
    #In case new rate detail's time and daytype is identical to allready existing rate details it will
    #be updated so we don't think it is a collision
    #In case new rate details time is WD and there already is FD there cannot be time collisions. and vice versa
    #In all other cases we need to check for time colissions. Note bug that was originaly here - function does not
    #work if time wraps around e.g. period is between 23:00 and 01:00
    #UPDATE mor has peculiar way to check for time collisions - if at least a minute is set for all days, no other
    #tariff detail can be set to fd/wd and vice versa
    ratesd = Ratedetail.joins("LEFT JOIN rates ON (ratedetails.rate_id = rates.id)").where(["rates.tariff_id = '#{id}' AND
      CASE
        WHEN daytype = '#{day_type}' AND start_time = '#{a1}' AND end_time = '#{a2}' THEN 0
        WHEN '#{day_type}' IN ('WD', 'FD') AND daytype IN ('WD', 'FD') AND daytype != '#{day_type}' THEN 0
        WHEN (daytype = '' AND '#{day_type}' != '') OR (daytype IN ('WD', 'FD') AND '#{day_type}' NOT IN ('WD', 'FD')) THEN 1
        ELSE ('#{a1}' BETWEEN start_time AND end_time) OR ('#{a2}' BETWEEN start_time AND end_time) OR (start_time BETWEEN '#{a1}' AND '#{a2}') OR (end_time BETWEEN '#{a1}' AND '#{a2}')
      END != 0"]).all

    notice_2 = ''
    #checking time periods for collisions
    #ticket #5808 -> not checking any more
    #if ratesd and ratesd.size.to_i > 0
    #  notice_2 = _('Tariff_import_incorrect_time').html_safe
    #  notice_2 += '<br /> * '.html_safe + _('Please_select_period_without_collisions').html_safe
    #  # redirect_to :action => "import_csv", :id => @tariff.id, :step => "2" and return false
    #end

    ratesd = Ratedetail.select("SUM(IF(daytype = '',1,0)) all_sum, SUM(IF(daytype != '',1,0)) wd_fd_sum ").joins("LEFT JOIN rates ON (ratedetails.rate_id = rates.id)").where(["rates.tariff_id = '#{id}'"]).first
    if ratesd.wd_fd_sum.to_i == 0
      rate_types = [[_("All"), "all"], [_("Work_Days"), "wd"], [_("Free_Days"), "fd"]]
    else
      rate_types = [_("Work_Days"), "wd"], [_("Free_Days"), "fd"]
    end

    return rate_types, notice_2
  end

  def head_of_file(path, n = 1)
    CsvImportDb.head_of_file(path, n)
  end

  def save_file(file, path = "/tmp/")
    CsvImportDb.save_file(id, file, path)
  end

  def load_csv_into_db(tname, sep, dec, fl, path = "/tmp/")
    colums ={}
    colums[:colums] = [{:name => 'f_subcodes', :type => 'VARCHAR(50)', :default => ''},
                       {:name => 'short_prefix', :type => 'VARCHAR(50)', :default => ''},
                       {:name => 'f_country_code', :type => 'INT(4)', :default => 0},
                       {:name => 'f_error', :type => 'INT(4)', :default => 0},
                       {:name => 'nice_error', :type => 'INT(4)', :default => 0},
                       {:name => 'ned_update', :type => 'INT(4)', :default => 0},
                       {:name => 'not_found_in_db', :type => 'INT(4)', :default => 0},
                       {:name => 'id', :type => 'INT(11)', :inscrement => ' NOT NULL auto_increment '},
                       {:name => 'original_destination_name', :type => 'VARCHAR(255)', :default => ''}]
    CsvImportDb.load_csv_into_db(tname, sep, dec, fl, path, colums)
  end

  def analize_file(name, options)
    CsvImportDb.log_swap('analize')
    MorLog.my_debug("CSV analize_file #{name}", 1)
    arr = {}
    arr[:destinations_in_db] = Destination.count.to_i
    arr[:directions_in_db] = Direction.count.to_i
    arr[:destinations_in_csv_file] = (ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name}").to_i - 1).to_s if ActiveRecord::Base.connection.tables.include?(name)
    #arr[:rates_to_update] = Rate.count(:all, :conditions => ['tariff_id = ?', id], :joins => "JOIN destinations ON (rates.destination_id = destinations.id) JOIN #{name} ON (destinations.prefix = replace(col_#{options[:imp_prefix]}, '\\r', ''))")
    arr[:tariff_rates] = Rate.count(:all, :conditions => {:tariff_id => id})

    if options[:imp_effective_from].present?
      str = " AND IFNULL(rates.effective_from, '') = CONVERT_TZ(STR_TO_DATE(replace(col_#{options[:imp_effective_from]}, '\\r', ''), '#{options[:date_format]}'), '#{options[:current_user_tz]}', '#{local_tz_for_import}')"
      str2 = ", col_#{options[:imp_effective_from]}"

      # Formats similiar to '06-01' cannot be interpreted by SQL Date parser, so the mentioned fields have to be
      # pre-parsed by Ruby.
      rows = ActiveRecord::Base.connection.select_all("SELECT id, col_#{options[:imp_effective_from]} AS effective_from FROM #{name} WHERE (length(col_#{options[:imp_effective_from]}) = 5 AND LEFT(col_#{options[:imp_effective_from]}, 3) = '#{options[:date_format][2]}')")
      current_time = Date.current.to_time
      row_updates = []
      rows.each do |row|
        begin
          effective_from_date = row['effective_from']
          effective_from_date = Time.parse(effective_from_date.gsub('-', '/'), current_time).
              strftime("#{options[:date_format]}")

          row_updates << "UPDATE #{name} SET col_#{options[:imp_effective_from]} = '#{effective_from_date}' WHERE id = #{row['id']}"
        rescue => exception
          #Do nothing.
        end
      end

      ActiveRecord::Base.transaction{ row_updates.each { |update| ActiveRecord::Base.connection.execute(update) } }
    else
      str = " AND rates.effective_from IS NULL"
      str2 = ""
    end

    # set error flag on not rates if Effective_from is not datetime | code : 16
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 16 WHERE STR_TO_DATE(replace(col_#{options[:imp_effective_from]}, '\\r', ''), '#{options[:date_format]}') IS NULL OR STR_TO_DATE(replace(col_#{options[:imp_effective_from]}, '\\r', ''), '#{options[:date_format]}') = '0000-00-00 00:00:00'") if ActiveRecord::Base.connection.tables.include?(name) and options[:imp_effective_from].present?

    # set error flag on dublicates | code : 12
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 12 WHERE f_error = 0 AND col_#{options[:imp_prefix]} IN (SELECT prf FROM (SELECT col_#{options[:imp_prefix]} AS prf, count(*) AS u FROM #{name} GROUP BY col_#{options[:imp_prefix]}#{str2}  HAVING u > 1) AS imf )") if ActiveRecord::Base.connection.tables.include?(name)

    # set error flag on not int prefixes | code : 13
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 13 WHERE replace(col_#{options[:imp_prefix]}, '\\r', '') REGEXP '^[0-9]+$' = 0 AND f_error = 0")   if ActiveRecord::Base.connection.tables.include?(name)

    unless ["admin", "accountant"].include?(User.current.usertype)
      # set error flag on not found destinations if reseller | code : 14
      ActiveRecord::Base.connection.execute("UPDATE #{name} LEFT JOIN destinations ON (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix) SET f_error = 1, nice_error = 14 WHERE destinations.id IS NULL AND f_error = 0") if ActiveRecord::Base.connection.tables.include?(name)
    end

    if options[:imp_cc] != -1
      # set error flag where country_code is not found in DB | code : 11
      ActiveRecord::Base.connection.execute("UPDATE #{name} LEFT JOIN directions ON (replace(col_#{options[:imp_cc]}, '\\r', '') = directions.code) SET f_error = 1, nice_error = 11 WHERE directions.id IS NULL AND f_error = 0")      if ActiveRecord::Base.connection.tables.include?(name)
    end

    if ActiveRecord::Base.connection.tables.include?(name)
    #ticket #5808 -> since now we dont check for time collisions,
    #just import anything if posible. else user will be notified
    #in the last step about rates that was not posible to import
    #due to time collision.
    day_type = ["wd", "fd",].include?(options[:imp_date_day_type].to_s) ? options[:imp_date_day_type].to_s : ''
    start_time = options[:imp_time_from_type]
    end_time = options[:imp_time_till_type]
    ActiveRecord::Base.connection.execute("UPDATE #{name}
                                          JOIN destinations ON (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix)
                                          JOIN rates ON (rates.destination_id = destinations.id) JOIN ratedetails ON (ratedetails.rate_id = rates.id)
                                          SET f_error = 1, nice_error = 15
                                          WHERE rates.tariff_id = '#{id}' AND CASE
                                          WHEN daytype = '#{day_type}' AND start_time = '#{start_time}' AND end_time = '#{end_time}' THEN 0
                                          WHEN '#{day_type}' IN ('WD', 'FD') AND daytype IN ('WD', 'FD') AND daytype != '#{day_type}' THEN 0
                                          WHEN (daytype = '' AND '#{day_type}' != '') OR (daytype IN ('WD', 'FD') AND '#{day_type}' NOT IN ('WD', 'FD')) THEN 1
                                          ELSE ('#{start_time}' BETWEEN start_time AND end_time) OR ('#{end_time}' BETWEEN start_time AND end_time) OR (start_time BETWEEN '#{start_time}' AND '#{end_time}') OR (end_time BETWEEN '#{start_time}' AND '#{end_time}')
                                          END != 0")
    end

    # set flag not_found_in_db
    ActiveRecord::Base.connection.execute("UPDATE #{name} LEFT JOIN destinations ON (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix) SET not_found_in_db = 1 WHERE destinations.id IS NULL AND f_error = 0") if ActiveRecord::Base.connection.tables.include?(name)

    # set flags
    self.csv_import_prefix_analize(name, options)   if ActiveRecord::Base.connection.tables.include?(name)

    if options[:imp_update_dest_names].to_i == 1 and options[:imp_dst] >= 0
      # set flag on destination name update
      ActiveRecord::Base.connection.execute("UPDATE #{name} join destinations on (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix) SET ned_update = 1 WHERE BINARY replace(replace(TRIM(col_#{options[:imp_dst]}), '\r', ''), '  ', ' ') != IFNULL(original_destination_name,destinations.name)") if ActiveRecord::Base.connection.tables.include?(name)
    end

    if options[:imp_update_subcodes].to_i == 1 and options[:imp_subcode] >= 0
      # set flag on destination name update
      ActiveRecord::Base.connection.execute("UPDATE #{name} join destinations on (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix) SET ned_update = ned_update + 2 WHERE (destinations.subcode != replace(col_#{options[:imp_subcode]}, '\\r', '') OR (destinations.subcode IS NULL AND LENGTH(col_#{options[:imp_subcode]}) > 0 ) )")  if ActiveRecord::Base.connection.tables.include?(name)
    end

    if options[:imp_update_directions].to_i == 1
      ActiveRecord::Base.connection.execute("UPDATE #{name} join directions on (replace(col_#{options[:imp_cc]}, '\\r', '') = directions.code) join destinations on (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix) SET ned_update = ned_update + 4 WHERE destinations.direction_code != directions.code")   if ActiveRecord::Base.connection.tables.include?(name)
    end

    if ActiveRecord::Base.connection.tables.include?(name)
      arr[:bad_destinations] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_error = 1").to_i
      arr[:destinations_to_create] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_error = 0 AND not_found_in_db = 1").to_i
      arr[:destinations_to_update] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) AS d_all FROM #{name} WHERE ned_update IN (1, 3, 5, 7)").to_i if options[:imp_update_dest_names].to_i == 1 and options[:imp_dst] >= 0
      arr[:subcodes_to_update] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) AS d_all FROM #{name} WHERE ned_update IN (2, 3, 6, 7)").to_i if options[:imp_update_subcodes].to_i == 1 and options[:imp_subcode] >= 0
      arr[:directions_to_update] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) AS d_all FROM #{name} WHERE ned_update IN (4, 5, 6, 7)").to_i if options[:imp_update_directions].to_i == 1
      arr[:new_rates_to_create] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) AS r_all FROM #{name} join destinations ON (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix) LEFT JOIN rates ON (destinations.id = rates.destination_id and rates.tariff_id = #{id} #{str}) WHERE f_error = 0 AND rates.id IS NULL").to_i + arr[:destinations_to_create].to_i
      arr[:new_destinations_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE not_found_in_db = 1").to_i
      arr[:existing_destinations_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE not_found_in_db = 0 AND f_error = 0").to_i
      arr[:rates_to_update] = Rate.count(:all, :conditions => ["tariff_id = ? AND f_error = 0 AND not_found_in_db = 0 #{str}", id], :joins => "JOIN destinations ON (rates.destination_id = destinations.id) JOIN #{name} ON (destinations.prefix = replace(col_#{options[:imp_prefix]}, '\\r', ''))")
      arr[:destination_groups_to_update] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name}").to_i
    end

    if options[:imp_delete_unimported_prefix_rates].to_i == 1
      arr[:rates_to_delete] = arr[:tariff_rates] - arr[:rates_to_update]
    end

    return arr
  end

  def create_deatinations(name, options, options2)
    CsvImportDb.log_swap('create_destinations_start')
    MorLog.my_debug("CSV create_deatinations #{name}", 1)
    count = 0
    s = []; ss=[]; cc = ""
    ["prefix", "direction_code", "subcode", "name", "city"].each { |col|
      if !options["imp_#{col}".to_sym].blank? and options["imp_#{col}".to_sym].to_i > -1 or ["direction_code", "subcode"].include?(col)
        case col
          when "direction_code"
            sbg = "short_prefix"
            cc << (options[:imp_cc].to_i >= 0 ? "IF(replace(col_#{options[:imp_cc]}, '\\r', '') IN (SELECT code FROM directions),replace(col_#{options[:imp_cc]}, '\\r', ''),#{sbg})" : "#{sbg}")
            s << "#{cc}"
          when "subcode"
            if options[:imp_subcode].to_i > -1
              s << "replace(col_#{options["imp_#{col}".to_sym]}, '\\r', '')"
            else
              s << "f_subcodes"
            end
          when "tier"
            s << 'IF(col_' + (options["imp_#{col}".to_sym]).to_s + ' = "", 0, replace(col_' + (options["imp_#{col}".to_sym]).to_s + ", '\\r', ''))"
          else
            s << 'replace(col_' + (options["imp_#{col}".to_sym]).to_s + ", '\\r', '')"
        end
        ss << col
      elsif col == "name"
        ss << "name"
        subc = options[:imp_subcode].to_i > -1 ? ", ' ',#{s[2]}" : ""
        if !options[:imp_dst].blank? and options[:imp_dst].to_i > -1
          s << "IF(replace(col_#{options[:imp_dst].to_s}, '\\r', '') = '',
                CONCAT((SELECT name FROM directions WHERE code = #{s[1]} LIMIT 1) #{subc}) ,
                replace(col_#{options[:imp_dst].to_s}, '\\r', ''))"
        else
          s << "CONCAT((SELECT name FROM directions WHERE code = short_prefix LIMIT 1) #{subc})"
        end
      end
    }

    s2 = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_country_code = 1 AND f_error = 0 AND not_found_in_db = 1").to_i
    n = s2/1000 +1
    n.times { |i|
      in_rd = "INSERT INTO destinations (#{ss.join(',')})
                SELECT #{s.join(',')} FROM #{name}
                WHERE f_country_code = 1 AND f_error = 0 AND not_found_in_db = 1 LIMIT #{i * 1000}, 1000"
      begin
        Confline.set_value('Destination_create', 1, User.current.id)
        ActiveRecord::Base.connection.execute(in_rd)
        count += ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_country_code = 1 AND f_error = 0 AND not_found_in_db = 1 LIMIT #{i * 1000}, 100000").to_i
      ensure
        Confline.set_value('Destination_create', 0, User.current.id)
      end
    }

    if options[:imp_cc] >= 0
      s3 = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_country_code = 0 AND f_error = 0 AND not_found_in_db = 1").to_i
      n = s3/1000 +1
      n.times { |i|
        n_rd = "INSERT INTO destinations (#{ss.join(',')})
                  SELECT #{s.join(',')} FROM #{name}
                  WHERE f_country_code = 0 AND f_error = 0 AND not_found_in_db = 1 LIMIT #{i * 1000}, 1000"
        begin
          Confline.set_value('Destination_create', 1, User.current.id)
          ActiveRecord::Base.connection.execute(n_rd)
          count += ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_country_code = 0 AND f_error = 0 AND not_found_in_db = 1 LIMIT #{i * 1000}, 1000").to_i
        ensure
          Confline.set_value('Destination_create', 0, User.current.id)
        end
      }
    end
    CsvImportDb.log_swap('create_destinations_end')
    return count
  end

  def update_destinations(name, options, options2)
    CsvImportDb.log_swap('update_destinations_start')
    MorLog.my_debug("CSV update_destinations #{name}", 1)
    count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE ned_update IN (1, 3, 5, 7)").to_i

    sql = "UPDATE destinations " +
          "JOIN #{name} ON (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix) " +
          "SET name = replace(replace(TRIM(col_#{options[:imp_dst]}), '\\r', ''), '  ', ' ') " +
          "WHERE ned_update IN (1, 3, 5, 7)"
    ActiveRecord::Base.connection.update(sql)
    CsvImportDb.log_swap('update_destinations_end')
    return count
  end

  def update_destination_groups(name, options, options2)
    CsvImportDb.log_swap('update_destination_groups_start')
    MorLog.my_debug("CSV update_destination_groups #{name}", 1)
    count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name}").to_i

    sql ="UPDATE destinations
         JOIN #{name} ON (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix)
         JOIN destinationgroups ON destinationgroups.desttype = destinations.subcode AND flag = LOWER(direction_code)
         SET destinations.destinationgroup_id = destinationgroups.id"

    ActiveRecord::Base.connection.update(sql)
    CsvImportDb.log_swap('update_destination_groups_end')
    return count
  end

  def update_subcodes(name, options, options2)
    CsvImportDb.log_swap('update_subcodes_start')
    MorLog.my_debug("CSV update_subcodes #{name}", 1)
    count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE ned_update IN (2, 3, 6, 7)").to_i

    sql ="UPDATE destinations
         JOIN #{name} ON (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix)
         SET subcode = replace(col_#{options[:imp_subcode]}, '\\r', '')
         WHERE ned_update IN (2, 3, 6, 7)"
    ActiveRecord::Base.connection.update(sql)
    CsvImportDb.log_swap('update_subcodes_end')
    return count
  end

  def update_directions(name, options, options2)
    CsvImportDb.log_swap('update_directions_start')
    MorLog.my_debug("CSV update_directions #{name}", 1)
    count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE ned_update IN (4, 5, 6, 7)").to_i

    sql ="UPDATE destinations
         JOIN #{name} ON (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix)
         JOIN directions on directions.code = replace(col_#{options[:imp_cc]}, '\\r', '')
         SET destinations.direction_code = replace(col_#{options[:imp_cc]}, '\\r', '')
         WHERE ned_update IN (4, 5, 6, 7)"
    ActiveRecord::Base.connection.update(sql)
    CsvImportDb.log_swap('update_directions_end')
    return count
  end

  def update_rates_from_csv(name, options, options2)
    CsvImportDb.log_swap('update_rates_from_csv_start')
    MorLog.my_debug("CSV update_rates_from_csv #{name}", 1)
    #bad_prefix_sql = options2[:bad_destinations].to_i > 0 ? "AND replace(col_#{options[:imp_prefix]}, '\\r', '') NOT IN (#{options2[:bad_prefixes].join(',')})" : ''
    ["wd", "fd"].include?(options[:imp_date_day_type].to_s) ? day_type = options[:imp_date_day_type].upcase : day_type = ""
    type_sql = day_type.blank? ? '' : " AND ratedetails.daytype = '#{day_type.to_s}' "

    if options[:manual_connection_fee] and !options[:manual_connection_fee].blank?
      conection_fee = options[:manual_connection_fee]
    elsif !options[:imp_connection_fee].blank? and options[:imp_connection_fee].to_i > -1
      conection_fee = "replace(replace(col_#{options[:imp_connection_fee]}, '\\r', ''), '#{options[:dec]}', '.')"
    else
      conection_fee = 0
    end

    if options[:manual_increment] and !options[:manual_increment].blank?
      increment_s = options[:manual_increment]
    elsif !options[:imp_increment_s].blank? and options[:imp_increment_s].to_i > -1
      increment_s = "replace(col_#{options[:imp_increment_s]}, '\\r', '')"
    else
      increment_s = 1
    end

    if options[:manual_min_time] and !options[:manual_min_time].blank?
      min_time = options[:manual_min_time]
    elsif !options[:imp_min_time].blank? and options[:imp_min_time].to_i > -1
      min_time = "replace(col_#{options[:imp_min_time]}, '\\r', '')"
    else
      min_time = 0
    end

    if options[:manual_ghost_percent] and !options[:manual_ghost_percent].blank?
      ghost_percent = options[:manual_ghost_percent]
    elsif !options[:imp_ghost_percent].blank? and options[:imp_ghost_percent].to_i > -1
      ghost_percent = "replace(col_#{options[:imp_ghost_percent]}, '\\r', 0)"
      ghost_percent = "IF(#{ghost_percent} REGEXP '^[[:digit:].]+$', #{ghost_percent}, 0)"
    else
      ghost_percent = 'NULL'
    end

    if options[:imp_effective_from].present?
      str = " AND rates.effective_from = CONVERT_TZ(STR_TO_DATE(replace(col_#{options[:imp_effective_from]}, '\\r', ''), '#{options[:date_format]}'), '#{options[:current_user_tz]}', '#{local_tz_for_import}')"
    else
      str = " AND rates.effective_from IS NULL"
    end

    count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM rates join destinations ON (destinations.id = rates.destination_id) JOIN #{name} ON (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix) where rates.tariff_id = #{id} #{str} AND f_error = 0 AND not_found_in_db = 0")
    sql = "UPDATE rates, destinations, #{name}
            SET ghost_min_perc = #{ghost_percent}
            WHERE destinations.id = rates.destination_id AND replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix AND rates.tariff_id = #{id} #{str} AND f_error = 0 AND not_found_in_db = 0"
    ActiveRecord::Base.connection.update(sql)

    sql = "UPDATE ratedetails, (SELECT rates.id AS nrate_id, #{name}.* FROM rates join destinations ON (destinations.id = rates.destination_id) JOIN #{name} ON (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix) where rates.tariff_id = #{id} #{str} AND f_error = 0 AND not_found_in_db = 0) AS temp
            SET ratedetails.rate = replace(replace(replace(col_#{options[:imp_rate]}, '\\r', ''), '#{options[:dec]}', '.'), '$', ''),
                ratedetails.connection_fee = #{conection_fee},
                increment_s = #{increment_s},
                min_time = #{min_time}
            WHERE ratedetails.rate_id = nrate_id #{type_sql} AND start_time = '#{options[:imp_time_from_type]}' AND end_time = '#{options[:imp_time_till_type]}'"
    ActiveRecord::Base.connection.update(sql)
    CsvImportDb.log_swap('update_rates_from_csv_end')
    return count
  end

  def create_rates_from_csv(name, options, options2)
    CsvImportDb.log_swap('create_rates_from_csv_start')
    MorLog.my_debug("CSV create_rates_from_csv #{name}", 1)

    if options[:imp_effective_from].present?
      str = " AND IFNULL(rates.effective_from, '') = CONVERT_TZ(STR_TO_DATE(replace(col_#{options[:imp_effective_from]}, '\\r', ''), '#{options[:date_format]}'), '#{options[:current_user_tz]}', '#{local_tz_for_import}')"
      effective_from_column = ", effective_from"
      effective_from_value = ", CONVERT_TZ(STR_TO_DATE(replace(col_#{options[:imp_effective_from]}, '\\r', ''), '#{options[:date_format]}'), '#{options[:current_user_tz]}', '#{local_tz_for_import}')"
    end

    count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name}
    join destinations on (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix)
    LEFT join rates on (destinations.id = rates.destination_id and rates.tariff_id = #{id} #{str})
    WHERE rates.id IS NULL AND f_error = 0")

    if options[:manual_ghost_percent] and !options[:manual_ghost_percent].blank?
      ghost_percent = options[:manual_ghost_percent]
    elsif !options[:imp_ghost_percent].blank? and options[:imp_ghost_percent].to_i > -1
      ghost_percent = "replace(col_#{options[:imp_ghost_percent]}, '\\r', '')"
      ghost_percent = "IF(#{ghost_percent} REGEXP '^[[:digit:].]+$', #{ghost_percent}, 0)"
    else
      ghost_percent = 'NULL'
    end

    sql="INSERT INTO rates (tariff_id, destination_id, ghost_min_perc#{effective_from_column})
    SELECT #{id}, destinations.id, #{ghost_percent}#{effective_from_value} FROM #{name}
    JOIN destinations ON (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix)
    LEFT JOIN rates ON (destinations.id = rates.destination_id AND rates.tariff_id = #{id} #{str})
    WHERE rates.id IS NULL AND f_error = 0"
    ActiveRecord::Base.connection.update(sql)
    CsvImportDb.log_swap('create_rates_from_csv')
    return count
  end

  def insert_ratedetails(name, options, options2)
    CsvImportDb.log_swap('insert_ratedetails_start')
    MorLog.my_debug("CSV insert_ratedetails #{name}", 1)

    s = []; ss=[]
    collums = ["rate", "increment_s", "min_time", "connection_fee", "daytype"]
    collums.each { |col|
      case col
        when "daytype"
          ["wd", "fd"].include?(options[:imp_date_day_type].to_s) ? day_type = options[:imp_date_day_type].upcase : day_type = ""
          s1 = day_type.blank? ? "''" : " '#{day_type.to_s}' "
        when "connection_fee"
          if options[:manual_connection_fee] and !options[:manual_connection_fee].blank?
            s1 = options[:manual_connection_fee]
          elsif !options[:imp_connection_fee].blank? and options[:imp_connection_fee].to_i > -1
            s1 = "replace(replace(col_#{options[:imp_connection_fee]}, '\\r', ''), '#{options[:dec]}', '.')"
          else
            s1 = 0
          end
        when "increment_s"
          if options[:manual_increment] and !options[:manual_increment].blank?
            s1 = options[:manual_increment]
          elsif !options[:imp_increment_s].blank? and options[:imp_increment_s].to_i > -1
            s1 = "replace(col_#{options[:imp_increment_s]}, '\\r', '')"
          else
            s1 = 1
          end
        when "min_time"
          if options[:manual_min_time] and !options[:manual_min_time].blank?
            s1 = options[:manual_min_time]
          elsif !options[:imp_min_time].blank? and options[:imp_min_time].to_i > -1
            s1 = "replace(col_#{options[:imp_min_time]}, '\\r', '')"
          else
            s1 = 0
          end
        when "rate"
          s1 = "replace(replace(replace(col_#{options[:imp_rate]}, '\\r', ''), '#{options[:dec]}', '.'), '$', '')"
        else
          s1= 'replace(col_' + (options["imp_#{col}".to_sym]).to_s + ", '\\r', '')"
      end
      s << s1
      ss << col
    }
    #ticket #4845. im not joining ratedetails based only on rate_id table cause it might return more than
    #1 row for each rate and in that case multiple new rates might be imported. Instead im joining on rate_id,
    #daytype, start/end time to exclude rate details that has to be updated, not inserted as new.
    #Note that i'm relying 100% that checks were made to ensure that after inserting new ratedetails there cannot
    #be any duplications,  we should pray for that.

    str = ''

    if options[:imp_effective_from].present?
      str << "AND CONVERT_TZ(STR_TO_DATE(replace(col_#{options[:imp_effective_from]}, '\\r', ''), '#{options[:date_format]}'), '#{options[:current_user_tz]}', '#{local_tz_for_import}') = rates.effective_from"
    end

    count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name}
    join destinations on (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix)
    join rates on (destinations.id = rates.destination_id AND rates.tariff_id = #{id} #{str})
    left join ratedetails on (ratedetails.rate_id = rates.id AND ratedetails.daytype = '#{(['wd', 'fd'].include?(options[:imp_date_day_type].to_s) ? options[:imp_date_day_type].to_s : '')}' AND ratedetails.start_time = '#{options[:imp_time_from_type]}' AND ratedetails.end_time = '#{options[:imp_time_till_type]}')
WHERE ratedetails.id IS NULL AND f_error = 0")

    in_rd = "INSERT INTO ratedetails (rate_id, start_time, end_time, #{ss.join(',')})
    SELECT DISTINCT(rates.id), '#{options[:imp_time_from_type]}', '#{options[:imp_time_till_type]}', #{s.join(',')} FROM #{name}
    join destinations on (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix)
    join rates on (destinations.id = rates.destination_id and rates.tariff_id = #{id} #{str})
    left join ratedetails on (ratedetails.rate_id = rates.id AND ratedetails.daytype = '#{(['wd', 'fd'].include?(options[:imp_date_day_type].to_s) ? options[:imp_date_day_type].to_s : '')}' AND ratedetails.start_time = '#{options[:imp_time_from_type]}' AND ratedetails.end_time = '#{options[:imp_time_till_type]}')
    WHERE ratedetails.id IS NULL AND f_error = 0"

    ActiveRecord::Base.connection.execute(in_rd)
    CsvImportDb.log_swap('insert_ratedetails_end')
    return count
  end

  def delete_unimported_rates(name, options)
    existing_rates = rates.all
    imported_rates = rates.joins('INNER JOIN destinations ON rates.destination_id = destinations.id').
                                  joins("INNER JOIN #{name} ON destinations.prefix = #{name}.col_#{options[:imp_prefix]} AND f_error = 0").
                                  all

    rates_to_delete = (existing_rates - imported_rates)
    rates_to_delete_count = rates_to_delete.size

    Rate.transaction do
      rates_to_delete.each {|rate| rate.destroy_everything}
    end

    rates_to_delete_count
  end

  def Tariff.clean_after_import(tname, path = "/tmp/")
    CsvImportDb.clean_after_import(tname, path)
  end


  def csv_import_prefix_analize(name, options)
    MorLog.my_debug("CSV csv_import_prefix_analize #{name}", 1)
    # retrieve direction_codes to hash
    direction_codes = {}
    res = ActiveRecord::Base.connection.select_all("SELECT direction_code, prefix FROM destinations;")
    res.each { |r| direction_codes[r["prefix"]] = r["direction_code"] }

    #counting destinations allready in MOR
    destination_data = ActiveRecord::Base.connection.select_all("SELECT prefix, name FROM destinations")
    prefixes = destination_data.map { |pr| pr["prefix"].to_s.gsub(/\s/, '') }

    # 0 - empty line - skip
    # 1 - everything ok
    # 2 - cc(country_code) = usa
    # 3 - cc from csv
    # 4 - prefix from shorter prefix
    # ERRORS
    # 10 - no cc from csv - can't create destination
    # 11 - bad cc from csv - can't create destination
    # 12 - duplicate

    short_prefix = ''
    subcodes = ''
    bad = []


    new_destinations = ActiveRecord::Base.connection.select_all("SELECT *, #{name}.id AS i_id FROM #{name} left join destinations on (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix)  WHERE not_found_in_db = 1 AND f_error = 0;")
    MorLog.my_debug("Use temp table : #{name}")

    prefixes = Hash[prefixes.map { |v| [v.to_s, 1] }]
    config   = Rails.configuration.database_configuration
    packed_destinations = {}
    update = {}
    new_destinations.each_with_index { |row, i|
      country_code = row["col_#{options[:imp_cc]}"].to_s #country_code
      if country_code.blank? or options[:imp_cc] == -1
        prefix = row["col_#{options[:imp_prefix]}"].to_s.strip.gsub(/\s/, '')
        pfound = 0
        plength = prefix.length
        j = 1
        while j < plength and pfound == 0
          tprefix = prefix[0, plength-j]
          pfound = 1 if prefixes[tprefix].to_i == 1
          j += 1
        end
        if pfound == 1
          short_prefix = direction_codes[tprefix.to_s]
          if options[:imp_subcode].to_i < 0
            string = prefix.to_i.to_s[0..(prefix.to_i.to_s.length.to_i-2)]
            dan = true
            str = "prefix like '#{string.to_s}'"
            string = string.to_s[0..(string.length.to_i-2)].to_s
            while (string.length.to_i > 1)
              str << " OR prefix like '#{string.to_s}'"
              string = string.to_s[0..(string.length.to_i-2)].to_s
            end
            dest = Destination.where(str).order("prefix DESC").first
            if dest
              subcodes = dest.subcode.to_s
              dan = false
            end
            if string.length.to_i == 1 and dan == true
              subcodes = 'NGN'
            end
            packed_destinations[short_prefix].blank? ? packed_destinations[short_prefix] = [subcodes] : packed_destinations[short_prefix] << subcodes
            if update[short_prefix].blank?
              update[short_prefix] = {}
              update[short_prefix][subcodes] = [row['i_id']]
            else
              if update[short_prefix][subcodes].blank?
                update[short_prefix][subcodes] = [row['i_id']]
              else
                update[short_prefix][subcodes] << row['i_id']
              end
            end
          else
            b = ActiveRecord::Base.connection.select_all("SELECT COUNT(*) AS a FROM information_schema.tables  WHERE table_schema = '#{config[Rails.env]["database"]}' AND table_name = '#{name}' LIMIT 1")
            if b.first["a"] > 0
              ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_country_code = 1, short_prefix = '#{short_prefix}', f_subcodes = col_#{options[:imp_subcode].to_i} WHERE id = #{row['i_id']}")
            else
              flash[:notice] = _('Tariff_import_failed_please_try_again')
              redirect_to :controller => "tariffs", :action => "list" and return false
            end
          end
        else
          bad << row['i_id']
        end
      end
      MorLog.my_debug(i.to_s + " status/update_rate counted", 1) if i % 1000 == 0
    }

    update.keys.each { |s_prefix|
      update[s_prefix].keys.each{ |subcode|
        b = ActiveRecord::Base.connection.select_all("SELECT COUNT(*) AS a FROM information_schema.tables  WHERE table_schema = '#{config[Rails.env]["database"]}' AND table_name = '#{name}' LIMIT 1")
        if b.first["a"] > 0
          all_id = update[s_prefix][subcode].map { |i| i }.join ','
          ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_country_code = 1, short_prefix = '#{s_prefix}', f_subcodes = '#{subcode}' WHERE id IN (#{all_id})")
        else
          flash[:notice] = _('Tariff_import_failed_please_try_again')
          redirect_to :controller => "tariffs", :action => "list" and return false
        end
      }
    }

    if bad and bad.size.to_i > 0
      b = ActiveRecord::Base.connection.select_all("SELECT COUNT(*) AS a FROM information_schema.tables  WHERE table_schema = '#{config[Rails.env]["database"]}' AND table_name = '#{name}' LIMIT 1")
      if b.first["a"] > 0
        # set error flag on not int prefixes | code : 13
        ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 10 WHERE id IN (#{bad.join(',')})")
      else
        flash[:notice] = _('Tariff_import_failed_please_try_again')
        redirect_to :controller => "tariffs", :action => "list" and return false
      end
    end
  end

  def able_to_delete?
    #check for providers
    tpc = providers.count
    if tpc > 0
      message = "#{tpc} #{_('providers_are_using_this_tariff_cant_delete')}"
      return false, message
    end
    # check for cardgroups
    cardgroup = cardgroups.count
    if cardgroup > 0
      message = "#{cardgroup} #{_('cardgroups_are_using_this_tariff_cant_delete')}"
      return false, message
    end
    #check for users
    tuc = users.count
    if tuc > 0
      message = "#{tuc} #{_('users_are_using_this_tariff_cant_delete')}"
      return false, message
    end
    #check for locationrules
    lrules = locationrules.count
    if lrules > 0
      message = "#{lrules} #{_('locationrules_are_using_this_tariff_cant_delete')}"
      return false, message
    end
    #check for OP
    opts = origination_points.count
    if opts > 0
      message = _('device_op_are_using_this_tariff_cant_delete')
      return false, message
    end
    #check for TP
    tpts = termination_points.count
    if tpts > 0
      message = _('device_tp_are_using_this_tariff_cant_delete')
      return false, message
    end
    comm_use_prov_table = common_use_providers.count
    if comm_use_prov_table > 0
      message = _('common_use_providers_are_using_this_tariff_cant_delete')
      return false, message
    end

    true
  end

  def self.find_by_user(user_id)
    if Confline.get_value("User_Wholesale_Enabled").to_i == 0
      cond = " AND purpose = 'user' "
    else
      cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    end
    Tariff.where("owner_id = #{user_id} #{cond}").order("name ASC")
  end

  def updated
    self.last_update_date = Time.now
    self.save
  end

  private

  def get_user_rate_details(rate, exrate)
    arate_details = Aratedetail.where("rate_id = #{rate.id.to_s} AND artype = 'minute'").order("price DESC").all
    arate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [arate_details[0]['price'].to_d]}) if arate_details.size > 0
    return arate_details, arate_cur
  end

  def nice_number(number, session)
    if !session[:nice_number_digits]
      confline = Confline.get_value("Nice_Number_Digits")
      session[:nice_number_digits] ||= confline.to_i if confline and confline.to_s.length > 0
      session[:nice_number_digits] ||= 2 if !session[:nice_number_digits]
    end
    session[:nice_number_digits] = 2 if session[:nice_number_digits] == ""
    n = ""
    n = sprintf("%0.#{session[:nice_number_digits]}f", number.to_d) if number
    if session[:change_decimal]
      n = n.gsub('.', session[:global_decimal])
    end
    n
  end

  def get_provider_rate_details(rate, exrate)
    rate_details = Ratedetail.where(["rate_id = ?", rate.id]).order("rate DESC").all

    if rate_details.size > 0
      rate_increment_s = rate_details[0]['increment_s']
      rate_cur, rate_free = Currency.count_exchange_prices({:exrate => exrate, :prices => [rate_details[0]['rate'].to_d, rate_details[0]['connection_fee']]})
    end

    return rate_details, rate_cur
  end

  def local_tz_for_import
    Time.now.in_time_zone(Rails.configuration.time_zone).formatted_offset
  end

  def self.tariffs_for_device(current_user_id)
    Tariff.where("purpose = 'provider' OR purpose = 'user_wholesale' AND owner_id = #{current_user_id}")
          .order('name ASC').all
  end

  def update_time
    self.last_update_date = Time.now
    self.save
  end
end
#module ActiveRecord
#  module ConnectionAdapters
#    class MysqlAdapter
#      private
#      def connect_with_local_infile
#        @connection.options(Mysql::OPT_LOCAL_INFILE, 1)
#        connect_without_local_infile
#      end
#      alias_method_chain :connect, :local_infile
#    end
#  end
#end
