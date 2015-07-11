# -*- encoding : utf-8 -*-
class Did < ActiveRecord::Base
  attr_accessible :id, :did, :status, :user_id, :device_id, :subscription_id, :reseller_id
  attr_accessible :closed_till, :dialplan_id, :language, :provider_id, :comment, :call_limit
  attr_accessible :sound_file_id, :grace_time, :t_digit, :t_response, :reseller_comment, :cid_name_prefix
  attr_accessible :tonezone, :call_count, :cc_tariff_id, :owner_tariff_id

  attr_accessor :skip_conditions_callback

  attr_protected

  belongs_to :device
  belongs_to :user
  has_many :didrates
  belongs_to :dialplan
  belongs_to :provider
  has_many :activecalls
  has_many :calls
  has_many :first_call, -> { limit(1) }, :class_name => 'Call', :foreign_key => 'did_id'

  validates_uniqueness_of :did, :message => _("DID_must_be_unique")
  validates_presence_of :did, :message => _("Enter_DID")
  validates_format_of :did, :with => /\A\d+\z/, :message => _('DID_must_consist_only_of_digits'), :on => :create

  before_create :validate_provider, :reseller_did_creation
  before_save :validate_device, :validate_user, :check_collisions_with_qf_rules, :conditions
  before_destroy :find_if_used_in_calls

  # ----- scopes -----------------------------
  #get all
  scope :dids_all, -> { } # so that rails wouldn't go mad
  # get all dids where status = 'closed'
  scope :closed, -> { where('status = "closed"') }
  # get all dids where status = 'free'
  scope :free, -> { where('status = "free"') }
  # get all dids where status = 'active'
  scope :active, -> { where('status = "active"') }
  # get all dids where status = 'reserved'
  scope :reserved, -> { where('status = "reserved"') }
  # get all dids where status = 'terminated'
  scope :terminated, -> { where('status = "terminated"') }


  attr_accessor :closing

  def conditions
    unless @skip_conditions_callback
      if (self.user.try(:usertype).to_s == "reseller") and self.dialplan_id.to_i > 0
        errors.add(:did, _("Dont_be_so_smart"))
        return false
      end
    end
  end

  def validate_provider
    if !['admin', 'accountant'].include?(User.current.usertype)
      c_u = User.current
      if c_u.usertype == 'reseller' and provider and c_u.own_providers.to_i == 1 and !c_u.providers.where("providers.id = #{provider.id}").first and provider.id != Confline.get_value("DID_default_provider_to_resellers").to_i
        errors.add(:provider, _("Provider_not_found"))
        return false
      end

      if c_u.usertype == 'reseller' and provider and c_u.own_providers.to_i == 0 and provider.id.to_i != Confline.get_value("DID_default_provider_to_resellers").to_i
        errors.add(:provider, _("Provider_not_found"))
        return false
      end

    end
  end

  def validate_device
    #logger.info "etfffffff"
    if User.current and !['admin', 'accountant'].include?(User.current.usertype)
      if User.current.usertype == 'reseller' and device and !User.current.load_users_devices({first: true, conditions: "devices.id = #{device.id}"})
        errors.add(:device, _("Device_not_found"))
        return false
      end
    end
    if self.device and self.device.is_trunk? and User.current.is_reseller? and not User.current.allowed_to_assign_did_to_trunk? and not self.closing
      self.errors.add(:device, _('DID_cannot_be_assigned_to_trunk'))
      return false
    end
  end

  def validate_user
    if User.current and !['admin', 'accountant'].include?(User.current.usertype)
      if User.current.usertype == 'reseller' and status == 'reserved' and user and !User.where("users.id = #{user.id} and users.owner_id = #{User.current.id}").first
        errors.add(:user, _("User_not_found"))
        return false
      end
    end
  end

  def reseller
    @attributes["reseller"] ||= User.where(["users.id = ? and users.usertype='reseller'", self.reseller_id]).first
  end

  def reseller=(reseller)
    @attributes["reseller"] = reseller
    @attributes["reseller_id"] = reseller.id if reseller.class == User
  end

  def did_prov_rates(t ='')
    did_check_rates('provider', t)
  end

  def did_incoming_rates(t ='')
    did_check_rates('incoming', t)
  end

  def did_owner_rates(t ='')
    did_check_rates('owner', t)
  end

  def did_check_rates(type, t)
    cond = t ? ["did_id = ? AND rate_type = ? AND daytype = ?", self.id, type, t] : ["did_id = ? AND rate_type = ?", self.id, type]
    Didrate.where(cond).order('start_time ASC').all
  end

  def check_did_rates
    r_size = Didrate.where(['did_id = ?', id]).group("rate_type").all

    if !r_size or r_size.size < 3
      ['provider', 'incoming', 'owner'].each { |rtype|
        if !Didrate.where(['did_id = ? AND rate_type = ? ', id, rtype]).first
          dr = Didrate.new(:did_id => id, :rate_type => rtype.to_s)
          dr.save
        end
      }
    end
  end

  def make_free
    self.user_id = 0
    self.device_id = 0
    self.dialplan_id = 0
    #ticket 6224 if did was assigned to reseller we should reset cc_tariff_if, because
    #the tariff might be reseller's whitch no one else can see or use.
    if self.reseller_id != 0
      self.cc_tariff_id = 0
    end
    self.reseller_id = 0
    self.status = "free"
    self.save
  end

  def make_free_for_reseller
    self.user_id = 0
    self.device_id = 0
    self.dialplan_id = 0
    self.status = "free"
    self.save
  end

  def assign(device_id)
    dev = Device.find(device_id)
    if dev.primary_did_id == 0
      dev.primary_did_id = self.id
      dev.save
    end

    self.device_id = device_id
    self.external_server = ''
    self.status = "active"
    self.save
  end

  def unassing
    if dev = self.device
      dev.primary_did_id = 0
      dev.save
    end
    self.device_id = 0
    self.save
  end

  def assign_server(server)
    self.external_server = server
    self.device_id = -2
    self.status = "active"
    self.save
  end

  def close
    dev = Device.where(["id = ?", device_id]).first

    if dev and dev.primary_did_id == self.id
      dev.primary_did_id = 0
      dev.save
      #dev.update_cid(self.device.name)
    end

    self.status = "closed"
    self.closed_till = (Time.now + Confline.get_value("Days_for_did_close").to_i.days).strftime("%Y-%m-%d %H:%M:%S")
    self.closing = true
    self.save

  end

  def reserve(user_id)
    did_user = User.where(["id = ?", user_id]).first
    if did_user and did_user.is_reseller?
      self.update_attributes({:reseller_id => did_user.id, :user_id => 0, :device_id => 0, :status => "free", :cc_tariff_id => 0})
    else
      self.update_attributes({:user_id => user_id, :status => "reserved"})
    end
  end

  def terminate
    self.user_id = 0
    self.device_id = 0
    self.reseller_id = 0
    self.status = "terminated"
    self.save
  end

  #debug
  #put value into file for debugging
  def my_debug(msg)
    File.open(Debug_File, "a") { |f|
      f << msg.to_s
      f << "\n"
    }
  end

  def Did.find_all_for_select
    if User.current.usertype == 'reseller'
      select('id, did').where(reseller_id: User.current.id).all
    else
      select('id, did').all
    end
  end

  def Did.free_dids_for_select(id = 0)
    if User.current.usertype == 'reseller'
      reseller = User.current.id
    else
      reseller = 0
    end
    select("id, did").where(["status = 'free' and reseller_id = ? AND id != ?", reseller, id]).order('did ASC')
  end

  def Did.forward_dids_for_select(id = 0)
    if User.current.usertype == 'reseller'
      reseller = User.current.id
    else
      reseller = 0
    end
    select("id, did").where(["dialplan_id != 0 and reseller_id = ? AND id != ?", reseller, id]).order('did ASC')
  end

