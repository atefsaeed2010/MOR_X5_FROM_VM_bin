# -*- encoding : utf-8 -*-
class Call < ActiveRecord::Base
  include SqlExport
  include CsvImportDb
  belongs_to :user
  belongs_to :provider
  belongs_to :device, :foreign_key => "accountcode"
  has_many :cc_actions
  has_one :recording
  has_one :call_detail
  belongs_to :card
  belongs_to :server

  has_and_belongs_to_many :cs_invoices

  validates_presence_of :calldate, :message => _("Calldate_cannot_be_blank")

  attr_protected

  #def device
  #  Device.find(self.accountcode)nice_billsec
  #end
  #
  # Nasty hack to overide provider method. Used in CallController.advanced_list and coresponding view.
  # MK: provider is only Termination provider, if some method needs did provider, then it should use did_provider method
  # MK: callertype=Local/Outside does not show correctly if call is outgoing or incomming, MOR also has calls which are incoming+outgoing at the same time
  alias_method :provider_by_id, :provider

  def provider
    #if self.callertype == 'Local' #outgoing call
    return Provider.where(id: self.provider_id.to_i).first
    #end
    #if self.callertype == 'Outside' #incoming call
    #  return Provider.find(:first, :conditions => "id = #{self.did_provider_id}")
    #end
    #return nil
  end

  def did_provider
    return Provider.where(id: self.did_provider_id.to_i).first
  end

  def nice_billsec
    #it is used to show correct billsec for flat-rates call, because call.billsec = 0 for flatrates, but real_billsec > 0
    # billsec = 0 because to do not ruin rerating and to handle call which part is billed by flat-rate, another part by normal rate
    billsec = self.billsec
    billsec = self.real_billsec.ceil if billsec == 0 and self.real_billsec > 0
    billsec
  end

  def nice_user_billsec
    billsec = self.user_billsec
    billsec = self.real_billsec.ceil if billsec == 0 and self.real_billsec > 0
    billsec
  end

  def Call.nice_billsec_sql
    if User.current.is_user? and Confline.get_value("Invoice_user_billsec_show", User.current.owner.id).to_i == 1
      "CEIL(user_billsec) as 'nice_billsec'"
    elsif User.current.is_reseller?
      "CEIL(reseller_billsec) as 'nice_billsec'"
    else
      "IF((billsec = 0 AND real_billsec > 0), CEIL(real_billsec), billsec) as 'nice_billsec'"
    end
  end

  def Call.nice_answered_cond_sql(search_not = true)
    if User.current.usertype.to_s == 'user' and Confline.get_value('Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users').to_i == 1
      if search_not
        " (calls.disposition='ANSWERED' AND calls.hangupcause='16') "
      else
        " (calls.disposition='ANSWERED' OR (calls.disposition='ANSWERED' AND calls.hangupcause!='16') ) "
      end
    else
      " calls.disposition='ANSWERED' "
    end
  end

  def Call.nice_failed_cond_sql
    if User.current.usertype.to_s == 'user' and Confline.get_value('Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users').to_i == 1
      " (calls.disposition='FAILED' OR (calls.disposition='ANSWERED' and calls.hangupcause!='16')) "
    else
      " calls.disposition='FAILED' "
    end
  end

  def Call.nice_disposition
    if User.current.usertype.to_s == 'user' and Confline.get_value('Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users').to_i == 1
      " IF(calls.disposition  = 'ANSWERED',IF((calls.disposition='ANSWERED' AND calls.hangupcause='16'), 'ANSWERED', 'FAILED'),disposition)"
    else
      " calls.disposition"
    end
  end

  def reseller
    res = nil
    res = User.where(id: self.reseller_id).first if self.reseller_id.to_i > 0
    res
  end

  def destinations
    de = nil
    de = Destination.find(self.prefix) if self.prefix and self.prefix.to_i > 0
    de
  end

  def peerip
    self.call_detail.try :peerip
  end

  def recvip
    self.call_detail.try :recvip
  end

  def sipfrom
    self.call_detail.try :sipfrom
  end

  def uri
    self.call_detail.try :uri
  end

  def useragent
    self.call_detail.try :useragent
  end

  def peername
    self.call_detail.try :peername
  end

  def t38passthrough
    self.call_detail.try :t38passthrough
  end

  # Returns hash with call debuginfo if that info exists otherwise returns nil
  def getDebugInfo
    debug = 0
    debug += self.peerip.size if self.peerip
    debug += self.recvip.size if self.recvip
    debug += self.sipfrom.size if self.sipfrom
    debug += self.uri.size if self.uri
    debug += self.useragent.size if self.useragent
    debug += self.peername.size if self.peername
    #debug += self.t38passthrough.size if self.t38passthrough
    if debug != 0
      debuginfo = Hash.new()
      self.peerip ? debuginfo["peerip"] = self.peerip.to_s : debuginfo["peerip"] = ""
      self.recvip ? debuginfo["recvip"] = self.recvip.to_s : debuginfo["recvip"] =""
      self.sipfrom ? debuginfo["sipfrom"] = self.sipfrom.to_s : debuginfo["sipfrom"] = ""
      self.useragent ? debuginfo["useragent"] = self.useragent.to_s : debuginfo["useragent"] =""
      self.peername ? debuginfo["peername"] = self.peername.to_s : debuginfo["peername"] = ""
      self.uri ? debuginfo["uri"] = self.uri.to_s : debuginfo["uri"] =""
      self.t38passthrough ? debuginfo["t38passthrough"] = self.t38passthrough.to_s : debuginfo["t38passthrough"] = ""
      return debuginfo
    else
      return nil
    end
  end

  def Call::total_calls_by_direction_and_disposition(start_date, end_date, users = [])
    #parameters:
    #  start_date - min date for filtering out calls, expected to be date/datetime
    #    instance or date/datetime as string
    #  end_date - max date for filtering out calls, expected to be date instance or date as
    #    string.
    #  users - array of user id's
    #returns - array of hashs. total call count for incoming and outgoing, answered, not answered,
    #  busy and failed calls grouped by disposition and direction originated or received by
    #  specified users. if no users were specified - for all users
    Call.total_calls_by([], {:outgoing => true, :incoming => true}, start_date, end_date, {:direction => true, :disposition => true}, users)
  end

  def Call::answered_calls_day_by_day(start_date, end_date, users = [])

    raw_calls = Call.total_calls_by(['ANSWERED'], {:outgoing => true, :incoming => true}, start_date, end_date, {:date => true}, users)
    totals = raw_calls.pop
    tz = User.current.time_zone

    start_time = Time.parse(start_date).in_time_zone(tz).strftime('%F')
    end_time = Time.parse(end_date).in_time_zone(tz).strftime('%F')

    dates = (start_time.to_date..end_time.to_date).map{ |date| date.strftime("%F") }
    calls =[]
    t_billsec =[]
    avg_billsec =[]

    date_get = lambda do |i|
      (Time.parse(start_date).in_time_zone(tz) + (i).days).strftime("%F %T")
    end

    dates.each_with_index do |date, i|
      interval = raw_calls.select do |summary|
        date = summary[:calldate].strftime("%F %T")
        date >= date_get[i] && date < date_get[i+1]
      end

      unless interval.blank?

        call_count  = interval.collect(&:total_calls).sum
        billsec     = interval.collect(&:total_billsec).sum

        calls       << call_count
        t_billsec   << billsec
        avg_billsec << (billsec / call_count)
      else
        calls       << 0
        t_billsec   << 0
        avg_billsec << 0
      end
    end

    return dates, calls, t_billsec, avg_billsec, totals
  end

  def Call::total_calls_by(disposition, direction, start_date, end_date, group_options = [], users = [])
    #parameters:
    #  disposition - expected array of dispositions deffined as
    #    strings(why not incapsulate strings by creating class Disposition?)
    #  direction - call direction(outgoing, incoming or both) expected array
    #    of posible directions as contstans or whatever it is:/(again why not
    #    incapsulate it in separate class?)
    #  start_date - min date for filtering out calls, expected to be date/datetime
    #    instance or date/datetime as string
    #  end_date - max date for filtering out calls, expected to be date instance or date as
    #    string. if datetime or datetime sring will be passed QUERY WILL FAIL
    #  users - array of user id's, if not supplied, but direction is it will default to all
    #    incoming and/or outgoing calls
    #returns:
    #  whatever Calls.find returns, and the last element in array will be totals/averages of all fetched values
    select = []
    select << "COUNT(*) AS 'total_calls'"
    select << "SUM(calls.billsec) AS 'total_billsec'"
    select << "AVG(calls.billsec) AS 'average_billsec'"

    condition = []
    condition << "calls.calldate BETWEEN '#{start_date.to_s}' AND '#{end_date.to_s}'"
    #if disposition is not specified or it is all 4 types(answered, failed, busy, no answer),
    #there is no need to filter it
    condition << "calls.disposition IN ('#{disposition.join(', ')}')" if !disposition.empty? and disposition.length < 4

    join = []
    if users.empty?
      if direction.include?(:incoming) and direction.include?(:outgoing)
        condition << "calls.user_id IS NOT NULL"
      else
        condition << 'calls.user_id != -1 AND calls.user_id IS NOT NULL' if direction.include?(:outgoing)
        condition << 'calls.user_id = -1' if direction.include?(:incoming)
      end
    else
      #no mater weather we are allready checking devices for user_id, call.user_id might still be NULL, else we would select
      #to many failed calls
      condition << "calls.user_id IS NOT NULL"
      if direction.include?(:outgoing) and direction.include?(:incoming)
        condition << "(dst_devices.user_id IN (#{users.join(', ')}) OR src_devices.user_id IN (#{users.join(', ')}))"
      end
      if direction.include?(:incoming)
        join << 'LEFT JOIN devices dst_devices ON calls.dst_device_id = dst_devices.id'
        condition << "dst_devices.user_id IN (#{users.join(', ')}" if !direction.include?(:outgoing)
      end
      if direction.include?(:outgoing)
        join << 'LEFT JOIN devices src_devices ON calls.src_device_id = src_devices.id'
        condition << "src_devices.user_id IN (#{users.join(', ')})" if !direction.include?(:incoming)
      end
    end

    #dont group at all, group by date, direction and/or disposition
    #accordingly, we should select those fields from table
    group = []
    if group_options[:date]
      select << "(calls.calldate) AS 'calldate'"
      group << 'year(calldate), month(calldate), day(calldate), hour(calldate)'
    end
    if group_options[:disposition]
      select << 'calls.disposition'
      group << 'calls.disposition' if group_options[:disposition]
    end

    if group_options[:direction]
      if users.empty?
        select << "IF(calls.user_id  = -1, 'incoming', 'outgoing') AS 'direction'"
        group << 'direction'
      else
        if direction.include?(:incoming)
          select << "IF(dst_devices.user_id IN (#{users.join(', ')}), 'incoming', 'outgoing') AS 'direction'"
          group << 'direction'
        end
        if direction.include?(:outgoing) and !direction.include?(:incoming)
          select << "IF(src_device.user_id IN (#{users.join(', ')}), 'outgoing', 'incoming') AS 'direction'"
          group << 'direction'
        end
      end
    end

    if group_options[:date]
      statistics = Call.select(select.join(', ')).joins(join.join(' ')).where(condition.join(' AND ')).group(group.join(', ')).all
      statistics.each do |st|
        st.calldate = (st.calldate.to_time + Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_s(:db) if !st.calldate.blank?
      end
    else
      statistics = Call.select(select.join(', ')).joins(join.join(' ')).where(condition.join(' AND ')).group(group.join(', ')).all
    end

    #calculating total billsec, total calls and average billsec
    total_calls = 0
    total_billsec = 0
    for stats in statistics
      total_calls += stats['total_calls'].to_i
      total_billsec += stats['total_billsec'].to_i
    end
    average_billsec = total_calls == 0 ? 0 : total_billsec/total_calls

    #return array of hashs, bet we should definetly return some sort of Statistics class
    statistics << {'total_calls' => total_calls, 'total_billsec' => total_billsec, 'average_billsec' => average_billsec}
  end

  def Call.calls_order_by(params, options)
    case options[:order_by].to_s.strip
      when "time" then
        order_by = "calls.calldate"
      when "src" then
        order_by = "calls.src"
      when "dst" then
        order_by = "calls.dst"
      when "nice_billsec" then
        order_by = "nice_billsec"
      when "hgc" then
        order_by = "calls.hangupcause"
      when "server" then
        order_by = "calls.server_id"
      when "p_name" then
        order_by = "providers.name"
      when "p_rate" then
        order_by = "calls.provider_rate"
      when "p_price" then
        order_by = "calls.provider_price"
      when "reseller" then
        order_by = "nice_reseller"
      when "r_rate" then
        order_by = "calls.reseller_rate"
      when "r_price" then
        order_by = "calls.reseller_price"
      when "user" then
        order_by = "nice_user"
      when "u_rate" then
        order_by = "calls.user_rate"
      when "u_price" then
        order_by = "calls.user_price"
      when "number" then
        order_by = "dids.did"
      when "d_provider" then
        order_by = "calls.did_prov_price"
      when "d_inc" then
        order_by = "calls.did_inc_price"
      when "d_owner" then
        order_by = "calls.did_price"
      when "prefix" then
        order_by = "calls.prefix"
      when "direction" then
        order_by = "destinations.direction_code"
      when "destination" then
        order_by = "destinations.name"
      when "duration" then
        order_by = "duration"
      when "answered_calls" then
        order_by = "answered_calls"
      when "total_calls" then
        order_by = "total_calls"
      when "cardgroup" then
        order_by = "cardgroups.name"
      when "asr" then
        order_by = "asr"
      when "acd" then
        order_by = "acd"
      when "markup" then
        order_by = "markup"
      when "margin" then
        order_by = "margin"
      when "user_price" then
        order_by = "user_price"
      when "provider_price" then
        order_by = "provider_price"
      when "profit" then
        order_by = "profit"
      else
        order_by = options[:order_by]
    end
    if order_by != ""
      order_by += (options[:order_desc].to_i == 0 ? " ASC" : " DESC")
    end
    return order_by
  end

  def call_log
    c_l = CallLog.where(uniqueid: self.uniqueid).first
    return c_l
  end

  def Call.last_calls(options={})
    cond, var, jn = Call.last_calls_parse_params(options)
    select = ["calls.*", Call.nice_billsec_sql]
    select << SqlExport.nice_user_sql
    #select << 'calls.user_id, users.first_name, users.last_name, card_id, cards.number'
    select << Call.nice_disposition + ' AS disposition'

    #if reseller pro - change common use provider price, rate to reseller tariff rate, price

    select << "(#{SqlExport.reseller_rate_sql} * #{options[:exchange_rate]} ) AS reseller_rate_exrate"

    if options[:current_user].usertype == 'reseller'
      select << "(IF(users.owner_id = #{options[:current_user].id}, 0, did_price) * #{options[:exchange_rate]} ) AS did_price_exrate"
      select << "(IF(users.owner_id = #{options[:current_user].id}, did_inc_price, 0) * #{options[:exchange_rate]} ) AS did_inc_price_exrate"
      select << "(did_prov_price * #{options[:exchange_rate]} ) AS did_prov_price_exrate"
      if options[:current_user].reseller_allow_providers_tariff?
        select << "(#{SqlExport.reseller_provider_rate_sql} * #{options[:exchange_rate]} ) AS provider_rate_exrate"
        select << "(#{SqlExport.reseller_provider_price_sql} * #{options[:exchange_rate]} ) AS provider_price_exrate"
      end
      select << "(#{SqlExport.user_price_no_dids_sql} * #{options[:exchange_rate]} ) AS user_price_exrate"
      select << "(#{SqlExport.reseller_price_no_dids_sql} * #{options[:exchange_rate]} ) AS reseller_price_exrate"
      select << "(#{SqlExport.user_rate_sql} * #{options[:exchange_rate]} ) AS user_rate_exrate"
      select << "(#{SqlExport.reseller_profit_no_dids_sql} * #{options[:exchange_rate]} ) AS profit"
    else
      ['did_price', 'did_inc_price', 'did_prov_price'].each { |co| select << "(#{co} * #{options[:exchange_rate]} ) AS #{co}_exrate" }
      if options[:current_user].usertype == 'user'
        select << "(IF(calls.user_id = #{options[:current_user].id}, #{SqlExport.user_price_sql}, #{SqlExport.user_did_price_sql}) * #{options[:exchange_rate]} ) AS user_price_exrate"
        select << "(#{SqlExport.user_rate_sql} * #{options[:exchange_rate]} ) AS user_rate_exrate"
      else
        select << "(#{SqlExport.user_price_no_dids_sql} * #{options[:exchange_rate]} ) AS user_price_exrate"
        select << "(#{SqlExport.admin_reseller_price_no_dids_sql} * #{options[:exchange_rate]} ) AS reseller_price_exrate"
        select << "(#{SqlExport.admin_user_rate_sql} * #{options[:exchange_rate]} ) AS user_rate_exrate"
        select << "(#{SqlExport.admin_provider_rate_sql} * #{options[:exchange_rate]}) AS provider_rate_exrate "
        select << "(#{SqlExport.admin_provider_price_sql} * #{options[:exchange_rate]} ) AS provider_price_exrate"
        select << "(#{SqlExport.admin_profit_sql} + #{options[:s_user_id] == '-2' ? 'calls.did_price + calls.did_prov_price' : '(IF(calls.user_id = ' + options[:s_user_id].to_s + ', calls.did_prov_price, calls.did_price - calls.did_inc_price))'}) * #{options[:exchange_rate]} AS profit"
      end
    end
    select << "IF(resellers.id > 0, #{SqlExport.nice_user_sql("resellers", nil)}, '') AS 'nice_reseller'"
    if options[:show_device_and_cid].to_i == 1
      select << "CONCAT(src_device.device_type, '/', src_device.extension, ' (', IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ''), ')') AS nice_src_device"
      jn << "LEFT JOIN devices AS src_device ON (src_device.id = calls.src_device_id)"
    end
    selected_page = options[:page].to_i - 1
    selected_page = 1 if (selected_page < 0)
    Call.select(select.join(", \n")).
        joins(jn.join(" \n")).
        where([cond.join(" \nAND "), *var]).
        order(options[:order]).
        limit("#{(selected_page * options[:items_per_page].to_i).to_i}, #{options[:items_per_page].to_i}").all
  end

  def Call.last_calls_total_stats(options={})
    options[:exchange_rate] ||= 1
    cond, var, jn = Call.last_calls_parse_params(options)
    #if reseller pro - change common use provider price, rate to reseller tariff rate, price
    if options[:current_user].usertype == 'reseller'
      prov_price = "(SUM(#{SqlExport.reseller_provider_price_sql}) * #{options[:exchange_rate].to_d}) as total_provider_price"
      profit = "(SUM(IF(calls.user_id = #{options[:current_user].id}, 0, #{SqlExport.reseller_profit_no_dids_sql})) * #{options[:exchange_rate].to_d}) AS total_profit"
      user_price = SqlExport.user_price_no_dids_sql
      reseller_price = SqlExport.reseller_price_no_dids_sql
      did_price = "SUM(IF(users.owner_id = #{options[:current_user].id}, 0, did_price)) * #{options[:exchange_rate].to_d} as total_did_price"
      did_inc_price = "SUM(IF(users.owner_id = #{options[:current_user].id}, did_inc_price, 0)) * #{options[:exchange_rate].to_d} as total_did_inc_price"
    else
      prov_price = "(SUM(#{SqlExport.admin_provider_price_sql}) * #{options[:exchange_rate].to_d}) as total_provider_price"
      profit = "(SUM(#{SqlExport.admin_profit_sql} + #{options[:s_user_id] == '-2' ? 'calls.did_price + calls.did_prov_price' : '(IF(calls.user_id = ' + options[:s_user_id].to_s + ', calls.did_prov_price , calls.did_price - calls.did_inc_price))'}) * #{options[:exchange_rate].to_d}) AS total_profit"
      user_price = SqlExport.user_price_no_dids_sql
      reseller_price = SqlExport.admin_reseller_price_no_dids_sql
      did_price = "SUM(did_price) * #{options[:exchange_rate].to_d} as total_did_price"
      did_inc_price = "SUM(did_inc_price) * #{options[:exchange_rate].to_d} as total_did_inc_price"
    end

    if User.current.is_user? and Confline.get_value("Invoice_user_billsec_show", User.current.owner.id).to_i == 1
      billsec_sql = "CEIL(user_billsec)"
    elsif User.current.is_reseller?
      billsec_sql = "CEIL(reseller_billsec)"
    else
      billsec_sql = "IF((billsec = 0 AND real_billsec > 0), CEIL(real_billsec), billsec)"
    end

    Call.select("
                 COUNT(*) as total_calls,
                 SUM(#{billsec_sql}) as total_duration,
                 SUM(IF(calls.user_id = #{options[:current_user].id}, #{SqlExport.user_price_sql}, #{options[:current_user].usertype == "user" ? SqlExport.user_did_price_sql : SqlExport.user_price_no_dids_sql})) * #{options[:exchange_rate].to_d} as total_user_price_with_dids,

                 SUM(#{user_price}) * #{options[:exchange_rate].to_d} as total_user_price,
                 SUM(#{reseller_price}) * #{options[:exchange_rate].to_d} as total_reseller_price,
                 SUM(#{SqlExport.admin_reseller_price_no_dids_sql}) * #{options[:exchange_rate].to_d} as total_reseller_price_with_dids,
                 SUM(did_prov_price) * #{options[:exchange_rate].to_d} as total_did_prov_price,
                 #{did_price}, #{did_inc_price}, " + prov_price + "," + profit
    ).joins(jn.join(" \n")).where([cond.join(' AND '), *var]).first
  end

  def Call.last_calls_csv(options={})
    cond, var, jn = Call.last_calls_parse_params(options)
    s =[]
    headers = []
    format = Confline.get_value('Date_format', (options[:current_user].usertype == 'reseller' ? options[:current_user].id : options[:current_user].owner_id)).gsub('M', 'i')
    csv_full_src = true if options[:show_full_src].to_i == 1
    #calldate2 - because something overwites calldate when changing date format
    time_offset = options[:current_user].time_offset
    if options[:api].to_i == 1
      format = '%Y-%m-%d %H:%i:%S'
      headers << "'#{_('Date')}'" + ' AS calldate2'
      s << SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', {:format => format, :offset => 0}), "calldate2")
      headers << "'#{_('UniqueID')}'" + ' AS uniqueid'
      s << SqlExport.column_escape_null('calls.uniqueid', 'uniqueid')
    else
      headers << "'#{_('Date')}'" + ' AS calldate2'
      s << SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', {:format => format, :offset => time_offset}), "calldate2")
    end
    unless csv_full_src
      headers << "'#{_('Source')}'" + ' AS src'
      s << SqlExport.column_escape_null("calls.src", "src")
    end
    if csv_full_src or options[:pdf].to_i == 1
      headers << "'#{_('Called_from')}'" + ' AS clid'
      s << SqlExport.column_escape_null("calls.clid", "clid")
    end
    headers << "'#{_('Called_to')}'" + ' AS dst'
    options[:current_user].usertype == 'user' ? s << SqlExport.hide_dst_for_user_sql(options[:current_user], "csv", SqlExport.column_escape_null("calls.localized_dst"), {:as => "dst"}) : s << SqlExport.column_escape_null("calls.localized_dst", "dst")
    if options[:current_user].usertype != 'reseller'
      headers << "'#{_('Prefix')}'" + ' AS prefix'
      s << SqlExport.column_escape_null("calls.prefix", "prefix")
    end
    headers << "'#{_('Destination')}'" + ' AS destination'
    s << "CONCAT(#{SqlExport.column_escape_null("directions.name")}, ' ', #{SqlExport.column_escape_null("destinations.subcode")}, ' ', #{SqlExport.column_escape_null("destinations.name")}) as destination"
    headers << "'#{_('Duration')}'" + ' AS nice_billsec'
    s << Call.nice_billsec_sql

    headers << "'#{_('hangup_cause')}'" + ' AS dispod'
    if options[:current_user].usertype != 'user' or (Confline.get_value('Show_HGC_for_Resellers').to_i == 1 and options[:current_user].usertype == 'reseller')
      s << SqlExport.column_escape_null("CONCAT(#{SqlExport.column_escape_null("calls.disposition")}, '(', #{SqlExport.column_escape_null("calls.hangupcause")}, ')')", 'dispod')
    else
      s << SqlExport.column_escape_null(Call.nice_disposition, 'dispod')
    end
    if options[:current_user].usertype == "admin" or options[:current_user].usertype == "accountant"
      headers << "'#{_('Server')}'" + ' AS server_id'
      s << SqlExport.column_escape_null("calls.server_id", "server_id")
      headers << "'#{_('Provider_name')}'" + ' AS provider_name'
      s << SqlExport.column_escape_null("providers.name", "provider_name")
      if options[:can_see_finances]
        headers << "'#{_('Provider_rate')}'" + ' AS provider_rate'
        headers << "'#{_('Provider_price')}'" + ' AS provider_price'
        s << SqlExport.replace_dec("(IF(calls.provider_rate IS NULL, 0, #{SqlExport.admin_provider_rate_sql}) * #{options[:exchange_rate]} )", options[:column_dem], 'provider_rate')
        s << SqlExport.replace_dec("(IF(calls.provider_price IS NULL, 0, #{SqlExport.admin_provider_price_sql}) * #{options[:exchange_rate]} )", options[:column_dem], 'provider_price')
      end
      if Confline.get_value('RS_Active').to_i == 1
        nice_reseller = "IF(resellers.id != 0,IF(LENGTH(resellers.first_name+resellers.last_name) > 0, CONCAT(resellers.first_name, ' ',resellers.last_name ), resellers.username), ' ')"
        headers << "'#{_('Reseller')}'" + ' AS nice_reseller'
        s << "IF(#{nice_reseller} IS NULL, ' ', #{nice_reseller}) as 'nice_reseller'"
        if options[:can_see_finances]
          headers << "'#{_('Reseller_rate')}'" + ' AS reseller_rate'
          headers << "'#{_('Reseller_price')}'" + ' AS reseller_price'
          s << SqlExport.replace_dec("(#{SqlExport.admin_reseller_rate_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'reseller_rate')
          s << SqlExport.replace_dec("(#{SqlExport.admin_reseller_price_no_dids_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'reseller_price')
        end
      end

      headers << "'#{_('User')}'" + ' AS user'
      s << "IF(calls.card_id = 0 ,IF(users.first_name = '' and users.last_name = '', users.username, (#{SqlExport.nice_user_sql('users', false)})), CONCAT('Card#', IF(cards.number IS NULL, '', cards.number))) as 'user'"
      if options[:show_device_and_cid].to_i == 1
        headers << "'#{_('Device')}'" + ' AS nice_src_device'
        s << "CONCAT(src_device.device_type, '/', src_device.extension, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ')') AS nice_src_device"
        jn << "LEFT JOIN devices AS src_device ON (src_device.id = calls.src_device_id)"
      end
      if options[:can_see_finances]
        headers << "'#{_('User_rate')}'" + ' AS user_rate'
        headers << "'#{_('User_price')}'" + ' AS user_price'
        s << SqlExport.replace_dec("(IF(calls.user_rate IS NULL, 0, #{SqlExport.user_rate_sql}) * #{options[:exchange_rate]} )", options[:column_dem], 'user_rate')
        s << SqlExport.replace_dec("(IF(calls.user_price IS NULL, 0, #{SqlExport.user_price_no_dids_sql}) * #{options[:exchange_rate]} ) ", options[:column_dem], 'user_price')
      end
      headers << "'#{_('DID_Number')}'" + ' AS did'
      s << "IF(dids.did IS NULL, '' , dids.did) AS 'did'"
      if options[:can_see_finances]
        headers << "'#{_('DID_provider_price')}'" + ' AS did_prov_price'
        headers << "'#{_('DID_incoming_price')}'" + ' AS did_inc_price'
        headers << "'#{_('DID_Price')}'" + ' AS did_price'
        s << SqlExport.replace_dec("(IF(calls.did_prov_price IS NULL, 0, calls.did_prov_price) * #{options[:exchange_rate]} ) ", options[:column_dem], 'did_prov_price')
        s << SqlExport.replace_dec("(IF(calls.did_inc_price IS NULL, 0, calls.did_inc_price) * #{options[:exchange_rate]} ) ", options[:column_dem], 'did_inc_price')
        s << SqlExport.replace_dec("(IF(calls.did_price IS NULL, 0 , calls.did_price) * #{options[:exchange_rate]} ) ", options[:column_dem], 'did_price')
      end
    end
    if options[:current_user].show_billing_info == 1 and options[:can_see_finances]
      if options[:current_user].usertype == 'reseller'
        if options[:current_user].reseller_allow_providers_tariff?
          if options[:provider]
            headers << "'#{_('Provider_ID')}'" + ' AS provider_id'
            s << 'providers.id AS provider_id'
          end
          headers << "'#{_('Provider_name')}'" + ' AS provider_name'
          headers << "'#{_('Provider_rate')}'" + ' AS provider_rate'
          headers << "'#{_('Provider_price')}'" + ' AS provider_price'
          s << SqlExport.column_escape_null("IF(providers.user_id = 0 AND providers.common_use = 0, 'admin', providers.name)", 'provider_name')
          s << SqlExport.replace_dec("(IF(calls.provider_rate IS NULL, 0, #{SqlExport.reseller_provider_rate_sql}) * #{options[:exchange_rate]} )", options[:column_dem], 'provider_rate')
          s << SqlExport.replace_dec("(IF(calls.provider_price IS NULL, 0, #{SqlExport.reseller_provider_price_sql}) * #{options[:exchange_rate]} ) ", options[:column_dem], 'provider_price')
        end
        headers << "'#{_('User')}'" + ' AS user'
        s << "IF(calls.card_id = 0 ,IF(users.first_name = '' and users.last_name = '', users.username, (#{SqlExport.nice_user_sql('users', false)})), CONCAT('Card#', IF(cards.number IS NULL, '', cards.number))) as 'user'"
        if options[:show_device_and_cid].to_i == 1
          headers << "'#{_('Device')}'" + ' AS nice_src_device'
          s << "CONCAT(src_device.device_type, '/', src_device.extension, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ')') AS nice_src_device"
          jn << "LEFT JOIN devices AS src_device ON (src_device.id = calls.src_device_id)"
        end
        headers << "'#{_('User_rate')}'" + ' AS user_rate'
        headers << "'#{_('User_price')}'" + ' AS user_price'
        s << SqlExport.replace_dec("(#{SqlExport.user_rate_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'user_rate')
        s << SqlExport.replace_dec("(IF(#{SqlExport.user_price_no_dids_sql} != 0 , (#{SqlExport.user_price_no_dids_sql}), 0) * #{options[:exchange_rate]} ) ", options[:column_dem], 'user_price')
        headers << "'#{_('DID_Number')}'" + ' AS did'
        headers << "'#{_('DID_Number')}'" + ' AS did_inc_price'
        headers << "'#{_('DID_Price')}'" + ' AS did_price'
        s << "IF(dids.did IS NULL , '' , dids.did) AS 'did'"
        s << SqlExport.replace_dec("(IF(calls.did_inc_price IS NULL OR users.owner_id = #{options[:current_user].id}, calls.did_inc_price, 0) * #{options[:exchange_rate]} ) ", options[:column_dem], 'did_inc_price')
        s << SqlExport.replace_dec("(IF(calls.did_price IS NULL OR users.owner_id != #{options[:current_user].id}, calls.did_price, 0) * #{options[:exchange_rate]} ) ", options[:column_dem], 'did_price')
      elsif options[:current_user].usertype == 'user'
        if options[:show_device_and_cid].to_i == 1
          headers << "'#{_('Device')}'" + ' AS nice_src_device'
          s << "CONCAT(src_device.device_type, '/', src_device.extension, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ')') AS nice_src_device"
          jn << "LEFT JOIN devices AS src_device ON (src_device.id = calls.src_device_id)"
        end
        headers << "'#{_('User_price')}'" + ' AS user_price'
        s << SqlExport.replace_dec("((IF(calls.user_id = #{options[:current_user].id},#{SqlExport.user_price_sql},calls.did_price)) * #{options[:exchange_rate]} ) ", options[:column_dem], "user_price")
      end
    end

    if options[:current_user].usertype == "admin" or options[:current_user].usertype == "accountant"
      if options[:can_see_finances]
        headers << "'#{_('Profit')}'" + ' AS profit'
        if options[:user] && ((options[:s_user] != 'all') || (options[:s_user_id].present? && (options[:s_user_id].to_s != '-2')))
          s << SqlExport.replace_dec("(IF(calls.user_id = #{options[:user].id},#{SqlExport.admin_profit_sql} + calls.did_prov_price,calls.did_price) * #{options[:exchange_rate]})", options[:column_dem], 'profit')
        else
          s << SqlExport.replace_dec("((#{SqlExport.admin_profit_sql} + calls.did_price + calls.did_prov_price) * #{options[:exchange_rate]})", options[:column_dem], 'profit')
        end
      end
    elsif options[:current_user].usertype == 'reseller'
      if options[:can_see_finances]
        headers << "'#{_('Profit')}'" + ' AS profit'
        s << SqlExport.replace_dec("(#{SqlExport.reseller_profit_no_dids_sql} * #{options[:exchange_rate]})", options[:column_dem], 'profit')
      end
    end


    filename = "Last_calls-#{options[:current_user].id.to_s.gsub(" ", "_")}-#{options[:from].gsub(" ", "_").gsub(":", "_")}-#{options[:till].gsub(" ", "_").gsub(":", "_")}-#{DateTime.now.strftime('%Q').to_i}"
    sql = "SELECT * "
    if options[:pdf].to_i == 0 and options[:test] != 1
      sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{options[:collumn_separator]}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
    end
    #Call.last_calls_parse_params might return "LEFT JOIN destinations ..."
    #if condition below is met, in that case we should not join destinations again
    #it is very important to join tables in this paricular order DO NOT CHANGE IT

    # setting headers
    header_sql = "SELECT " + headers.join(', ') + ' UNION ' if options[:csv]

    sql += " FROM (#{header_sql.to_s} (SELECT #{s.join(', ')}
             FROM calls "
    unless options[:s_country] and !options[:s_country].blank?
      sql += "LEFT JOIN destinations ON (destinations.prefix = IF(calls.prefix IS NULL, '', calls.prefix)) "
    end
    sql += jn.join(' ')
    sql += "LEFT JOIN directions ON (directions.code = destinations.direction_code)"
    sql += "WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} ORDER BY #{options[:order].gsub('nice_user', 'user')} )) AS C"

    test_content = ""
    if options[:test].to_i == 1
      mysql_res = ActiveRecord::Base.connection.select_all(sql)
      test_content = mysql_res.to_a.to_json
    else
      if options[:pdf].to_i == 1
        filename = Call.find_by_sql(sql)
      else
        ActiveRecord::Base.connection.execute(sql)
      end
    end
    return filename, test_content
  end

  def Call.calls_for_laod_stats(options={})
    cond= ['calldate BETWEEN ? AND ?']
    var = [options[:a1], options[:a2]]

    if options[:s_server].to_i != -1 and options[:current_user].usertype != 'reseller'
      cond << 'server_id = ?'; var << options[:s_server]
    end

    if options[:s_user].to_i != -1
      cond << 'user_id = ? '; var << options[:s_user] # AND b.user_id = '#{@search_user}' "
      if options[:s_device].to_i != -1
        cond << 'src_device_id = ?'; var << options[:s_device] # AND b.src_device_id = '#{@search_device}'"
      end
    end

    if options[:s_reseller].to_i != -1
      cond << 'calls.reseller_id = ? '; var << options[:s_reseller]
    end

    if options[:s_direction] != -1
      case options[:s_direction].to_s
        when "outgoing"
          cond << 'did_id= 0'
        when "incoming"
          cond << "did_id > 0 AND callertype = 'Local'"
        when "mixed"
          cond << "did_id > 0 AND callertype = 'Outside'"
      end
    end

    if options[:s_provider].to_i != -1
      cond << 'provider_id = ?'; var << options[:s_provider]
    end

    if !options[:s_did].blank? and options[:current_user].usertype != 'reseller'
      cond << "dst= ?"; var << options[:s_did]
    end

    if options[:current_user].usertype == "reseller"
      cond << "(calls.reseller_id = ? OR calls.user_id = ? OR calls.dst_user_id = ?)"
      var += [options[:current_user].id, options[:current_user].id, options[:current_user].id]
    end

    c2 = Call.select('calldate, duration').where([cond.join(' AND ').to_s] + var).all
    cond << "disposition = 'ANSWERED'"
    calls1 = Call.select('calldate, duration').where([cond.join(' AND ').to_s] + var).all
    highest_duration = Call.where([cond.join(' AND ')] + var).maximum(:duration)
    return calls1, c2, highest_duration
  end

  def Call.country_stats(options={})

    cond = []
    var = []

    if options[:user_id]
      if options[:user_id].to_s != '-1'
        cond << 'calls.user_id = ? '
        var << options[:user_id]
      end
    end

    if options[:current_user].usertype == "reseller"
      cond << "(calls.reseller_id = ? OR calls.user_id = ? OR calls.dst_user_id = ?)"
      var += [options[:current_user].id, options[:current_user].id, options[:current_user].id]
      user_price = SqlExport.replace_price(SqlExport.user_price_sql)
      provider_price =SqlExport.replace_price(SqlExport.reseller_provider_price_sql)
    else
      user_price = SqlExport.replace_price(SqlExport.admin_user_price_sql)
      provider_price =SqlExport.replace_price(SqlExport.admin_provider_price_sql)
    end

    cond << "calls.calldate BETWEEN ? AND ?"
    var += ["#{options[:a1]}", "#{options[:a2]}"]

    cond << 'calls.disposition = "ANSWERED"'

    calls_all = Call.
        from('calls FORCE INDEX (calldate)').
        where([cond.join(' AND ').to_s] + var).
        select("COUNT(*) as 'calls', SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) as 'billsec', SUM(#{provider_price}) as 'selfcost', SUM(#{user_price}) as 'price', SUM(#{user_price}-#{provider_price}) as calls_profit").
        joins("LEFT JOIN destinations ON (destinations.prefix = calls.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.left_join_reseler_providers_to_calls_sql}").all

    calls = Call.
        from('calls FORCE INDEX (calldate)').
        where([cond.join(' AND ').to_s] + var).
        select("destinations.direction_code as 'direction_code', destinationgroups.id, destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', destinationgroups.desttype as 'dg_type',  COUNT(*) as 'calls', SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) as 'billsec', SUM(#{provider_price}) as 'selfcost', SUM(#{user_price}) as 'price'").
        joins("LEFT JOIN destinations ON (destinations.prefix = calls.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.left_join_reseler_providers_to_calls_sql}").
        group('destinationgroups.id').
        order('destinationgroups.name ASC, destinationgroups.desttype ASC').all

    calls_for_pie_graph = Call.
        from('calls FORCE INDEX (calldate)').
        where([cond.join(' AND ').to_s] + var).
        select("destinationgroups.name as 'dg_name', destinationgroups.desttype as 'dg_type',SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) as 'billsec'").
        joins("LEFT JOIN destinations ON (destinations.prefix = calls.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.left_join_reseler_providers_to_calls_sql}").
        group('destinationgroups.id').
        order('billsec desc').all

    calls_for_price = Call.
        from('calls FORCE INDEX (calldate)').
        where([cond.join(' AND ').to_s] + var).
        select("destinationgroups.name as 'dg_name', destinationgroups.desttype as 'dg_type',  SUM(#{user_price}) as 'price'").
        joins("LEFT JOIN destinations ON (destinations.prefix = calls.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.left_join_reseler_providers_to_calls_sql}").
        group('destinationgroups.id').
        order('price desc').all

    calls_for_profit = Call.
        from('calls FORCE INDEX (calldate)').
        where([cond.join(' AND ').to_s] + var).
        select("destinationgroups.name as 'dg_name', destinationgroups.desttype as 'dg_type', SUM(#{user_price}-#{provider_price}) as calls_profit").
        joins("LEFT JOIN destinations ON (destinations.prefix = calls.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.left_join_reseler_providers_to_calls_sql}").
        group('destinationgroups.id').
        order('calls_profit desc').all

    #---------- Graphs ------------
    #    Countries times for pie
    all = 0
    country_times_pie= "\""
    if calls_for_pie_graph and calls_for_pie_graph.size.to_i > 0
      calls_for_pie_graph.each_with_index { |c, i|
        pull = i == 1 ? 'true' : 'false'
        if i < 6
          country_times_pie += c.dg_name.to_s + " " + c.dg_type + ";" + (c.billsec.to_i / 60).to_s + ";" + pull + "\\n"
        else
          all += c.billsec
        end
      }
      country_times_pie += _('Others') + ";" + (all.to_i / 60).to_s + ";false\\n"
    else
      country_times_pie += _('No_result') + ";1;false\\n"
    end
    country_times_pie += "\""

    #------- Countries profit graph ----------
    all = 0
    countries_profit_pie = "\""
    if calls_for_profit and calls_for_profit.size.to_i > 0
      calls_for_profit.each_with_index { |c, i|
        pull = i == 1 ? 'true' : 'false'
        if i < 6
          countries_profit_pie += c.dg_name.to_s + " " + c.dg_type + ";" + (Email.nice_number(c.calls_profit.to_d)).to_s + ";" + pull + "\\n"
        else
          all += c.calls_profit.to_d
        end
      }
      countries_profit_pie+= _('Others') + ";" + Email.nice_number(all.to_d > 0.to_d ? all.to_d : 0).to_s + ";false\\n"
    else
      countries_profit_pie+= _('No_result') + ";1;false\\n"
    end
    countries_profit_pie += "\""

    #------- Countries incomes graph ----------
    all = 0
    countries_incomes_pie = "\""
    if calls_for_price and calls_for_price.size.to_i > 0
      calls_for_price.each_with_index { |c, i|
        pull = i == 1 ? 'true' : 'false'
        if i < 6
          countries_incomes_pie += c.dg_name.to_s + " " + c.dg_type + ";" + Email.nice_number(c.price.to_d).to_s + ";" + pull + "\\n"
        else
          all += c.price.to_d
        end
      }
      countries_incomes_pie+= _('Others') + ";" + Email.nice_number(all.to_d).to_s + ";false\\n"
    else
      countries_incomes_pie+= _('No_result') + ";1;false\\n"
    end
    countries_incomes_pie += "\""

    return calls, country_times_pie, countries_profit_pie, countries_incomes_pie, calls_all

  end

  def Call.hangup_cause_codes_stats(options={})
    cond = []; var = []
    cond2 = []

    if options[:user_id].to_i != -1
      cond << 'c.user_id = ? '; var << options[:user_id]
    end

    if options[:device_id].to_i != -1
      cond << "(c.src_device_id = ? OR c.dst_device_id = ?)"
      var +=[options[:device_id].to_i, options[:device_id].to_i]
    end

    if options[:provider_id].to_i != -1
      cond << "((c.provider_id = ? and c.callertype = 'Local') OR (c.did_provider_id = ? and c.callertype = 'Outside'))"
      var +=[options[:provider_id].to_i, options[:provider_id].to_i]
    end

    des = ''
    if options[:country_code] and !options[:country_code].blank?
      cond2 << "de.direction_code = '#{options[:country_code]}'"
      des = 'LEFT JOIN destinations de ON (c.prefix = de.prefix)'
    end

    if options[:current_user].usertype == "reseller"
      cond << "(c.reseller_id = ? OR c.user_id = ? OR c.dst_user_id = ?)"
      var += [options[:current_user].id, options[:current_user].id, options[:current_user].id]
    end

    cond << "c.calldate BETWEEN ? AND ?"
    var += [options[:a1].to_s, options[:a2].to_s]

    sql = "SELECT c.hc_code, COUNT(c.clid) AS 'calls', h.id, h.code, h.description FROM(
              SELECT c.hangupcause AS 'hc_code', c.clid, c.prefix
              FROM calls c FORCE INDEX (calldate)
              WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])}) c
           LEFT JOIN hangupcausecodes h ON (c.hc_code = h.code) #{des} " + (!cond2.blank? ? "WHERE " + cond2.join(' AND ') : "") + " GROUP BY c.hc_code"

    select = Call.find_by_sql(sql)
    calls = select.sort_by{|c| c.hc_code.to_i}

    code_calls = select.sort_by{|c| c.calls}.reverse

    format = Confline.get_value('Date_format', (options[:current_user].usertype == 'reseller' ? options[:current_user].id : options[:current_user].owner_id)).gsub('%H:%M:%S', '')

    date_period = []
    a1 = !options[:a1].blank? ? options[:a1] : Date.today.to_s
    a2 = !options[:a2].blank? ? options[:a2] : Date.today.to_s
    a2 = a1 if a1.to_date > a2.to_date

   day_calls = Call.find_by_sql("SELECT #{SqlExport.nice_date('DATE(calldate)', {:reference => 'call_date_formated', :format => format, :tz => options[:current_user].time_offset})},
                                SUM(IF(hangupcause = 16, 1, 0)) AS calls,
                                SUM(IF(hangupcause != 16, 1, 0)) AS bad_calls
                                FROM calls c #{des} WHERE #{ ActiveRecord::Base.sanitize_sql_array([(cond + cond2 + ["hangupcause != ''"]).join(' AND '), *var])}
                                GROUP BY call_date_formated LIMIT 1000;")
    #---------- Graphs ------------
    #    Hangup causes codes for pie
    all = 0
    hcc_pie= "\""
    calls_size = 0
    if code_calls and code_calls.size.to_i > 0
      code_calls.each_with_index { |c, i|
        pull = i == 1 ? 'true' : 'false'
        if i < 6
          hcc_pie += c.hc_code.to_s + ";" + (c.calls.to_i).to_s + ";" + pull + "\\n"
        else
          all += c.calls.to_i
        end
        calls_size +=c.calls.to_i
      }
      hcc_pie += _('Others') + ";" + all.to_s + ";false\\n"
    else
      hcc_pie += _('No_result') + ";1;false\\n"
    end
    hcc_pie += "\""

    #    Hangup causes codes for line
    if day_calls.blank?
      hcc_graph = _('No_result')
    else
      hcc_graph = []
      day_calls.each do |call|
        hcc_graph << "#{call.call_date_formated};#{call.calls};#{call.bad_calls}"
      end
      hcc_graph = hcc_graph.join("\\n")
    end

    return calls, hcc_pie, hcc_graph, calls_size
  end

  def Call.cardgroup_aggregate(options={})
    group_by = []
    options[:destination_grouping] == 1 ? group_by << "destinations.direction_code, destinations.prefix" : group_by << "destinations.direction_code, destinations.subcode"
    group_by << "cards.cardgroup_id" if options[:cardgroup] == "any"

    cond = ["calldate BETWEEN ? AND ?"]
    var = [options[:from], options[:till]]
    if  options[:prefix].to_s != ""
      cond << "calls.prefix LIKE ?"
      var << options[:prefix].gsub(/[^0-9]/, "").to_s + "%"
    end

    if options[:cardgroup] == "any"
      cond << "cards.cardgroup_id IN (SELECT id FROM cardgroups WHERE owner_id = ?)"
      var << options[:user_id]
    else
      cond << "cards.cardgroup_id = ?"
      var << options[:cardgroup].to_i
    end

    s = []

    if options[:csv].to_i == 0
      s << "IF(calls.prefix = '', '#{_('Calls_To_Dids')}', calls.prefix ) AS prefix, directions.name as 'dir_name', destinations.direction_code AS 'code', destinations.subcode AS 'subcode', destinations.name AS 'dest_name'"
    else
      if options[:destination_grouping].to_i == 1
        s << SqlExport.column_escape_null("CONCAT(directions.name, ' ', destinations.subcode, ' ', destinations.name, ' (',  calls.prefix, ') ' )", "direct_name", "#{_('Calls_To_Dids')}")
      else
        s << SqlExport.column_escape_null("CONCAT(directions.name, ' ', destinations.subcode, ' (',  calls.prefix, ') ')", "direct_name", "#{_('Calls_To_Dids')}")
      end
    end
    s << "cardgroups.name AS  'cardgroup_name'"
    s << SqlExport.column_escape_null("SUM(IF(calls.disposition = 'ANSWERED', calls.billsec, 0))", 'duration', 0)
    s << SqlExport.column_escape_null("SUM(IF(calls.disposition = 'ANSWERED', 1,0))", 'answered_calls', 0)
    s << SqlExport.column_escape_null("COUNT(*)", 'total_calls', 0)
    s << SqlExport.column_escape_null("SUM(IF(calls.disposition = 'ANSWERED', 1,0))/COUNT(*)*100", 'asr', 0)
    s << SqlExport.column_escape_null("SUM(IF(calls.disposition = 'ANSWERED', calls.billsec, 0))/SUM(IF(calls.disposition = 'ANSWERED', 1,0))", 'acd', 0)
    s << SqlExport.column_escape_null("SUM(calls.provider_price)", "provider_price", 0)
    s << SqlExport.column_escape_null("SUM(calls.user_price)", "user_price", 0)
    s << SqlExport.column_escape_null("SUM(calls.user_price) - SUM(calls.provider_price)", 'profit', 0)
    s << SqlExport.column_escape_null("IF((SUM(calls.user_price) != 0 OR SUM(calls.provider_price) != 0),(((SUM(calls.user_price) - SUM(calls.provider_price)) / SUM(calls.user_price)) * 100),0)", 'margin', 0)
    s << SqlExport.column_escape_null("IF((SUM(calls.user_price) != 0 OR SUM(calls.provider_price) != 0),(((SUM(calls.user_price) / SUM(calls.provider_price)) * 100 ) - 100), 0)", 'markup', 0)
    order = !options[:order].to_s.blank? ? 'ORDER BY ' + options[:order] : ''
    group = group_by.size > 0 ? 'GROUP BY ' +group_by.join(", ") : ''

    jn = ["LEFT JOIN devices ON (calls.src_device_id = devices.id)", "LEFT JOIN users ON (users.id = devices.user_id)", "JOIN cards ON (cards.id = calls.card_id)", "LEFT JOIN cardgroups ON (cardgroups.id = cards.cardgroup_id)", "LEFT JOIN destinations ON (destinations.prefix = calls.prefix)", "LEFT JOIN directions ON (directions.code = destinations.direction_code)"]

    if options[:csv].to_i == 1
      filename = "Cardgroups_aggregate-#{options[:from].gsub(" ", "_").gsub(":", "_")}-#{options[:till].gsub(" ", "_").gsub(":", "_")}-#{Time.now().to_i}"
      sql = "SELECT * "
      if options[:test].to_i != 1
        sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{options[:collumn_separator]}' OPTIONALLY ENCLOSED BY '#{''}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
      end
      sql += " FROM (SELECT #{s.join(', ')} FROM calls #{jn.join(' ')}  WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} #{group}  #{order}  ) as C"

      data = ''
      if options[:test].to_i == 1
        mysql_res = ActiveRecord::Base.connection.select_all(sql)
        MorLog.my_debug(sql)
        MorLog.my_debug("------------------------------------------------------------------------")
        MorLog.my_debug(mysql_res.to_yaml)
        data << mysql_res.to_json
      else
        mysql_res = ActiveRecord::Base.connection.execute(sql)
      end
      return filename, data
    else
      sql = "SELECT #{s.join(', ')} FROM calls #{jn.join(' ')}  WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])}  #{group}  #{order} "
      mysql_res = Call.find_by_sql(sql)
      return mysql_res
    end
  end

  def Call.analize_cdr_import(name, options)
    CsvImportDb.log_swap('analyze')
    MorLog.my_debug("CSV analyze_file #{name}", 1)
    arr = {}
    current_user = User.current.id
    arr[:calls_in_db] = Call.count(:all, :conditions => {:reseller_id => current_user}).to_i
    arr[:clis_in_db] = Callerid.count(:all, :joins => 'JOIN devices ON (devices.id = callerids.device_id) JOIN users ON (devices.user_id = users.id)', :conditions => "users.owner_id = #{current_user}").to_i

    if options[:step] and options[:step] == 8
      arr[:step] = 8
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 0, nice_error = 0 where id > 0")
    else
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET not_found_in_db = 0, f_error = 0, nice_error = 0 where id > 0")
    end

    if options[:imp_clid] and options[:imp_clid] >= 0
      #set flag on not found and count them
      str = if options[:create_callerid].to_i.zero?
              'f_error = 1, nice_error = 8'
            else
              'not_found_in_db = 1'
            end
      found_clis = ActiveRecord::Base.connection.select_all("SELECT col_#{options[:imp_clid]} FROM #{name}  JOIN callerids ON (callerids.cli = replace(col_#{options[:imp_clid]}, '\\r', ''))
                                                                                                            JOIN devices ON devices.id = callerids.device_id
                                                                                                            JOIN users ON users.id = devices.user_id
                                                                                                            JOIN users owners ON users.owner_id = owners.id
                                                                                                            WHERE users.owner_id = #{current_user} OR (#{current_user} = 0 AND owners.usertype = 'reseller' AND owners.own_providers = 0)")
      idsclis = ["'not_found'"]
      found_clis.each { |id| idsclis << id["col_#{options[:imp_clid]}"].to_s }
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET #{str} where col_#{options[:imp_clid]}  not in (#{idsclis.compact.join(',')})")
    end


    #set flag on bad dst | code : 3
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 3 where replace(replace(col_#{options[:imp_dst]}, '\\r', ''), '
', '') REGEXP '^[0-9]+$' = 0  and f_error = 0")
    #set flag on bad calldate | code : 4
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 4 where replace(replace(col_#{options[:imp_calldate]}, '\\r', ''), '
', '') REGEXP '^[0-9 :-]+$' = 0 and f_error = 0 ")
    #set flag on bad billsec | code : 5
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 5 where replace(replace(col_#{options[:imp_billsec]}, '\\r', ''), '
', '') REGEXP '^[0-9]+$' = 0 and f_error = 0")
    if  options[:imp_provider_id].to_i > -1
    #set flag on bad Provider ID | code : 6
      prov_id =
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 6 where replace(replace(col_#{options[:imp_provider_id]}, '\\r', ''), '
', '') NOT IN (SELECT providers.id FROM providers WHERE hidden = 0 AND (user_id = #{current_user} OR (common_use = 1 and providers.id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{current_user})))) and f_error = 0")
    end

    #set flag on bad clis and count them
    unless options[:import_user]
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 1 where replace(replace(col_#{options[:imp_clid]}, '\\r', ''), '
', '') REGEXP '^[0-9]+$' = 0")
      if User.current.is_admin?
        ActiveRecord::Base.connection.execute("UPDATE #{name}
                                             JOIN callerids ON (callerids.cli = col_#{options[:imp_clid]})
                                             JOIN devices ON (callerids.device_id = devices.id)
                                             JOIN users ON (devices.user_id = users.id)
                                             JOIN users AS owners ON (users.owner_id = owners.id)
                                             SET f_error = 1, nice_error=7, #{name}.owner_id=owners.id
                                             WHERE owners.own_providers = 1")
      end
    end
    cond = options[:import_user] ? " AND user_id = #{options[:import_user]} " : '' #" calls.cli "
    ActiveRecord::Base.connection.execute("UPDATE #{name} JOIN calls ON (calls.calldate = timestamp(replace(col_#{options[:imp_calldate]}, '\\r', '')) ) SET f_error = 1, nice_error = 2 WHERE dst = replace(col_#{options[:imp_dst]}, '\\r', '') and billsec = replace(col_#{options[:imp_billsec]}, '\\r', '')  #{cond} and f_error = 0")

    arr[:cdr_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 0").to_i
    arr[:bad_cdrs] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 1").to_i
    arr[:bad_clis] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 1").to_i
    if options[:step] and options[:step] == 8
      arr[:new_clis_to_create] = ActiveRecord::Base.connection.select_value("SELECT COUNT(DISTINCT(col_#{options[:imp_clid]})) FROM #{name}  WHERE nice_error != 1 and not_found_in_db = 1").to_i if options[:imp_clid] and options[:imp_clid] >= 0
      arr[:clis_to_assigne] = Callerid.count(:all, :conditions => {:device_id => -1}).to_i
    else
      arr[:new_clis_to_create] = ActiveRecord::Base.connection.select_value("SELECT COUNT(DISTINCT(col_#{options[:imp_clid]})) FROM #{name} LEFT JOIN callerids on (callerids.cli = replace(col_#{options[:imp_clid]}, '\\r', '')) WHERE nice_error != 1 and callerids.id is null and not_found_in_db = 1").to_i if options[:imp_clid] and options[:imp_clid] >= 0
      arr[:clis_to_assigne] = Callerid.count(:all, :conditions => {:device_id => -1}).to_i + arr[:new_clis_to_create].to_i
    end

    arr[:existing_clis_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where not_found_in_db = 0 and f_error = 0").to_i
    arr[:new_clis_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(DISTINCT(col_#{options[:imp_clid]})) FROM #{name} where not_found_in_db = 1").to_i if options[:imp_clid] and options[:imp_clid] >= 0
    arr[:cdrs_to_insert] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 0").to_i
    return arr
  end

  def Call.insert_cdrs_from_csv(name, options)
    provider = Provider.includes(:tariff).where("providers.id = #{options[:import_provider]}").first if options[:imp_provider_id].to_i < 0

    if options[:import_user]
      res = ActiveRecord::Base.connection.select_all("SELECT *, devices.id as dev_id FROM #{name} JOIN devices ON (devices.id = #{options[:import_device]}) WHERE f_error = 0 and do_not_import = 0")
    else
      res = ActiveRecord::Base.connection.select_all("SELECT *, devices.id as dev_id FROM #{name} JOIN callerids ON (callerids.cli = replace(col_#{options[:imp_clid]}, '\\r', '')) JOIN devices ON (callerids.device_id = devices.id) WHERE f_error = 0 and do_not_import = 0")
    end

    imported_cdrs = 0
    for r in res
      billsec = r["col_#{options[:imp_billsec]}"].to_i
      call = Call.new(:billsec => billsec, :dst => CsvImportDb.clean_value(r["col_#{options[:imp_dst]}"].to_s).gsub(/[^0-9]/, ""), :calldate => r["col_#{options[:imp_calldate]}"], :card_id => 0)

      # A: Hack for the mess that gets created with speedup.sql
      call.lastapp    =	""	if call.attributes.has_key? 'lastapp'
      call.lastdata   =	""	if call.attributes.has_key? 'lastdata'
      call.uniqueid   =	""	if call.attributes.has_key? 'uniqueid'
      call.channel    =	""	if call.attributes.has_key? 'channel'
      call.dcontext   =	""	if call.attributes.has_key? 'dcontext'
      call.dstchannel =	""	if call.attributes.has_key? 'dstchannel'
      call.userfield  =	""	if call.attributes.has_key? 'userfield'

      duration = CsvImportDb.clean_value(r["col_#{options[:imp_duration]}"]).to_i
      duration = billsec if duration == 0 or options[:imp_duration] == -1
      disposition = ""
      disposition = CsvImportDb.clean_value r["col_#{options[:imp_disposition]}"] if options[:imp_disposition] > -1
      if disposition.length == 0
        disposition = 'ANSWERED' if billsec > 0
        disposition = 'NO ANSWER' if billsec == 0
      end

      call.clid = CsvImportDb.clean_value r["col_#{options[:imp_clid]}"] if options[:imp_clid] > -1
      call.clid = "" if call.clid.to_s.length == 0

      call.src = CsvImportDb.clean_value(r["col_#{options[:imp_src_number]}"]).gsub(/[^0-9]/, "") if options[:imp_src_number] > -1
      call.src = call.clid.to_i.to_s if call.src.to_s.length == 0
      call.src = "" if call.src.to_s.length == 0

      call.duration = duration

      call.disposition = disposition
      call.accountcode = r['dev_id']
      call.src_device_id = r['dev_id']
      call.user_id = r['user_id']

      #If Provider ID Should Be Imported FROM CSV
      if options[:imp_provider_id].to_i > -1
        call.provider_id =  CsvImportDb.clean_value(r["col_#{options[:imp_provider_id]}"]).gsub(/[^0-9]/, "")
      else
        call.provider_id = provider.id
      end

      call.localized_dst = call.dst

      user = User.find(call.user_id)

      call.reseller_id = user.owner_id
      call = call.count_cdr2call_details(call.provider.tariff_id , user, 0, true) if call.valid?

      if call.save
        user.balance -= call.user_price
        user.save
        imported_cdrs += 1
      end
    end

    errors = ActiveRecord::Base.connection.select_all("SELECT * FROM #{name} where f_error = 1")
    return imported_cdrs, errors
  end


  # counts details for the call imported from csv
  #
  # Upgrade: selfcost_tariff_id and user_id can be Tariff or User objects so
  # not to perform find and not to stress database.
  #

  def count_cdr2call_details(selfcost_tariff_id, user_id, user_test_tariff_id = 0, importing = false, include_reseller_users = false, rerating_type = 'admin_user')
    @prov_exchange_rate_cache ||= {}
    @tariffs_cache ||= {}

    if user_id.class == User
      user = user_id
      user_id = user.id
    else
      user = User.includes(:tariff).where("users.id = #{user_id}").first
    end

    # testing tariff
    if user_test_tariff_id > 0
      tariff = Tariff.where(:id => user_test_tariff_id).first
      CsvImportDb.clean_value "Using testing tariff with id: #{user_test_tariff_id}"
    else
      tariff = user.tariff
    end
    dst = CsvImportDb.clean_value self.dst.to_s #.gsub(/[^0-9]/, "")
    device_id = self.accountcode
    time = self.calldate.strftime("%H:%M:%S")
    calldatetime = self.calldate.strftime('%Y-%m-%d %H:%M:%S')

    if selfcost_tariff_id.class == Tariff
      prov_tariff = selfcost_tariff_id
      selfcost_tariff_id = prov_tariff.id
      @tariffs_cache["t_#{selfcost_tariff_id}".to_sym] ||= prov_tariff
    else
      prov_tariff = @tariffs_cache["t_#{selfcost_tariff_id}".to_sym] ||= Tariff.find(selfcost_tariff_id)
    end

    prov_exchange_rate = @prov_exchange_rate_cache["p_#{prov_tariff.id}".to_sym] ||= prov_tariff.exchange_rate

    #my_debug ""

    # get daytype and localization settings
    day = self.calldate.to_s(:db)
    sql = "SELECT  A.*, (SELECT IF((SELECT daytype FROM days WHERE date = '#{day}') IS NULL, (SELECT IF(WEEKDAY('#{day}') = 5 OR WEEKDAY('#{day}') = 6, 'FD', 'WD')), (SELECT daytype FROM days WHERE date = '#{day}')))   as 'dt' FROM devices JOIN locations ON (locations.id = devices.location_id) LEFT JOIN (SELECT * FROM locationrules WHERE  enabled = 1 AND lr_type = 'dst' AND LENGTH('#{dst}') BETWEEN minlen AND maxlen AND (SUBSTRING('#{dst}',1,LENGTH(cut)) = cut OR LENGTH(cut) = 0 OR ISNULL(cut)) ORDER BY location_id DESC ) AS A ON (A.location_id = locations.id OR A.location_id = 1) WHERE devices.id = #{device_id} ORDER BY LENGTH(cut) DESC LIMIT 1;"
    res = ActiveRecord::Base.connection.select_one(sql)
    if res and res['device_id'].blank? and res['did_id'].blank?
      daytype = res['dt']
      loc_add = res['add']
      loc_cut = res['cut']
      loc_tariff_id = res['tariff_id']

                                #V ticket #8547
      if loc_tariff_id.to_i > 0 #and user_test_tariff_id.to_i == 0
        # change tariff because of localization
        tariff = @tariffs_cache["t_#{loc_tariff_id}".to_sym] ||= Tariff.where(:id => loc_tariff_id).first
      end

      #my_debug sql
      #my_debug "calldate: #{day}, time: #{time}, daytype: #{daytype}, loc_add: #{loc_add}, loc_cut: #{loc_cut}, loc_add: #{loc_add}, src: #{call.src}, dst: #{dst}, tariff_id: #{tariff_id}, self_tariff_id: #{selfcost_tariff_id}"
      #localization
      #      start = 0
      #      start = loc_cut.length if loc_cut
      orig_dst = dst
      #      dst = loc_add.to_s + dst[start, dst.length]
      dst = Location.nice_locilization(loc_cut, loc_add, orig_dst)

      MorLog.my_debug "Before Localication: #{orig_dst}, after localization-> dst: #{dst}, cut: #{loc_cut.to_s}, add: #{loc_add.to_s} "

      # initial values

      price = 0
      max_rate = 0
      user_exchange_rate = 1
      temp_prefix = ""
      user_billsec = 0

      s_prefix = ""
      s_rate = 0
      s_increment = 1
      s_min_time = 0
      s_conn_fee = 0

      s_billsec = 0
      s_price = 0


      # checking maybe called to own DID?

      did = nil
      did = Did.where("did = '#{dst}' AND dids.user_id = #{user_id}").first

      own_did = 0
      own_did = 1 if did

      if own_did == 1
        MorLog.my_debug 'Call to own DID - call will not be charged'
        user_billsec = self.billsec
        self.dst_device_id = did.device_id
        if user_billsec > 0
          self.hangupcause = 16
        else
          self.hangupcause = 0
        end
        self.did_id = did.id
        self.real_duration = user_billsec
        self.real_billsec = user_billsec
        self.reseller_id = user.owner_id
      end

      if own_did == 0
        #data for selfcost
        dst_array = []
        dst.length.times { |i| dst_array << dst[0, i+1] }
        if dst_array.size > 0
          sql =
              "SELECT A.prefix, ratedetails.rate,   ratedetails.increment_s, ratedetails.min_time, ratedetails.connection_fee "+
                  "FROM  rates JOIN ratedetails ON (ratedetails.rate_id = rates.id  AND (ratedetails.daytype = '#{daytype}' OR ratedetails.daytype = '' ) AND '#{time}' BETWEEN ratedetails.start_time AND ratedetails.end_time) JOIN (SELECT destinations.* FROM  destinations " +
                  "WHERE destinations.prefix IN ('#{dst_array.join("', '")}') ORDER BY LENGTH(destinations.prefix) DESC) " +
                  "as A ON (A.id = rates.destination_id) WHERE rates.tariff_id = #{selfcost_tariff_id} AND (rates.effective_from <= '#{calldatetime}' OR rates.effective_from IS NULL) ORDER BY LENGTH(A.prefix) DESC, rates.effective_from DESC LIMIT 1;"
        end

        #my_debug sql
        res = ActiveRecord::Base.connection.select_one(sql)

        if res
          s_prefix = res['prefix']
          s_rate = res['rate'].to_d
          s_increment = res['increment_s'].to_i
          s_min_time = res['min_time'].to_i
          s_conn_fee = res['connection_fee'].to_d
        end

        s_increment = 1 if s_increment == 0
        if (self.billsec % s_increment == 0)
          s_billsec = (self.billsec / s_increment).floor * s_increment
        else
          s_billsec = ((self.billsec / s_increment).floor + 1) * s_increment
        end
        s_billsec = s_min_time if s_billsec < s_min_time
        s_price = (s_rate * s_billsec) / 60 + s_conn_fee

        #   MorLog.my_debug "PROVIDER's: prefix: #{s_prefix}, rate: #{s_rate}, increment: #{s_increment}, min_time: #{s_min_time}, conn_fee: #{s_conn_fee}, billsec: #{s_billsec}, price: #{s_price}, exchange_rate = #{prov_exchange_rate}"
        #====================== data for USER ==============
        price, max_rate, user_exchange_rate, temp_prefix, user_billsec = self.count_call_rating_details_for_user(tariff, time, daytype, dst, user, calldatetime)
        MorLog.my_debug "USER: call_id: #{self.id}, user_price: #{price}, max_rate: #{max_rate}, exchange_rate: #{user_exchange_rate}, tmp_prefix: #{temp_prefix}, user_billsec: #{user_billsec}"

        #====================== data for RESELLER ==============

        if self.reseller_id.to_i > 0

          reseller = User.where(id: self.reseller_id.to_i).first
          tariff = @tariffs_cache["t_#{reseller.tariff_id.to_i}".to_sym] ||= Tariff.where(id: reseller.tariff_id.to_i).first if reseller

          common_use_provider =  Application.common_use_provider(self.provider_id)

          # In Case Common Use Provider present his Tariff should be used instead of reseller tariff
          tariff = Tariff.where(id: common_use_provider.tariff_id.to_i).first if common_use_provider.present?

          if reseller and tariff
            res_price, res_max_rate, res_exchange_rate, res_temp_prefix, res_billsec = self.count_call_rating_details_for_user(tariff, time, daytype, dst, reseller, calldatetime)
            MorLog.my_debug "RESELLER: call_id: #{self.id}, user_price: #{res_price}, max_rate: #{res_max_rate}, exchange_rate: #{res_exchange_rate}, tmp_prefix: #{res_temp_prefix}, user_billsec: #{res_billsec}"
          end
        end


      end # own_did == 0

      # ========= Calculation ===========

      if !include_reseller_users && user.is_reseller?
        if self.reseller_id.to_i > 0
          self.reseller_rate = res_max_rate / res_exchange_rate
          self.reseller_billsec = res_billsec
          self.reseller_price = 0
        end

        if self.disposition.to_s.upcase == 'ANSWERED'
          self.provider_price = s_price / prov_exchange_rate if importing
          self.user_price = price / user_exchange_rate

          if self.reseller_id.to_i > 0
            self.reseller_price = res_price / res_exchange_rate
          end
        end

        return self
      else
        #new
        if rerating_type != 'admin_reseller'
          self.user_rate = max_rate / user_exchange_rate
          self.user_billsec = user_billsec
          self.user_price = 0
        end
        if importing
          self.provider_rate = s_rate / prov_exchange_rate
          self.provider_billsec = s_billsec
          self.provider_price = 0
        end

        #call.dst = orig_dst
        self.localized_dst = dst

        if self.reseller_id.to_i > 0 && rerating_type != 'reseller_user'
          self.reseller_rate = res_max_rate / res_exchange_rate
          self.reseller_billsec = res_billsec
          self.reseller_price = 0
        end

        #call.prefix = res[0]["prefix"] if res[0]

        if temp_prefix.to_s.length > s_prefix.to_s.length
          self.prefix = temp_prefix
        else
          self.prefix = s_prefix
        end

        if !res_temp_prefix.blank? and self.prefix
          if self.reseller_id.to_i > 0 and res_temp_prefix.to_s.length > self.prefix.to_s.length
            self.prefix = res_temp_prefix
          end
        end


        #need to find prefix for error fixing when no prefix is in calls table - this should not happen anyways, so maybe no fix is neccesary?

        if self.disposition.to_s.upcase == 'ANSWERED'
          #        call.prov_price = s_price
          #        call.price = price

          #new
          self.provider_price = s_price / prov_exchange_rate if importing

          self.user_price = price / user_exchange_rate if rerating_type != 'admin_reseller'

          if self.reseller_id.to_i > 0 && rerating_type != 'reseller_user'
            self.reseller_price = res_price / res_exchange_rate
          end

        end

        # tmp hack to handle dids for reseller
        # disabled because
=begin
      if call.did_id.to_i > 0

        call.provider_rate = 0
        call.provider_price = 0

        call.user_price = 0
        call.user_rate = 0

        call.reseller_rate = 0
        call.reseller_price = 0

      end
=end
    end
    else
      MorLog.my_debug "#{Time.now.to_s(:db)}  SQL not found--------------------------------------------"
      MorLog.my_debug sql
    end
    self
  end


  def count_call_rating_details_for_user(tariff, time, daytype, dst, user, calldatetime = nil)
    @count_call_rating_details_for_user_exchange_rate_cache ||= {}
    if tariff.purpose == "user"

      #  sql =   "SELECT A.prefix, aratedetails.* FROM  rates JOIN aratedetails ON (aratedetails.rate_id = rates.id ) JOIN destinationgroups " +
      #"ON (destinationgroups.id = rates.destinationgroup_id) JOIN (SELECT destinations.* FROM  destinations " +
      #"WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix)) ORDER BY LENGTH(destinations.prefix) DESC LIMIT 1) as A " +
      #"ON (A.destinationgroup_id = destinationgroups.id) WHERE rates.tariff_id = #{tariff_id} ORDER BY aratedetails.id ASC"

      dst_array = []
      dst.length.times { |i| dst_array << dst[0, i+1] }
      sql = "SELECT B.prefix as 'prefix', aid, afrom, adur, atype, around, aprice, acid, acfrom, acdur, actype, acround, acprice " +
          "FROM (SELECT A.prefix, aratedetails.id as 'aid', aratedetails.from as 'afrom', aratedetails.duration as 'adur', aratedetails.artype as 'atype', aratedetails.round as 'around', aratedetails.price as 'aprice', acustratedetails.id as 'acid', acustratedetails.from as 'acfrom', acustratedetails.duration as 'acdur', acustratedetails.artype as 'actype', acustratedetails.round as 'acround', acustratedetails.price as 'acprice', SUM(acustratedetails.id) as 'sacid'  " +
          "FROM  rates JOIN aratedetails ON (aratedetails.rate_id = rates.id  AND '#{time}' BETWEEN aratedetails.start_time AND aratedetails.end_time AND (aratedetails.daytype = '#{daytype}' OR aratedetails.daytype = ''))  " +
          "JOIN destinationgroups ON (destinationgroups.id = rates.destinationgroup_id)     " +
          "JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix IN ('#{dst_array.join("', '")}')  AND destinationgroup_id IN (SELECT rates.destinationgroup_id from rates where rates.tariff_id = #{tariff.id})" +
          "ORDER BY LENGTH(destinations.prefix) DESC LIMIT 1) as A ON (A.destinationgroup_id = destinationgroups.id)  " +
          "LEFT JOIN customrates ON (customrates.destinationgroup_id = destinationgroups.id AND customrates.user_id = #{user.id})  " +
          "LEFT JOIN acustratedetails ON (acustratedetails.customrate_id = customrates.id  AND '#{time}' BETWEEN acustratedetails.start_time AND acustratedetails.end_time AND (acustratedetails.daytype = '#{daytype}' OR acustratedetails.daytype = ''))  " +
          "WHERE rates.tariff_id = #{tariff.id} GROUP BY aratedetails.id, acustratedetails.id ) AS B GROUP BY IF(B.sacid > 0,B.acid,B.aid)  " +
          "ORDER BY acfrom ASC, actype ASC, afrom ASC, atype ASC "

      #      sql = "SELECT B.prefix as 'prefix', aid, afrom, adur, atype, around, aprice, acid, acfrom, acdur, actype, acround, acprice FROM (
      #                SELECT * FROM (
      #                   SELECT A.prefix, aratedetails.id as 'aid', aratedetails.from as 'afrom', aratedetails.duration as 'adur', aratedetails.artype as 'atype', aratedetails.round as 'around', aratedetails.price as 'aprice', acustratedetails.id as 'acid', acustratedetails.from as 'acfrom', acustratedetails.duration as 'acdur', acustratedetails.artype as 'actype', acustratedetails.round as 'acround', acustratedetails.price as 'acprice', SUM(acustratedetails.id) as 'sacid' FROM rates
      #                          JOIN aratedetails ON (aratedetails.rate_id = rates.id  AND '#{time}' BETWEEN aratedetails.start_time AND aratedetails.end_time AND (aratedetails.daytype = '#{daytype}' OR aratedetails.daytype = ''))  " +
      #"JOIN destinationgroups ON (destinationgroups.id = rates.destinationgroup_id)     " +
      #"JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix IN ('#{dst_array.join("', '")}')) as A ON (A.destinationgroup_id = destinationgroups.id)  " +
      #"LEFT JOIN customrates ON (customrates.destinationgroup_id = destinationgroups.id AND customrates.user_id = #{user.id})  " +
      #                         "LEFT JOIN acustratedetails ON (acustratedetails.customrate_id = customrates.id  AND '#{time}' BETWEEN acustratedetails.start_time AND acustratedetails.end_time AND (acustratedetails.daytype = '#{daytype}' OR acustratedetails.daytype = ''))  " +
      #                         "WHERE rates.tariff_id = #{tariff.id} AND aid is not null ORDER BY LENGTH(prefix) DESC LIMIT 1
      #               ) AS C GROUP BY aid, acid
      #             ) AS B GROUP BY IF(B.sacid > 0,B.acid,B.aid)
      #             ORDER BY acfrom ASC, actype ASC, afrom ASC, atype ASC;#"

      #my_debug sql

      res = ActiveRecord::Base.connection.select_all(sql)

      custom_rates = 0
      billsec = 0
      price = 0
      max_rate = 0.0
      for r in res

        if res[0]['acid'] and res[0]['acid'].to_i > 0
          #my_debug "custom rates"

          custom_rates = 1


          r_from = r['acfrom']
          r_duration = r['acdur']
          r_artype = r['actype']
          r_round = r['acround']
          r_price = r['acprice']
          cr = true
        else
          #my_debug "no custom rates"


          r_from = r['afrom']
          r_duration = r['adur']
          r_artype = r['atype']
          r_round = r['around']
          r_price = r['aprice']
          cr = false
        end


        #         MorLog.my_debug "from: #{r_from}, duration: #{r_duration}, artype: #{r_artype}, round: #{r_round}, price: #{r_price}"

        if r_from.to_i <= self.billsec
          #this arate is suitable for this call
          if r_artype == "minute"
            #my_debug "1. minute, price: #{price}"
            max_rate = r_price.to_d if max_rate < r_price.to_d

            #count the time frame for us to bill
            if r_duration.to_i == (-1)
              #unlimited frame end
              #my_debug call.billsec.to_i
              billsec = self.billsec.to_i - r_from.to_i + 1
            else
              if self.billsec < (r_from.to_i + r_duration.to_i)
                billsec = self.billsec - r_from.to_i + 1
              else
                billsec = r_duration.to_i
              end
            end

            #my_debug "2. minute, price: #{price}, billsec: #{billsec}"

            #round time frame
            #              if (billsec % r_round.to_i) == 0
            #if round is 0, mistake in db?- must be changed to 1
            if r_round.to_i == 0
              r_round = 1
            end
            billsec = (billsec.to_d / r_round.to_d).ceil * r_round.to_i
            #my_debug "==0"
            #my_debug((billsec.to_d / r_round.to_d)).to_s
            #              else
            #my_debug "!=0"
            #                billsec = ((billsec.to_d / r_round.to_d) + 1).ceil * r_round.to_i
            #              end

            #my_debug "3. minute, price: #{price}, billsec: #{billsec}"
            #my_debug((r_price.to_d * billsec.to_d) / 60  ).to_s
            #count the price for the time frame
            price += (r_price.to_d * billsec.to_d) / 60

            #my_debug "4. minute, price: #{price}"
          else #event

            price += r_price.to_d
            billsec = 0
            #my_debug "5. event, price: #{price}"
          end #minute-event
        end #suitable arate
      end


      user_billsec = 0
      total_arates = res.size
      lfrom = res[total_arates - 1]["afrom"].to_i if cr == false
      lfrom = res[total_arates - 1]["acfrom"].to_i if cr == true
      if res.size > 0
        if (billsec + lfrom) > self.billsec
          user_billsec = billsec
        else
          user_billsec = self.billsec
        end

      end

      if custom_rates == 1
        user_exchange_rate = 1
      else
        user_exchange_rate = @count_call_rating_details_for_user_exchange_rate_cache["te_#{tariff.id}".to_sym] ||= tariff.exchange_rate
      end

      temp_prefix = ""
      temp_prefix = res[0]["prefix"] if res[0]

    else #tariff.purpose == "user_wholesale"

         #======================= user wholesale ===============

      sql = "SELECT A.prefix,
                     ratedetails.rate,
                     ratedetails.increment_s,
                     ratedetails.min_time,
                     ratedetails.connection_fee as 'cf'
              FROM rates
              JOIN ratedetails ON (ratedetails.rate_id = rates.id
                                   AND (ratedetails.daytype =  '#{daytype}' OR ratedetails.daytype = '' )
                                   AND '#{time}' BETWEEN ratedetails.start_time AND ratedetails.end_time
                                  )
              JOIN (SELECT destinations.*
                    FROM  destinations
                    WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix))
                   ) AS A ON (A.id = rates.destination_id)
              WHERE rates.tariff_id = #{tariff.id}
                    AND (rates.effective_from <= '#{calldatetime}' OR rates.effective_from IS NULL)
              ORDER BY LENGTH(A.prefix) DESC, rates.effective_from DESC
              LIMIT 1;"


      #my_debug sql

      res = ActiveRecord::Base.connection.select_one(sql)

      uw_prefix = ""
      uw_rate = 0
      uw_increment = 1
      uw_min_time = 0
      uw_conn_fee = 0

      if res
        uw_prefix = res['prefix']
        uw_rate = res['rate'].to_d
        uw_increment = res['increment_s'].to_i
        uw_min_time = res['min_time'].to_i
        uw_conn_fee = res['cf'].to_d
      end

      uw_billsec = 0
      uw_price = 0

      uw_increment = 1 if uw_increment == 0

      if (self.billsec % uw_increment == 0)
        uw_billsec = (self.billsec / uw_increment).floor * uw_increment
      else
        uw_billsec = ((self.billsec / uw_increment).floor + 1) * uw_increment
      end
      uw_billsec = uw_min_time if uw_billsec < uw_min_time

      #my_debug (call.billsec.to_d / uw_increment)
      #my_debug (call.billsec.to_d / uw_increment).floor
      #my_debug (call.billsec / uw_increment).floor * uw_increment
      #my_debug uw_billsec

      uw_price = (uw_rate * uw_billsec) / 60 + uw_conn_fee

      price = uw_price
      max_rate = uw_rate
      user_exchange_rate = @count_call_rating_details_for_user_exchange_rate_cache["te_#{tariff.id}".to_sym] ||= tariff.exchange_rate
      temp_prefix = uw_prefix
      user_billsec = uw_billsec
    end
    return price, max_rate, user_exchange_rate, temp_prefix, user_billsec
  end


  def Call.summary_by_dids(user, order, options)
    group_by = []
    options[:dids_grouping] == 1 ? group_by << "calls.did_provider_id" : group_by << "dids.user_id, dids.device_id"


    cond = ["calldate BETWEEN ? AND ?"]
    var = [options[:from], options[:till]]


    jn = ["JOIN dids ON (dids.id = calls.did_id)", "LEFT JOIN devices ON (dids.device_id = devices.id)", "LEFT JOIN users ON (users.id = dids.user_id)",  "LEFT JOIN providers ON (calls.did_provider_id = providers.id)"]

    if  options[:did].to_s != ""  and options[:d_search].to_i == 1
      cond << "dids.did LIKE ?"
      var << options[:did].to_s.strip + "%" #options[:did].gsub(/[^0-9]/, "").to_s + "%"
    end

    if  options[:did_search_from].to_s != "" and options[:did_search_till].to_s != "" and options[:d_search].to_i == 2
      cond << "dids.did BETWEEN ? AND ?"
      var << options[:did_search_from].to_s.strip #options[:did_search_from].gsub(/[^0-9]/, "").to_s
      var << options[:did_search_till].to_s.strip #options[:did_search_till].gsub(/[^0-9]/, "").to_s
    end

    if  options[:provider].to_s != "any"
      cond << "calls.did_provider_id = ?"
      var << options[:provider].to_i
    end

    if  options[:user_id].to_s != "any"
      cond << "dids.user_id = ?"
      var << options[:user_id].to_i
    end

    if !options[:device_id].blank? and options[:device_id].to_s != "all"
      cond << "dids.device_id = ?"
      var << options[:device_id].to_i
    end

    if options[:sdays].to_s != 'all'
      cond << 'DAYOFWEEK(calls.calldate) IN (1,7)'  if  options[:sdays].to_s == 'fd'
      cond << 'DAYOFWEEK(calls.calldate) IN (2,3,4,5,6)'  if  options[:sdays].to_s == 'wd'
    end

    if options[:period].to_i != -1
      didrate = Didrate.where({:id=>options[:period]}).first
      if didrate
      cond << 'TIME(calls.calldate) BETWEEN ? AND ?'
      var << didrate.start_time.strftime("%H:%M:%S")
      var << didrate.end_time.strftime("%H:%M:%S")
        end
    end

    s = []

    s << "#{SqlExport.nice_user_sql}, providers.user_id as prov_owner_id, calls.did_id, dids.did, providers.name, dids.comment, calls.did_provider_id, dids.user_id, dids.device_id, users.owner_id as user_owner_id "
    s << SqlExport.column_escape_null("COUNT(*)", 'total_calls', 0)

    s << SqlExport.column_escape_null("SUM(calls.did_billsec)", 'dids_billsec', 0)
    s << SqlExport.column_escape_null("SUM(calls.did_inc_price)", "inc_price", 0)
    s << SqlExport.column_escape_null("SUM(calls.did_prov_price)", "d_prov_price", 0)
    s << SqlExport.column_escape_null("SUM(calls.did_price)", 'own_price', 0)

    order = !order.to_s.blank? ? 'ORDER BY ' + order : ''
    group = group_by.size > 0 ? 'GROUP BY ' +group_by.join(", ") : ''




      sql = "SELECT #{s.join(', ')} FROM calls #{jn.join(' ')}  WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])}  #{group}  #{order} "
      mysql_res = Call.find_by_sql(sql)
      return mysql_res

  end

  def toggle_processed
    self.processed = processed == 0 ? 1 : 0
    save
  end

  def self.find_totals_for_profit(conditions)
    select_total = ["COUNT(*) AS 'total_calls'"]
    select_total << "SUM(IF(calls.disposition = 'ANSWERED', 1, 0)) AS 'answered_calls'"
    select_total << "SUM(IF(calls.disposition = 'BUSY', 1, 0)) AS 'busy_calls'"
    select_total << "SUM(IF(calls.disposition = 'NO ANSWER', 1, 0)) AS 'no_answer_calls'"
    select_total << "SUM(IF(calls.disposition = 'FAILED', 1, 0)) AS 'failed_calls'"

    total = Call.select(select_total.join(", ")).where(conditions.join(" AND ")).joins(SqlExport.left_join_reseler_providers_to_calls_sql)

    return total
  end

  def self.find_totals_for_profit_prices(select, conditions)
    total = Call.select(select.join(', ')).where((conditions + ["disposition = 'ANSWERED'"]).join(" AND ")).
            joins("LEFT JOIN users ON (users.id = calls.user_id) #{SqlExport.left_join_reseler_providers_to_calls_sql}").first

    return total
  end

  private

  def Call.last_calls_parse_params(options={})
    jn = ['LEFT JOIN users ON (calls.user_id = users.id)',
          'LEFT JOIN users AS resellers ON (calls.reseller_id = resellers.id)',
          'LEFT JOIN dids ON (calls.did_id = dids.id)',
          'LEFT JOIN cards ON (calls.card_id = cards.id)',
          SqlExport.left_join_reseler_providers_to_calls_sql
    ]
    cond = ["(calls.calldate BETWEEN ? AND ?)"]
    var = [options[:from], options[:till]]

    if options[:current_user].usertype == "reseller" and !options[:user]
      jn << "LEFT JOIN users AS dst_users ON (dst_users.id = calls.dst_user_id)"
      cond << "(calls.reseller_id = ? OR calls.user_id = ? OR users.owner_id = ? OR dst_users.owner_id = ?)"
      var += ([options[:current_user].id] * 4)
    end

    if options[:call_type] != "all"
      if ['answered', 'failed'].include?(options[:call_type].to_s)
        cond << Call.nice_answered_cond_sql if options[:call_type].to_s == 'answered'
        cond << Call.nice_failed_cond_sql if options[:call_type].to_s == 'failed'
      else
        cond << "calls.disposition = ?"
        var << options[:call_type]
      end
    end

    if options[:hgc]
      cond << "calls.hangupcause = ?"
      var << options[:hgc].code
    end

    unless options[:destination].blank?
      cond << "localized_dst like ?"
      var << "#{options[:destination]}"
    end

    if options[:s_reseller_did] != 'all' and !options[:s_reseller_did].blank?
      cond << "dids.reseller_id = ?"
      var << options[:s_reseller_did]
    end

    if options[:s_country] and !options[:s_country].blank?
      cond << "destinations.direction_code = ? "; var << options[:s_country]
      jn << 'LEFT JOIN destinations ON (calls.prefix = destinations.prefix)'
    end

    if options[:device].present? && options[:device].id
      device_id = options[:device].id
      cond << "(calls.dst_device_id = ? OR calls.src_device_id = ?)"
      var += [device_id, device_id]
    end

    if options[:user]
      current_user = options[:current_user]
      user_id = options[:user].id
      if current_user.is_reseller?
        cond << "(calls.user_id = ? OR calls.dst_user_id = ?)"
        var += [user_id, user_id]
      elsif current_user.is_user?
        cond << "(calls.user_id = ? OR calls.dst_user_id = ? OR cards.user_id = ?)"
        var += ([user_id] * 3)
      else
        jn << "LEFT JOIN devices AS dst_device ON (dst_device.id = calls.dst_device_id)"
        cond << "(calls.user_id = ? OR dst_device.user_id = ? OR calls.dst_user_id = ? OR cards.user_id = ?)"
        var += ([user_id] * 4)
      end
    end

    if options[:did]
      cond << "calls.did_id = ?"
      var << options[:did].id
    elsif !options[:s_did_pattern].to_s.strip.blank?
      cond << "dids.did LIKE ?"
      var << options[:s_did_pattern].to_s.strip
    end

    #find_calls_only_with_did
    if options[:only_did] and options[:only_did].to_i == 1
      cond<<"calls.did_id > ?"
      var << '0'
    end

    if options[:provider] or options[:did_provider]
      c = ""
      c << "calls.provider_id = ?" if options[:provider]
      c << " and " if options[:provider] and options[:did_provider]
      c << "calls.did_provider_id = ?" if options[:did_provider]
      cond << c
      var += [options[:provider].id] if options[:provider]
      var += [options[:did_provider].id] if options[:did_provider]
    end

    if options[:reseller]
      cond << "calls.reseller_id = ?"
      var << options[:reseller].id
    end

    if options[:source] and not options[:source].blank?
      cond << "(calls.src LIKE ? OR calls.clid LIKE ?)"
      2.times { var << options[:source] }
    end
    # this is nasty but oh well.

    unless options[:s_card_number].to_s.strip.blank?
      cond << "cards.number LIKE ?"
      var << options[:s_card_number]
    end

    unless options[:s_card_pin].to_s.strip.blank?
      cond << "cards.pin LIKE ?"
      var << options[:s_card_pin]
    end

    unless options[:s_card_id].to_s.strip.blank?
      cond << "calls.card_id LIKE ?"
      var << options[:s_card_id]
    end

    return cond, var, jn
  end
end
