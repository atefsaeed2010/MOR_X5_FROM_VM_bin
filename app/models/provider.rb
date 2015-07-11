# -*- encoding : utf-8 -*-
class Provider < ActiveRecord::Base

  include SqlExport

  belongs_to :tariff
  belongs_to :device
  belongs_to :terminator
  has_many :providerrules
  has_many :calls
  has_many :dids
  belongs_to :device
  belongs_to :user
  has_many :lcrproviders
  has_many :common_use_providers
  has_many :serverproviders, :dependent => :destroy

  attr_protected :user_id
  attr_accessor :old_register_record
  attr_accessor :old_register_extension_record
  attr_accessor :old_register_line_record
  attr_accessor :max_timeout

  # old validates_format_of :server_ip, :with => /(^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$)|(^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)?$)|dynamic/ , :message =>  _("Hostname_is_not_valid")
  validates_format_of :server_ip, :with => /(\A(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}\z)|(\A(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])\z)|^dynamic\z|^\z/, :message => _("Hostname_is_not_valid")
  validates_presence_of :name, :message => _("Provider_should_have_name")
  validates_format_of :port, :with => /^\d+$|^$/, :message => _("Provider_port_is_not_valid"), :multiline => true
  validates_uniqueness_of :name, :message => _('Provider_Name_Must_Be_Unique')
  #skype provider must have skype name, no blank field allowed
  validates_presence_of :login, :message => _("Skype_provider_should_have_name"), :if => lambda { |o| o.tech == "Skype" }
  validates_numericality_of [:tariff_id,:timeout], :only_integer => true
  validates_numericality_of :call_limit, :only_integer => true, :message => _('call_limit_must_be_numeric')

  before_save :before_save_timeout, :check_location_id, :check_login
  before_destroy :provider_before_destroy

  def before_save_timeout
    self.timeout = 30 if self.timeout.to_i < 30
    true
  end

  def check_login
    if self.device and self.device.device_ip_authentication_record == 0 and login.blank?
      errors.add(:login, _('Provider_should_have_login'))
      return false
    end
  end

  def check_location_id
    if self.user and self.user.id != 0
      #if old location id - create and set
      value = Confline.get_value("Default_device_location_id", self.user.id)
      if value.blank? or value.to_i == 1 or !value
        self.user.after_create_localization
      else
        #if new - only update devices with location 1
        self.user.update_resellers_device_location(value)
      end
    end
  end

  def provider_before_destroy
    if Call.count(:conditions => ["provider_id = ?", self.id]) > 0
      errors.add(:calls, _('Provider_has_calls'))
      return false
    end

    if self.dids and self.dids.size > 0
      errors.add(:dids, _('Cant_delete_provider_it_has_dids'))
      return false
    end

    if Lcr.count(:conditions => ["failover_provider_id = ?", self.id]) > 0
      errors.add(:lcrproviders, _('Cannot_delete_provider_it_is_assigned_as_failover_provider'))
      return false
    end

    if Alert.where(:check_type => "provider", :check_data => self.id).first
      errors.add(:alerts, _('Provider_assigned_to_alerts'))
      return false
    end

    for rule in self.providerrules
      rule.destroy
    end

    self.device.destroy if self.device
  end

  def self.create_by_user(current_user, params)
    provider = self.new
    provider.name = params[:provider][:name].strip

    provider.tariff_id = params[:tariff_id]
    provider.call_limit = params[:provider][:call_limit].to_i

    provider.tech = ""
    provider.server_ip = ""
    provider.login = ""
    provider.password = ""
    provider.port = ""
    provider.priority = 100
    provider.user = current_user
    return provider
  end

  def self.create_by_params(params, id)
    provider = self.new(params[:provider])
    provider.user_id = id
    provider.server_ip = "0.0.0.0"
    provider.login = provider.name.strip
    provider.password = "please_change"
    provider.port = "4569" if provider.tech == "IAX2"
    provider.port = "5060" if provider.tech == "SIP"
    provider.port = "1720" if provider.tech == "H323"

    provider.add_a = ""
    provider.add_b = ""
    provider.cut_a = 0
    provider.cut_b = 0

    # Dirty not proper hack.
    provider.channel = "" if !provider.channel
    #    params[:server_add] = 1 if session[:usertype] == "reseller"
    #    @server = Server.find(:first, :conditions => ["id = ?", params[:server_add]])
    #    unless @server
    #      flash[:notice] = _('No_servers_available')
    #      redirect_to :action => :list and return false
    #    end
    return provider
  end

  def type
    return "dynamic" if self.server_ip == "dynamic"
    return "hostname" if self.device and self.device.ipaddr.to_s == ""
    return "ip"
  end

  def network(type, host, ip, port)
    case type
      when "hostname"
        self.server_ip = host
        device = self.device
        #device.name = "prov" + device.id.to_s
        device.host = host.to_s
        device.ipaddr = ""
        self.port = device.port = port
      when "ip"
        self.server_ip = host
        device = self.device
        #device.name = "prov" + device.id.to_s
        device.host = host.to_s
        device.ipaddr = ip.to_s
        self.port = device.port = port
      when "dynamic"
        self.server_ip = "dynamic"
        device = self.device
        self.login.to_s.length > 0 ? device.name = self.login : device.name = "prov_" + self.id.to_s
        device.host = "dynamic"
        device.ipaddr = ""
        self.port = device.port = 0
      else
        return false
    end
    return true
  end

  # is provider active in some LCR?
  # nil - provider does not belong to this LCR
  # 0 - disabled
  # 1 - active
  def active?(lcr_id)
    if lcrprov = Lcrprovider.where("provider_id = #{self.id} AND lcr_id = #{lcr_id.to_i}").first
      return lcrprov.active
    else
      return nil
    end
  end

  def serverprovider
    Serverprovider.where(["server_id = ?", self.id]).all
  end

  def servers
    servers = Server.find_by_sql("SELECT servers.* FROM servers, serverproviders WHERE serverproviders.provider_id = '#{self.id.to_s}' AND serverproviders.server_id = servers.id ORDER BY servers.id;")
  end

  def calls(date_start, date_end)
    calls = Call.find_by_sql("SELECT calls.* FROM calls WHERE (calls.provider_id = '#{self.id}' OR calls.did_provider_id = '#{self.id}' ) AND calls.calldate BETWEEN '#{date_start}' AND '#{date_end}';")
  end

  def codec?(codec)
    sql = "SELECT COUNT(*) as 'count' FROM providercodecs, codecs WHERE providercodecs.provider_id = '" + self.id.to_s + "' AND providercodecs.codec_id = codecs.id AND codecs.name = '" + codec.to_s + "'"
    res = ActiveRecord::Base.connection.select_one(sql)
    res['count'].to_i == 1
  end

  def codecs_order(type, options={})
    Codec.find_by_sql("SELECT codecs.*,  IF(providercodecs.priority is null, 100, providercodecs.priority)  as bb FROM codecs  LEFT Join providercodecs on (providercodecs.codec_id = codecs.id and providercodecs.provider_id = #{self.id.to_i})  where codec_type = '#{type}' ORDER BY bb asc, codecs.id")
  end

  def codecs
    sql = "SELECT * FROM codecs, providercodecs WHERE providercodecs.provider_id = '" + self.id.to_s + "' AND providercodecs.codec_id = codecs.id ORDER BY providercodecs.priority"
    res = ActiveRecord::Base.connection.select_all(sql)
    codecs = []
    for i in 0..res.size-1
      codecs << Codec.find(res[i]["codec_id"])
    end
    codecs
  end

  def update_codecs_with_priority(codecs)
    dc = {}
    Providercodec.where(["provider_id = ?", self.id]).all.each { |c| dc[c.codec_id] = c.priority; c.destroy }
    Codec.all.each { |codec| Providercodec.new(:codec_id => codec.id, :provider_id => self.id, :priority => dc[codec.id].to_i).save if codecs[codec.name] == "1" }
    self.update_device_codecs
  end

  def update_device_codecs
    Devicecodec.where(["device_id = ?", self.device.id]).all.each { |codec| codec.destroy }
    self.codecs.each_with_index { |codec, index| Devicecodec.new(:device_id => self.device.id, :codec_id => codec.id, :priority => index.to_i).save }
    self.device.update_codecs if self.device
  end

  # uses 'sip reload keeprt' command (added by Kolmisoft) to reload sip configuration, apply all changes to provider registration
  # but keeping realtime peers intact, e.g. sip show peers will show all previously registered peers
  def sip_reload_keeprt
    exceptions = []
    servers = Server.where(:id => self.id, :server_type => 'asterisk').all
    servers.each do |server|
      begin
        server.ami_cmd("sip reload keeprt")
      rescue => e
        exceptions << e
      end
    end
    exceptions
  end

  def hide
    if self.hidden == 1
      self.hidden = 0
    else
      self.hidden = 1
    end
    return self.hidden
  end

  def reload
    exceptions = []
    servers = Server.where(:id => self.id, :server_type => 'asterisk').all
    servers.each do |server|
      begin
        server.ami_cmd('sip reload')
        server.ami_cmd('iax2 reload')
      rescue => e
        exceptions << e
      end
    end
    exceptions
  end

  def h323_reload
    exceptions = []
    servers = Server.where(:id => self.id, :server_type => 'asterisk').all
    servers.each do |server|
      begin
        server.ami_cmd('h323 reload')
      rescue => e
        exceptions << e
      end
    end
    exceptions
  end

  def provider_calls_csv(options = {})
    sep = Confline.get_value("CSV_Separator", 0).to_s
    dec = Confline.get_value("CSV_Decimal", 0).to_s

    if options[:direction] == "incoming"
      disposition = " (calls.did_provider_id = #{self.id} OR calls.src_device_id = #{self.device_id} )"
    else
      disposition = " calls.provider_id = #{self.id} "
    end

    disposition += " AND disposition = '#{options[:call_type]}' " if options[:call_type] != "all"
    disposition += " AND calldate BETWEEN '#{options[:date_from]}' AND '#{options[:date_till]}'"
    # csv_header = [_("date"), _("called_from"), _("called_to"),_("Destination"), _("duration"), _("Billsec"), _("hangup_cause"), _("User_Price")+"("+options[:show_currency].to_s+")",  _("Provider_price")+"("+options[:show_currency]+")", _("Profit")+"("+options[:show_currency]+")", _("Margin %"), _("Markup %")]
    exrate = Currency.count_exchange_rate(options[:default_currency], options[:show_currency])

    # fm1 = " ROUND("
    # fm2 =" ,#{options[:nice_number_digits]}) "

    r1 = dec == "." ? "" : "replace("
    r2 = dec == "." ? "" : ", '.', '#{dec}')"
    n1 = "#{r1}" #"#{r1} FORMAT("
    n2 = "#{r2}" #",#{options[:nice_number_digits]})#{r2}"
    c1 = options[:default_currency] != options[:show_currency] ? " * #{exrate.to_d} " : ""

    select2 = []
    format = Confline.get_value('Date_format', 0).gsub('M', 'i')
    select2 << SqlExport.nice_date('calldate', {:reference => 'calldate', :format => format, :tz => options[:tx]})
    select2 << "src , dst , direction , duration , billsec , disposition , #{n1}provider_price3#{n2} as provider_price3, #{n1}user_price3#{n2} as user_price3"
    select2 << "#{n1}(user_price3-provider_price3)#{n2} as 'profit'"

    select = []
    select << "calls.calldate"
    select << "IF(#{options[:show_full_src].to_i} = 1 AND CHAR_LENGTH(clid)>0 AND clid REGEXP'\"' , CONCAT(src, '  ' ,REPLACE(SUBSTRING_INDEX(clid, '\"', 2), '\"', '('), ')'), src) as 'src'"
    select << "calls.dst"
    select << "CONCAT(IF(directions.name IS NULL, '',directions.name), ' ', IF(destinations.name IS NULL, '',destinations.name), ' ', IF(destinations.subcode IS NULL, '',destinations.subcode)) as 'direction'"

    select << "IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) ) as 'duration'"
    if  options[:direction].to_s == "incoming"
      select << "calls.did_billsec as 'billsec'"
      select << "calls.disposition"
      select << "IF(calls.provider_price IS NOT NULL, calls.did_prov_price#{c1}, 0) as 'provider_price3'"
      select2 << "'0' as 'm1'"
      select2 << "'0' as 'm2'"
    else
      select << "IF(calls.billsec = 0 AND calls.real_billsec > 0, calls.real_billsec, calls.billsec) as 'billsec'"
      select << "calls.disposition"
      select << "IF(calls.provider_price IS NOT NULL, calls.provider_price#{c1}, 0) as 'provider_price3'"
      select2 << "IF( (((user_price3-provider_price3) / user_price3 ) *100) IS NULL, 0,  #{n1}(((user_price3-provider_price3) / user_price3 ) *100) #{n2}) as 'm1'"
      select2 << "IF(( ((user_price3 / provider_price3) *100)-100 ) IS NULL, 0 ,   #{n1}( ((user_price3 / provider_price3) *100)-100 ) #{n2}) as 'm2'"
    end

    select << "IF(calls.reseller_id > 0, calls.reseller_price#{c1} , calls.user_price#{c1}) as 'user_price3'"

    filename = "CDR-#{SqlExport.clean_filename(self.name)}-#{options[:date_from].gsub(" ", "_").gsub(":", "_")}-#{options[:date_till].gsub(" ", "_").gsub(":", "_")}-#{Time.now().to_i}-#{rand(20000).to_i}-#{options[:direction]}-#{options[:show_currency]}"

    sql = "SELECT * "
    if options[:test] != 1
      sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{sep}' OPTIONALLY ENCLOSED BY '#{''}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
    end
    sql += " FROM ("+
        #         "SELECT '#{csv_header.join("'"+sep+"'")}'"+
        #       " UNION "+
        "SELECT #{select2.join(" , ")}  FROM
            ((SELECT #{select.join(" , ")}
      FROM calls LEFT JOIN destinations ON (calls.prefix = destinations.prefix) LEFT JOIN directions ON (directions.code = destinations.direction_code)
      WHERE #{disposition}
      ORDER BY calls.calldate DESC)) as temp_a) as temp_c;"

    test_data = ''

    if options[:test].to_i == 1
      test_data = ActiveRecord::Base.connection.select_all(sql).to_json
    else
      mysql_res = ActiveRecord::Base.connection.execute(sql)
    end
    return filename, test_data
  end

  #========== DEBUG ===================
  def my_debug(msg)
    File.open(Debug_File, "a") { |f|
      f << msg.to_s
      f << "\n"
    }
  end

  def Provider.providers_order_by(options)
    case options[:order_by].to_s.strip
      when "name"
        order_by = "providers.name"
      when "id"
        order_by = "providers.id"
      when "tech"
        order_by = "providers.tech"
      when "channel"
        order_by = "providers.channel"
      when "login"
        order_by = "providers.login"
      when "password"
        order_by = "providers.password"
      when "server_ip"
        order_by = "providers.server_ip"
      when "tariff"
        order_by = "tariffs.name"
      else
        options[:order_by] ? order_by = options[:order_by] : order_by = "providers.name"
    end
    order_by += " ASC" if options[:order_desc].to_i == 0 and order_by != ""
    order_by += " DESC" if options[:order_desc].to_i == 1 and order_by != ""
    return order_by
  end

  def Provider.find_all_for_select
    select('id, name').order('providers.name ASC').all
  end

  def Provider.find_all_with_calls_for_stats(current_user, options={})
    s = []

    exrate = Currency.count_exchange_rate(options[:default_currency], options[:show_currency])
    c1 = options[:default_currency] != options[:show_currency] ? " * #{exrate.to_d} " : ""

    s << 'providers.id, providers.name, providers.tech'
    s << 'COUNT(b.id) as pcalls'
    s << "SUM(IF(b.DISPOSITION='ANSWERED',1,0)) AS 'answered'"
    s << "SUM(IF(b.DISPOSITION='BUSY',1,0)) AS 'busy'"
    s << "SUM(IF(b.DISPOSITION='NO ANSWER',1,0)) AS 'no_answer'"
    s << "SUM(IF(b.DISPOSITION='FAILED' AND hangupcause < 200 ,1,0)) AS 'failed'"
    s << "SUM(IF(b.DISPOSITION='FAILED' AND hangupcause > 199 ,1,0)) AS 'failed_locally'"
    s << "SUM(b.billsec) AS billsec"
    if current_user.is_admin?
      con = ''
      s << "(SUM(b.provider_price)#{c1}) as 'selfcost_price'"
      s << "(SUM(IF(b.reseller_id > 0, b.reseller_price, b.user_price))#{c1}) AS 'sel_price'"
      s << "(SUM(IF(b.reseller_id > 0, b.reseller_price, b.user_price) - b.provider_price )#{c1}) AS 'profit'"
    else
      con = "OR (providers.common_use = 1 AND providers.id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{current_user.id}))"
      s << "(SUM(IF(providers.common_use = 1, b.reseller_price,b.provider_price))#{c1}) as 'selfcost_price'"
      s << "(SUM(b.user_price)#{c1}) AS 'sel_price'"
      s << "(SUM(b.user_price - IF(providers.common_use = 1, b.reseller_price,b.provider_price))#{c1} ) AS 'profit'"
    end

    jcond = ["calls.calldate BETWEEN '#{options[:date_from]}' AND '#{options[:date_till]}'"]
    jcond << "calls.prefix LIKE '#{options[:s_prefix]}'" if !options[:s_prefix].blank?

    if current_user.is_reseller?
      jcond << "(calls.reseller_id = #{current_user.id} OR calls.user_id = #{current_user.id})"
    end


    joins = []
    joins << "LEFT JOIN (SELECT calls.id, calls.DISPOSITION, calls.hangupcause, calls.did_provider_id, IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) ) as 'billsec', calls.provider_id, calls.provider_price, calls.user_price, calls.reseller_price, calls.reseller_id FROM calls
    WHERE  #{jcond.join(' AND ')} )
    as b ON (b.provider_id = providers.id OR b.did_provider_id = providers.id)"

    cond = ["(providers.user_id = #{current_user.id} #{con})"]
    cond << "providers.id = #{options[:p_id]}" if options[:p_id]
    cond << "providers.hidden = 0" if options[:show_hidden].to_i == 0

    sql = "SELECT #{s.join(' , ')} FROM providers
            #{joins.join(' ')}
            WHERE #{cond.join(' AND ')}
            GROUP BY providers.id " + (options[:hide_providers_without_calls].to_i == 1 ? "HAVING COUNT(b.id) > 0" : "") + " ORDER BY providers.name ASC"
    Provider.find_by_sql(sql)
  end

  def set_old
    self.old_register_record = self.register
    self.old_register_extension_record = self.reg_extension
    self.old_register_line_record = self.reg_line
  end

  def create_serverproviders(servers)
    if servers
      ss = []
      servers.each { |s|
        sp = Serverprovider.where("server_id = #{s[0].to_i} AND provider_id = #{id}").first
        if not sp
          serverprovider = Serverprovider.new({:server_id => s[0].to_i, :provider_id => id})
          serverprovider.save
        end
        ss << s[0].to_i
      }
      ActiveRecord::Base.connection.execute("DELETE FROM serverproviders WHERE provider_id = '#{id}' AND server_id NOT IN (#{ss.join(',')})")
    end
  end

  def create_server_devices(servers, dev_id)
    if servers.present?
      servers.each do |s|
        serv = ServerDevice.new({server_id: s, device_id: dev_id})
        serv.save if ServerDevice.where(server_id: s, device_id: dev_id).first.nil?
      end
      ServerDevice.delete_all("device_id = #{dev_id} AND server_id NOT IN (#{servers.join(',')})")
    else
      ServerDevice.delete_all("device_id = #{dev_id}")
    end
  end

  def update_by(request)
    self.max_timeout = request["max_timeout"] if request["max_timeout"]
    self.call_limit = request["call_limit"] if request["call_limit"]
    self.timeout  = request["timeout"] if request["timeout"]
    self.tariff_id  = request["tariff_id"] if request["tariff_id"]
  end

  #ticket #5618
  def max_timeout
    self.device.max_timeout
  end

  #ticket #5618 provider must have a device
  def max_timeout=(timeout)
    self.device.max_timeout = timeout
  end

  def is_dahdi?
    self.tech == 'dahdi'
  end

  def self.add_server_to_provider(server, provider)
    serverprovider = Serverprovider.new
    serverprovider.server_id = server.id
    serverprovider.provider_id = provider.id
    serverprovider.save
  end

  def self.list(params, session, current_user)
    session[:providers_list_options] ? options = session[:providers_list_options] : options = {}
    # search params parsing. Assign new params if they were sent, default unset params to "" and leave if param is set but not sent
    options = ApplicationController.helpers.clear_options(options) if params[:clear].to_i == 1
    options[:s_user_id] ||= current_user.id
    [:s_tech, :s_name, :s_hidden].each { |key|
      params[key] ? options[key] = (params[key].to_s) : (options[key] = "" if !options[key])
    }
    params[:s_server_ip] ? (options[:s_server_ip] = params[:s_server_ip].to_s.strip) : (options[:s_server_ip] = "" if !options[:s_server_ip])
    # page number is an exception because it defaults to 1
    if params[:page] and params[:page].to_i > 0
      options[:page] = params[:page].to_i
    else
      options[:page] = 1 if !options[:page] or options[:page] <= 0
    end
    # same goes for order descending
    params[:order_desc] ? options[:order_desc] = params[:order_desc].to_i : (options[:order_desc] = 0 if !options[:order_desc])
    params[:order_by] ? options[:order_by] = params[:order_by].to_s : options[:order_by] == "acc"
    order_by = current_user.providers.providers_order_by(options)

    cond = []
    cond_param = []
    #conditions
    ["name","server_ip"].each { |col|
      ApplicationController.helpers.add_contition_and_param(options["s_#{col}".to_sym], options["s_#{col}".intern].to_s, "providers.#{col} LIKE ?", cond, cond_param) }
    ["tech", "hidden", "owner_id"].each { |col|
      ApplicationController.helpers.add_contition_and_param(options["s_#{col}".to_sym], options["s_#{col}".intern].to_s, "providers.#{col} = ?", cond, cond_param) }

    total_pages = (current_user.providers.where([cond.join(" AND ")] + cond_param).size / session[:items_per_page].to_d).ceil
    options[:page] = total_pages if options[:page].to_i > total_pages and total_pages > 0

    providers = current_user.providers.where([cond.join(" AND ")] + cond_param).includes([:tariff]).offset(session[:items_per_page]*(options[:page]-1)).limit(session[:items_per_page]).order(order_by).all

    provider_used_by_resellers = Provider.find_by_sql("SELECT p.* FROM providers p LEFT JOIN lcrproviders l ON l.provider_id = p.id
     WHERE p.common_use = 1 AND (p.terminator_id IN (SELECT id FROM terminators WHERE user_id !=0) OR l.lcr_id IN (SELECT id FROM lcrs WHERE user_id !=0)) GROUP BY p.id")

    servers = Server.all

    search = 0
    search = 1 if cond.size.to_i > 1

    sql = "SELECT DISTINCT tech FROM providers WHERE tech != '' ORDER BY tech"
    provtypes = ActiveRecord::Base.connection.select_all(sql)

    admin_providers = nil
    if current_user.usertype == 'reseller' and params[:s_hidden].to_i == 0
      admin_providers = Provider.where("common_use = 1 AND id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{current_user.id})").order(order_by).all
    end

    n_class = ''

    return options, total_pages, providers, provider_used_by_resellers, servers, search, provtypes, admin_providers, n_class
  end

  def self.create_device_for_providers_assigns(params, provider)
    dev = Device.new
    dev.device_ip_authentication_record = params[:ip_authentication].to_i
    if params[:ip_authentication].to_s == "1"
      if !dev.name.include?('ipauth')
        name = dev.generate_rand_name('ipauth', 8)
        while Device.where(['name= ? and id != ?', name, dev.id]).first
          name = dev.generate_rand_name('ipauth', 8)
        end
        dev.name = name
      end
    else
      dev.name = "prov_" + provider.id.to_s #tmp
    end
    dev.host = "0.0.0.0"
    dev.ipaddr = "0.0.0.0"
    dev.secret = provider.password.strip
    dev.context = Default_Context
    dev.callerid = "" #coming from provider
    dev.extension = ApplicationController::random_password(10) #should be not-quesable
    dev.username = provider.login.strip
    dev.trustrpid = 'yes'
    dev.server_id = Confline.get_value("Resellers_server_id").to_i if User.current.usertype.to_s == 'reseller'
    dev.insecure = 'port,invite'
    dev.device_type = provider.tech.strip
    dev.user_id = -1 #means it's not ordinary user
                      #temp until taken from provider's table
    dev.istrunk = 1   #mark as trunk by default when call will be send to this provider, to send Destination info to it also
    dev.port = provider.port.strip
    dev.proxy_port = provider.port.strip
    dev.works_not_logged = 1
    dev.nat = "no"

    return dev
  end

  def self.create_device_for_providers_creation(params, dev, provider)
    dev.accountcode = dev.id
    #dev.name = "prov" + dev.id.to_s
    dev.save

    provider.device_id = dev.id
    provider.save

    provider.create_serverproviders(params[:add_to_servers])
  end

  def self.edit_assigns(session, provider)
    servers = Server.where(:server_type => 'asterisk').order(:id).all
    prules = provider.providerrules

    providertypes = Providertype.all
    curr = User.current.currency

    audio_codecs = provider.codecs_order('audio')
    video_codecs = provider.codecs_order('video')

    tariffs = Tariff.where(:purpose => 'provider', :owner_id => session[:user_id])

    locations = User.current.locations

    serverproviders = []
    provider.serverproviders.each { |p| serverproviders[p.server_id] = 1 }

    is_common_use_used = false
    provider_used_by_resellers_terminator = Provider.where(["id = ? AND common_use = 1 and terminator_id IN (select id from terminators where user_id != 0)", provider.id]).all
    provider_used_by_resellers_lcr = Lcrprovider.where(["(provider_id = ? and lcr_id IN (select id from lcrs where user_id != 0))", provider.id]).all
    if provider_used_by_resellers_terminator.size > 0 or provider_used_by_resellers_lcr.size > 0
      is_common_use_used = true
    end

    device = provider.device

    return device, is_common_use_used, serverproviders, locations, tariffs, video_codecs, audio_codecs, curr, providertypes, prules, servers
  end

  def self.edit_if_device_good(device)
    cid_name = ""
    if device.callerid
      cid_name = Provider.nice_cid(device.callerid)
      cid_number = Provider.cid_number(device.callerid)
    end

    if User.current.usertype.to_s == 'admin'
      number_pools = NumberPool.order("name ASC").all.collect{|i| [i.name, i.id]}

      if device.callerid_number_pool_id.to_i != 0
        device_caller_id_number = 2
      else
        device_caller_id_number = 1
      end
    end

    if device.qualify == "yes" or device.qualify == "no"
      qualify_time = 2000
    else
      qualify_time = device.qualify
    end

    return device, cid_name, cid_number, number_pools, device_caller_id_number, qualify_time
  end

  def self.device_unassign_user_id(device)
    device.user_id = -1

    return device
  end

  def self.destroy_exceptions(provider, device)
    if provider.tech == "SIP"
      exceptions = device.prune_device_in_all_servers(nil, 0, 1, 0)
      raise exceptions[0] if exceptions.size > 0

      # reloading sip and keeping realtime peers intact
      exceptions = provider.sip_reload_keeprt
      raise exceptions[0] if exceptions and exceptions.size > 0
    end

    if provider.tech == "IAX2"
      exceptions = device.prune_device_in_all_servers(nil, 0, 0, 1)
      raise exceptions[0] if exceptions.size > 0
    end

    if provider.tech == "H323"
      exceptions = provider.h323_reload
      raise exceptions[0] if exceptions.size > 0
    end
  end

  def self.provider_new(session)
    provider = Provider.new
    provider.tech = ''
    tariffs = Tariff.where(["purpose = 'provider' AND owner_id = ?", session[:user_id]])
    servers= Server.order(:id).all

    return provider, tariffs, servers
  end

  def self.provider_create(current_user, params, server)
    provider = Provider.create_by_user(current_user, params)

    provider.save

    # server
    sp = Serverprovider.where("server_id = #{server.id.to_i} AND provider_id = #{provider.id.to_i}").first
    if not sp
      serverprovider=Serverprovider.new
      serverprovider.server_id = server.id
      serverprovider.provider_id = provider.id
      serverprovider.save
    end
  end

  def self.billing(current_user, params, session)
    curr = current_user.currency
    session[:providers_billing_options] ? options = session[:providers_billing_options] : options = {}
    options = ApplicationController.helpers.clear_options(options) if params[:clear].to_i == 1
    options[:s_user_id] ||= current_user.id
    [:s_tech, :s_name, :s_hidden].each { |key|
      params[key] ? options[key] = params[key].to_s : (options[key] = "" if !options[key])
    }
    # page number is an exception because it defaults to 1
    if params[:page] and params[:page].to_i > 0
      options[:page] = params[:page].to_i
    else
      options[:page] = 1 if !options[:page] or options[:page] <= 0
    end
    # same goes for order descending
    params[:order_desc] ? options[:order_desc] = params[:order_desc].to_i : (options[:order_desc] = 0 if !options[:order_desc])
    params[:order_by] ? options[:order_by] = params[:order_by].to_s : options[:order_by] == "acc"
    order_by = current_user.providers.providers_order_by(options)

    cond = []
    cond_param = []
    #conditions
    ["name"].each { |col|
      ApplicationController.helpers.add_contition_and_param(options["s_#{col}".to_sym], options["s_#{col}".intern].to_s+"%", "providers.#{col} LIKE ?", cond, cond_param) }
    ["tech", "hidden", "owner_id"].each { |col|
      ApplicationController.helpers.add_contition_and_param(options["s_#{col}".to_sym], options["s_#{col}".intern].to_s, "providers.#{col} = ?", cond, cond_param) }

    total_pages = (current_user.providers.count(:all, :conditions => [cond.join(" AND ")] + cond_param).to_d / session[:items_per_page].to_d).ceil
    options[:page] = total_pages if options[:page].to_i > total_pages and total_pages > 0

    providers = current_user.providers.where([cond.join(" AND ")] + cond_param).includes([:tariff]).offset(session[:items_per_page]*(options[:page]-1)).limit(session[:items_per_page]).order(order_by).all

    n_class = ''

    return curr, options, total_pages, providers, n_class
  end

  private

  # converting caller id like "name" <11> to name
  def self.nice_cid(cidn)
    if cidn
      cid = cidn.split('"')
      cid = cid[1] #if cidn.index('<')
    else
      cid = ""
    end
    cid
  end

  # converting caller id like "name" <11> to 11
  def self.cid_number(cid)
    if cid and cid.index('<') and cid.index('>')
      cid = cid[cid.index('<')+1, cid.index('>') - cid.index('<') - 1]
    else
      cid = ""
    end
    cid
  end
end