=begin
  Checks whether did has associated calls with if or not.

  *Returns*
  *boolean* - true if did has no associated calls with it, else returns false
=end
  def find_if_used_in_calls
    #Call.where("did_id = #{self.id}").first ? false : true
    self.call_count.to_i > 0 ? false : true
  end

  # cc_tariff_if can only be integer greater than 0 or by default 0
  def cc_tariff_id=(value)
    write_attribute(:cc_tariff_id, value.to_i)
  end

  def reseller_did_creation
    if User.current.usertype.downcase == "reseller"
      did = self.did
      rules = did.blank? ? [] : QuickforwardsRule.where(["#{did} REGEXP(concat('^',replace(replace(rule_regexp, '%', ''),'|','|^'))) and user_id = 0 and id != ?", User.current.quickforwards_rule_id])
      if rules.size > 0
        errors.add(:qf_rule_collision,_('Collisions_with_Quickforwards_Rules_rs'))
        return false
      end
    end
  end

  def check_collisions_with_qf_rules
    if self.find_collisions_with_qf_rules
      errors.add(:qf_rule_collision,_('Collisions_with_Quickforwards_Rules'))
      return false
    end
  end

  def find_collisions_with_qf_rules
    dids = self.find_qf_rules
    if dids.to_i > 0  and (self.dialplan and self.dialplan.dptype != 'quickforwarddids' or self.status == 'reserved')
      return true
    else
      return false
    end
  end

  def find_qf_rules
     rules = self.did.blank? ? [] : QuickforwardsRule.where("#{did} REGEXP(concat('^',replace(replace(rule_regexp, '%', ''),'|','|^')))")
     rule_ids = rules.collect(&:id)
     counter = 0

     rules.each do |rule|
       if rule.user_id.to_i == 0
         counter += 1
       else
         if ((rule_ids.include? User.where(:id => rule.user_id).first.quickforwards_rule.id) rescue false)
           counter += 1
         else
           next
         end
       end
     end
     return counter
  end

#  def find_qf_rules
#    QuickforwardsRule.where("#{did} REGEXP(replace(rule_regexp, '%', ''))").all.count
#  end

  def Did.insert_dids_from_csv_file(name,owner_id,prov_id)
    CsvImportDb.log_swap('analize')
    MorLog.my_debug("CSV analize_file #{name}", 1)

    dids_in_csv_file = (ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name}").to_i).to_s

    #------------ Analyze ------------------------------------
    # strip all DIDs
    ActiveRecord::Base.connection.execute("UPDATE #{name} set did = REPLACE( #{name}.did, ' ', '' )")

    # set error flag on duplicates | code : 1
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1 WHERE did IN (SELECT number FROM (select did as number, count(*) as u from #{name} group by did having u > 1) as imf )")

    # unset error for first number of duplicates
    ActiveRecord::Base.connection.execute("UPDATE #{name}, (SELECT id FROM #{name} WHERE f_error = 1 GROUP BY did) AS A SET f_error = 0 WHERE f_error = 1 AND #{name}.id = A.id")

    # set error flag where number is found in DB | code : 2
    ActiveRecord::Base.connection.execute("UPDATE #{name} LEFT JOIN dids ON (replace(#{name}.did, '\\r', '') = dids.did) SET f_error = 2 WHERE dids.id IS NOT NULL AND f_error = 0")

    # set error flag on not int numbers | code : 3
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 3 WHERE replace(#{name}.did, '\\r', '') REGEXP '^[0-9]+$' = 0")

    # set error flag on numbers which comtains \r | code : 3
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 3 WHERE replace(#{name}.did, '\\\\r', '') REGEXP '^[0-9]+$' = 0")

    # set error flag on collisions with QF | code : 4
    all_dids = ActiveRecord::Base.connection.select_all("SELECT * FROM #{name} WHERE f_error = 0").each(&:symbolize_keys!).collect{|v| v[:did]}
    dids_with_collisions = []
    if owner_id.to_i != 0
      assigned_qf = User.select("quickforwards_rule_id").where(:id => owner_id.to_i).first.quickforwards_rule_id
      cond = "and id != #{assigned_qf.to_s}" if assigned_qf.to_i > 0
      all_dids.each{|did|
        a = QuickforwardsRule.where("#{did} REGEXP(concat('^',replace(replace(rule_regexp, '%', ''),'|','|^'))) and user_id = 0 #{cond}")
        dids_with_collisions << did if a.size > 0
      }
    end
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 4 WHERE did IN (#{dids_with_collisions.join(',')})") if dids_with_collisions.size > 0

    #------------ Import -------------------------------------
    CsvImportDb.log_swap('create_dids_start')
    count = 0

    s1 = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_error = 0").to_i
    n = s1/1000 +1

    if owner_id.to_i == 0
      n.times{| i|
        nr_sql = "INSERT INTO dids (did,provider_id)
                      SELECT did,#{prov_id.to_s} FROM #{name}
                      WHERE f_error = 0 LIMIT #{i * 1000}, 1000"
        begin
          ActiveRecord::Base.connection.execute(nr_sql)
          count += ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_error = 0 LIMIT #{i * 1000}, 1000").to_i
        end
      }
    else
      n.times{| i|
        nr_sql = "INSERT INTO dids (did,reseller_id,provider_id)
                      SELECT did,#{owner_id.to_s},#{prov_id.to_s} FROM #{name}
                      WHERE f_error = 0 LIMIT #{i * 1000}, 1000"
        begin
          ActiveRecord::Base.connection.execute(nr_sql)
          count += ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_error = 0 LIMIT #{i * 1000}, 1000").to_i
        end
      }
    end

    CsvImportDb.log_swap('create_dids_end')
    return dids_in_csv_file, count
  end

  #order_by
  def Did.dids_order_by(options)
    order_type = options[:order_desc].to_i == 0 ? ' ASC' : ' DESC'
    case options[:order_by].to_s.strip
      when "DID" then
        order_by = "dids.did"
      when "Language" then
        order_by = 'dids.language'
      when "Status" then
        order_by = "dids.status"
      when "Provider" then
        order_by = "providers.name"
      when "Devices" then
        order_by = "devices.name"
      when "Dialpaln" then
        order_by = "dialplan.name"
      when "Simultaneous_Call_limit" then
        order_by = "call_limit"
      when "Comment" then
        order_by = "dids.comment"
      when "Tone_zone" then
        order_by = "dids.tonezone"
      when "Reseller" then
          order_by = "users.first_name" + order_type + ',' + " users.last_name"
      when "Owner"
        order_by = "users.first_name" + order_type + ',' + " users.last_name"
      else
        order_by = "dids.did"
    end
    order_by += order_type
    return order_by
  end

  def self.assign_did_to_calling_card_dp(did, answer, number_length, pin_length)
    dp = Dialplan.new
    dp.name = "CallingCard DP, answer: #{answer}, nl: #{number_length}, pl: #{pin_length}"
    dp.dptype = "callingcard"
    dp_id = dp.id
    dp.save

    dp_ext = "dp" + dp_id.to_s

    did.dialplan_id = dp_id
    did.status = "active"
    did.save

    #delete old config
    #Extline.destroy_all ["exten = ?", did.did]
    #Extline.mcreate(Default_Context, 1, "Goto", dp_ext+"|1", did.did, 0)

    # dp extlines
    answeri = 0
    answeri = 1 if answer

    Extline.mcreate(Default_Context, 1, "Set", "MORCC_ANSWER=#{answeri}", dp_ext, 0)
    Extline.mcreate(Default_Context, 2, "Set", "MORCC_NUMBER_LENGTH=#{number_length}", dp_ext, 0)
    Extline.mcreate(Default_Context, 3, "Set", "MORCC_PIN_LENGTH=#{pin_length}", dp_ext, 0)
    Extline.mcreate(Default_Context, 4, "Set", "MORCC_DESTINATION=#{did.did}", dp_ext, 0)
    Extline.mcreate(Default_Context, 5, "Set", "MOR_TELL_TIME=1", dp_ext, 0)
    Extline.mcreate(Default_Context, 6, "Set", "MOR_TELL_BALANCE=1", dp_ext, 0)
    Extline.mcreate(Default_Context, 7, "Set", "MOR_TELL_RTIME_WHEN_LEFT=120", dp_ext, 0)
    Extline.mcreate(Default_Context, 8, "Set", "MOR_TELL_RTIME_EVERY=60", dp_ext, 0)
    Extline.mcreate(Default_Context, 9, "Set", "LIMIT_TIMEOUT_FILE=mor/morcc_credit_low", dp_ext, 0)
    Extline.mcreate(Default_Context, 10, "Set", "CHANNEL(language)=#{did.language}", dp_ext, 0)
    Extline.mcreate(Default_Context, 11, "morcc", "", dp_ext, 0)
    Extline.mcreate(Default_Context, 12, "Hangup", "", dp_ext, 0)
  end

  def update_provider_did(params, current_user, comment)
    self.language = params[:did][:language].to_s.strip
    old_did_number = nil

    if params[:did][:provider_id]
      current_provider = provider
      admin = User.current_user.is_admin?
      if !admin || User.current_user.id == current_provider.user_id
        self.provider_id = params[:did][:provider_id].to_s.strip
      elsif admin
        bad_provider = true
      end
    end

    unless current_user.usertype == 'reseller'
      old_did_number = did
      if params[:did][:did] and params[:did][:did]!= self.did
        self.did = params[:did][:did].to_i
      end
      self.call_limit = params[:did][:call_limit].to_i
      self.call_limit = 0 if self.call_limit < 0
      self.comment = params[:did][:comment].to_s.strip if comment.to_i == 1
      self.user_id = params[:user_id] if params[:user_id]
      self.device_id = params[:device_id] if params[:device_id]
    else
      self.reseller_comment = params[:did][:reseller_comment].to_s.strip if comment.to_i == 1
    end
    self.cid_name_prefix = params[:did][:cid_name_prefix]
    return old_did_number, bad_provider
  end

  def self.did_rates_index(did_i)
    did = {prov_rates_c: did_i.did_prov_rates, incoming_rates_c: did_i.did_incoming_rates,
           owner_rates_c: did_i.did_owner_rates, prov_rates_f: did_i.did_prov_rates('FD'),
           incoming_rates_f: did_i.did_incoming_rates('FD'), owner_rates_f: did_i.did_owner_rates('FD'),
           prov_rates_w: did_i.did_prov_rates('WD'), incoming_rates_w:did_i.did_incoming_rates('WD'),
           owner_rates_w: did_i.did_owner_rates('WD')
    }

    return did.values
  end

  #
  def self.seek_by_filter(filter, current_user, did_str, style)
    output = []
    cond = ['dids.id > 0']
    var = []
    cond << 'dids.reseller_id = ?' and var << current_user.id if current_user.is_reseller?
    is_reseller = (current_user.is_reseller? ? ' AND dids.reseller_id = ' << current_user.id.to_s : false)
    cond << 'did LIKE ?' and var << did_str + '%' if did_str.to_s != ''
    case filter
    when 'ringgroup'
      cond << '(device_id != 0 OR dialplan_id != 0)'
      seeker = Did.where([cond.join(' AND ')].concat(var)).order('dids.did ASC')
      seek = seeker.limit(20).map { |did| ["<tr><td id='" << did.id.to_s << "' #{style}>" << did.did << '</td></tr>'] }
    when 'callback'
      cond << 'dialplans.dptype != "callback"'
      seeker = Did.where([cond.join(" AND ")].concat(var)).order("dids.did ASC").joins('INNER JOIN dialplans ON (dids.dialplan_id = dialplans.id)')
      seek = seeker.limit(20).map { |did| ["<tr><td id='" << did.id.to_s << "' #{style}>" << did.did << " - " << did.dialplan.name << '</td></tr>'] }
    when 'ivrs'
      cond << 'dids.status = "active"'
      seeker = Did.where([cond.join(' AND ')].concat(var)).order('dids.did ASC')
      seek = seeker.limit(20).map { |did| ["<tr><td id='" << did.id.to_s << "' #{style}>" << did.did << ' (' << did.status << ')</td></tr>'] }
    when 'forward_dids'
      cond << 'dialplan_id != 0'
      seeker = Did.where([cond.join(' AND ')].concat(var)).order('dids.did ASC')
      seek = seeker.limit(20).map { |did| ["<tr><td id='" << did.id.to_s << "' #{style}>" << did.did << '</td></tr>'] }
    else
      seeker = Did.where([cond.join(' AND ')].concat(var)).order('dids.did ASC')
      seek = seeker.limit(20).map { |did| ["<tr><td id='" << did.id.to_s << "' #{style}>" << did.did << '</td></tr>'] }
    end
    output << seek
    total_dids = seeker.size - 20
    if total_dids > 0
      output << "<tr><td id='-2' #{style}>" << _('Found') << " " << total_dids.to_s << ' ' << _('more') << '</td></tr>'
    elsif seek.size == 0
      output = ["<tr><td id='-2' #{style}>" << _('No_value_found') << '</td></tr>']
    end

    return output, total_dids
  end

end
