# -*- encoding : utf-8 -*-
class Confline < ActiveRecord::Base

  attr_protected

  validates_presence_of :name
  # Returns confline value of given name and user_ID
  def Confline::get_value(name, id = 0)
    cl = Confline.where(["name = ? and owner_id  = ?", name, id]).first
    return cl.value if cl
    return ""
  end

  def self.by_params(*params)
    cl = Confline.where(["name = ? and owner_id  = ?", params.slice(0..-2).join("_"), params.last]).first
    return cl.value if cl
    return ""
  end

  def self.by_params2(*params)
    cl = Confline.where(["name = ? and owner_id  = ?", params.slice(0..-2).join("_"), params.last]).first
    return cl.value2 if cl
    return ""
  end

  def Confline::get_value2(name, id = 0)
    cl = Confline.where(["name = ? and owner_id  = ?", name, id]).first
    return cl.value2 if cl
    return ""
  end

  def Confline::get_values(name, id = 0)
    return get_value(name, id), get_value2(name, id)
  end

  def Confline::update_sms_settings(params, user_id)
    set_value("SMS_Email_Pop3_Server", params[:email_pop3_server].to_s, user_id)
    set_value("SMS_Email_Login", params[:email_login], user_id)
    set_value("SMS_Email_Password", params[:email_password], user_id)
    set_value("Send_SMS_from_Front_page", params[:send_sms_from_front_page].to_i, user_id)
    set_value2("Frontpage_SMS_Text", params[:frontpage_sms_text].to_s, user_id)
  end

  def Confline::update_reseller_settings_payments(params, user_id)
    Confline.set_value("Paypal_Enabled", params[:reseller_paypal_enabled].to_i, user_id)
    Confline.set_value("PayPal_Email", params[:reseller_paypal_email], user_id)
    Confline.set_value("PayPal_Default_Currency", params[:reseller_paypal_default_currency], user_id)
    Confline.set_value("PayPal_Default_Amount", params[:reseller_paypal_default_amount], user_id)
    Confline.set_value("PayPal_User_Pays_Transfer_Fee", params[:paypal_user_pays_transfer_fee], user_id)
    Confline.set_value("PayPal_Min_Amount", params[:reseller_paypal_min_amount], user_id)
    Confline.set_value("PayPal_Max_Amount", params[:reseller_paypal_max_amount], user_id)
    Confline.set_value("PayPal_Test", params[:reseller_paypal_test], user_id)
    Confline.set_value("PayPal_Email_Notification", params[:reseller_paypal_email_notification], user_id)
    Confline.set_value("PayPal_Payment_Confirmation", params[:reseller_paypal_payment_confirmation], user_id)
    Confline.set_value('PayPal_Custom_redirect', params[:paypal_custom_redirect], user_id)
    Confline.set_value('Paypal_return_url', params[:paypal_return_url], user_id)
    Confline.set_value('Paypal_cancel_url', params[:paypal_cancel_url], user_id)

    #WebMoney
    if params[:reseller_webmoney_enabled]
      Confline.set_value("WebMoney_Enabled ", '1', user_id)
    else
      Confline.set_value("WebMoney_Enabled ", '0', user_id)
    end
    if params[:reseller_webmoney_test]
      Confline.set_value("WebMoney_Test", '1', user_id)
    else
      Confline.set_value("WebMoney_Test", '0', user_id)
    end
    Confline.set_value("WebMoney_Gateway ", params[:webmoney_gateway].to_i, user_id)
    Confline.set_value("WebMoney_Default_Currency", params[:reseller_webmoney_default_currency], user_id)
    Confline.set_value("WebMoney_Min_Amount", params[:reseller_webmoney_min_amount], user_id)
    Confline.set_value("WebMoney_Default_Amount", params[:reseller_webmoney_default_amount], user_id)

    Confline.set_value("WebMoney_Purse", params[:reseller_webmoney_purse], user_id)
    Confline.set_value("WebMoney_SIM_MODE", params[:reseller_webmoney_sim_mode], user_id)

    #Vouchers
    Confline.set_value("Vouchers_Enabled", params[:vouchers_enabled].to_i, user_id)
    Confline.set_value("Voucher_Card_Disable", params[:voucher_card_disable].to_i, user_id)
  end

=begin rdoc
 Check whether or what setting user has set to view dids in active calls, if nothing has been
 defaults to 'do not show'

 *Params*
 * +owner_id+ - User.id that shows confline owner. if nothing has been passed default to admin

 *Returns*
 * +boolean+ - true or false depending on what user has set and whether he has set anything
=end
  def self.active_calls_show_did?(owner_id = 0)
    get_value('Active_calls_show_did', owner_id) == "1" ? true : false
  end

  # Sets confline value.
  def Confline::set_value(name, value = 0, id = 0)
    cl = Confline.where(["name = ? and owner_id = ?", name, id]).first
    if cl
      if cl.value.to_s != value.to_s
        u = User.current ? User.current.id : -1
        Action.add_action_hash(u, {:action => "Confline changed", :target_id => cl.id, :target_type => 'confline', :data => cl.value.to_s, :data2 => value.to_s, :data4 => name})
      end
      cl.value = value
      cl.save
    else
      new_confline(name, value, id)
    end
  end

  def Confline::set_value2(name, value = 0, id = 0)
    cl = Confline.where(["name = ? and owner_id = ?", name, id]).first
    if cl
      if cl.value2.to_s != value.to_s
        if User.current_user
          Action.add_action_hash(User.current_user.id, {:action => "Confline changed", :target_id => cl.id, :target_type => 'confline', :data => cl.value2.to_s, :data2 => value.to_s, :data3 => 'value2', :data4 => name})
        else
          Action.add_action_hash(-1, {:action => "Confline changed", :target_id => cl.id, :target_type => 'confline', :data => cl.value2.to_s, :data2 => value.to_s, :data3 => 'value2', :data4 => name})
        end
      end
      cl.value2 = value
      cl.save
    else
      #self.my_debug("Confline missing: " + name.to_s + " ---> Created")
      Confline.new_confline2(name, value, id)
    end
  end

  # creates new confline with given params
  def Confline::new_confline(name, value, id = 0)
    confline = Confline.new()
    confline.name = name.to_s
    confline.value = value.to_s
    confline.owner_id = id
    confline.save
  end

  def Confline::new_confline2(name, value, id = 0)
    confline = Confline.new()
    confline.name = name.to_s
    confline.value2 = value.to_s
    confline.owner_id = id
    confline.save
  end

  def Confline::get_tax_number(id = 0)
    cl = Confline.where(["name Like 'Tax_%' and value2 = '1' AND owner_id = ?", id]).all
    return cl.size
  end

  def Confline::my_debug(msg)
    File.open(Debug_File, "a") { |f|
      f << "Confline.my_debug() is deprecated use MorLog.my_debug()\n"
      f << msg.to_s
      f << "\n"
    }
  end

  def Confline::get(name, id = 0)
    cl = Confline.where("name = '#{name}' and owner_id  = #{id} ").first
    return cl if cl
    return nil
  end

=begin rdoc
 Sets Conflines with name format "Default_Object_action" and value = data.
 This action is used to store default objects in conflines table.

 *Params*
 * +object+ - Class name variable. User, Device etc.
 * +owner_id+ - User.id that shows confline owner.
 * +data+ - hash of object properties. +object+ has method with same name as hash key, then hash value is used as default value.
=end

  def Confline.set_default_object(object, owner_id, data)
    instance = object.new
    data.each { |key, value|
      Confline.set_value("Default_#{object.to_s}_#{sanitize_sql(key)}", value, owner_id) if instance.respond_to?(key.to_sym)
    }
  end

=begin rdoc
 Recreates +object+ from Confline fields.

 *Params*
 * +object+ - Class name variable. User, Device etc.
 * +owner_id+ - User.id that shows confline owner.

 *Returns*
 +instance+ - instance of class +object+ with set default properties
=end

  def Confline.get_default_object(object, owner_id = 0)
    instance = object.new
    attributes = Confline.where(["name LIKE 'Default_#{object.to_s}_%' AND owner_id = ?", owner_id]).all
    attributes.each { |confline|
      val = confline.value
      key = confline.name.gsub("Default_#{object.to_s}_", "")
      if key.include?("Default_#{object.to_s.downcase.to_s}_")
        key = confline.name.gsub("Default_#{object.to_s.downcase.to_s}_", "")
      end
      if object != Device or (object == Device and (!key.include?('voicemail') and !key.include?('type')))
        instance.__send__((key+"=").to_sym, val) if instance.respond_to?(key.to_sym)
      end
    }
    instance
  end

=begin rdoc
 Returns Tax object filled with default values from conflines.

 *Params*
 * +owner_id+ - User.id that shows confline owner.

 *Returns*
 +tax+ - Tax object filled with default values.
=end

  def Confline.get_default_tax(owner_id)
    tax ={
        :tax1_enabled => 1,
        :tax2_enabled => Confline.get_value2("Tax_2", owner_id).to_i,
        :tax3_enabled => Confline.get_value2("Tax_3", owner_id).to_i,
        :tax4_enabled => Confline.get_value2("Tax_4", owner_id).to_i,
        :tax1_name => Confline.get_value("Tax_1", owner_id).to_s,
        :tax2_name => Confline.get_value("Tax_2", owner_id).to_s,
        :tax3_name => Confline.get_value("Tax_3", owner_id).to_s,
        :tax4_name => Confline.get_value("Tax_4", owner_id).to_s,
        :total_tax_name => Confline.get_value("Total_tax_name", owner_id).to_s,
        :tax1_value => Confline.get_value("Tax_1_Value", owner_id).to_d,
        :tax2_value => Confline.get_value("Tax_2_Value", owner_id).to_d,
        :tax3_value => Confline.get_value("Tax_3_Value", owner_id).to_d,
        :tax4_value => Confline.get_value("Tax_4_Value", owner_id).to_d
    }
    Tax.new(tax)
  end

  def Confline.get_csv_separator(user_id = 0)
    sep = Confline.get_value("CSV_Separator", user_id)
    sep = "," if sep.blank?
    sep
  end

=begin
  Get information about chann spy functionality, whether it is enabled or not. Only
  admin can enable/disable it, hence no user_id is specified when calling get_value.

  *Returns*
  +disabled+ boolean, true if chan_spy is disabled, else false. notice that if setting
    would not be specified, false would be returned be default, meaning that chan spy is
    enabled by default.
=end
  def Confline.chanspy_disabled?
    self.get_value("chanspy_disabled").to_i == 1
  end

=begin
  ERP settings are valid if login, pass and domain are set and not blank

  *Returns*
  +valid+ true if
=end
  def self.valid_erp_settings?(user_id)
    login = Confline.get_value("ERP_login", user_id)
    pass = Confline.get_value("ERP_password", user_id)
    host = Confline.get_value("ERP_domain", user_id)

    not (host.blank? or login.blank? or pass.blank?)
  end

  def self.get_default_user_pospaid_errors
    ActiveRecord::Base.connection.select_all('SELECT owner_id FROM conflines WHERE name IN (\'Default_User_allow_loss_calls\', \'Default_User_postpaid\') AND value = 1 GROUP BY owner_id HAVING COUNT(*) > 1 ;')
  end

  def self.load_recaptcha_settings
    if Confline.get_value("reCAPTCHA_enabled").to_i == 1
      Recaptcha.configuration.send("public_key=", Confline.get_value("reCAPTCHA_public_key"))
      Recaptcha.configuration.send("private_key=", Confline.get_value("reCAPTCHA_private_key"))
      Recaptcha.configuration.public_key = Confline.get_value("reCAPTCHA_public_key")
      Recaptcha.configuration.private_key = Confline.get_value("reCAPTCHA_private_key")
    end
  end

  def Confline.send_email_notice
    [
        [_('at_once_when_generated'), '1'], [_('every_3h'), '2'], [_('every_6h'), '3'],
        [_('every_12h'), '4'], [_('once_a_day'), '5'], [_('once_a_week'), '6'],
        [_('once_a_month'), '7']
    ]
  end

  def self.exchange_user_to_reseller_calls_table
    if Confline.get_value2("Calls_table_fixed", 0).to_i == 0
      sql = "UPDATE calls SET partner_price = user_price;"
      ActiveRecord::Base.connection.update(sql)
      sql = "UPDATE calls SET user_price = reseller_price;"
      ActiveRecord::Base.connection.update(sql)
      sql = "UPDATE calls SET reseller_price = partner_price;"
      ActiveRecord::Base.connection.update(sql)
      sql = "UPDATE calls SET partner_price = NULL"
      ActiveRecord::Base.connection.update(sql)

      Confline.set_value2("Calls_table_fixed", 1, 0)
      updated = true
    else
      updated = false
    end

    return updated
  end

  def self.get_device_range_values
    ran_min = Confline.get_value("Device_Range_MIN").to_i
    ran_max = Confline.get_value("Device_Range_MAX").to_i

    return ran_min, ran_max
  end

  def self.get_exeption_values
    exception_class_previous = Confline.get_value("Last_Crash_Exception_Class", 0).to_s
    exception_send_email = Confline.get_value("Exception_Send_Email").to_i

    return exception_class_previous, exception_send_email
  end

  def self.get_erp_values(cor_id)
    erp_domain = Confline.get_value("ERP_domain", cor_id)
    erp_login = Confline.get_value("ERP_login", cor_id)
    erp_password = Confline.get_value("ERP_password", cor_id)

    return erp_domain, erp_login, erp_password
  end

  def self.additional_modules_save_assign(params)
    Confline.set_value('AD_sounds_path', params['AD_sounds_path'])
    Confline.set_value('AD_Active', params['AD_Active'])
    Confline.set_value('CC_Active', params['CC_Active'])
    Confline.set_value('RS_Active', params['RS_Active'])
    Confline.set_value('RSPRO_Active', (params['RS_Active'].to_i == 1 ? params['RSPRO_Active'] : 0))
    Confline.set_value('SMS_Active', params['SMS_Active'])
    Confline.set_value('REC_Active', params['REC_Active'])
    Confline.set_value('PG_Active', params['PG_Active'])
    Confline.set_value('MA_Active', params['MA_Active'])
    Confline.set_value('CS_Active', params['CS_Active'])
    Confline.set_value('PROVB_Active', params['PROVB_Active'])
    Confline.set_value('AST_18', params['AST_18'])
    Confline.set_value('WP_Active', params['WP_Active'])
    Confline.set_value('CALLB_Active', params['CALLB_Active'])
    Confline.set_value('CC_Single_Login', (params['CC_Active'].to_i == 1 ? params['CC_Single_Login'] : 0))
    Confline.set_value('PBX_Active', params['PBX_Active'])

    ccl = params[:CCL_Active].to_i
    ccl_old = Confline.get_value("CCL_Active").to_i
    first_srv = Server.first.id
    def_asterisk = Confline.get_value("Default_asterisk_server").to_s
    reseller_server = Confline.get_value('Resellers_server_id').to_s
    resellers_devices = Device.joins("LEFT JOIN users ON (devices.user_id = users.id)")
    .where("(users.owner_id !=0 or usertype = 'reseller') AND users.hidden = 0").all

    if def_asterisk.to_i == 0
      def_asterisk = first_srv
    end

    return ccl, ccl_old, first_srv, def_asterisk, reseller_server, resellers_devices
  end

  # sd - ServerDevices
  # sp - ServerProviders
  def self.additional_modules_save_no_ccl(ccl, sd, sp, resellers_devices, def_asterisk, reseller_server)
    p_srv_id = Server.where(:server_type => 'sip_proxy').first.id.to_s rescue nil
    if !p_srv_id.blank?
      Server.delete_all(:server_type => "sip_proxy")
      Device.delete_all(:name => "mor_server_" + p_srv_id.to_s)
    end

    # CCL off - All devices with more than 1 server (or is a sip+dynamic combo) gets assigned to default asterisk server, duplicates removed.
    dups = []
    sd.each do |s|
      dup_count = ServerDevice.where(:device_id => s.device_id.to_s).size.to_i
      dev = Device.where(:id => s.device_id.to_s).first

      if dev.device_type.to_s == 'SIP' && dev.proxy_port.to_i == 0 && dev.name.include?('ipauth')
        dev.proxy_port = Device::DefaultPort['SIP']
        dev.save(:validate => false)
      end

      dev_prov = Provider.where(device_id: s.device_id).first
      if dev_prov.present? && dev_prov.tech == 'SIP'
        ServerDevice.destroy_all(device_id: s.device_id)
      end

      if dups.include?(s.device_id)
        s.delete
      elsif (dup_count > 1 && (dev_prov.nil? || (dev_prov.present? && dev_prov.tech == 'SIP'))) || dev.device_type.to_s == 'SIP'
        if resellers_devices.include?(dev)
          s.server_id = reseller_server
        else
          s.server_id = def_asterisk.to_s
        end
        if s.save
          dups << s.device_id
        else
          serv_error = s.errors
        end
      end
      if (dev.server_id != s.server_id) || dev.device_type.to_s == 'SIP'
        if dev.device_type.to_s == 'SIP' && !dev.name.include?('ipauth')
          dev.insecure = 'no'
        end
        if dev.server != s.server
          dev.server = s.server
        end
        dev.save
      end
    end
    servers = Server.where(id: [sp.collect(&:server_id)]) if sp.present?
    sp.each do |p|
      prov = Provider.where("id = #{p.provider_id}").first
      prov_dev = Device.where("id = #{prov.device_id}").first
      if prov_dev.proxy_port == 0 && prov_dev.device_type == 'SIP'
        prov.port = prov_dev.port
        prov_dev.proxy_port = prov_dev.port
        prov_dev.insecure = '' if prov_dev.host == 'dynamic'
        prov_dev.save(:validate => false)
        prov.save(:validate => false)
      end
      if prov_dev.user_id != -1 && prov_dev.device_type == 'SIP'
        ServerDevice.create(server_id: servers.select {|s| s.id == p.server_id }.first.try(:id), device_id: prov_dev.id)
      end
    end

    Confline.set_value('CCL_Active', ccl.to_i)
  end

  def self.additional_modules_save_with_ccl(sd, sp, created_server, ccl)
    sd.each do |d|
      cur_dev = Device.where(:id => d.device_id.to_s).first
      if cur_dev && cur_dev.device_type.to_s == 'SIP'
        d.server_id = created_server.id
        if Provider.where(device_id: cur_dev.id).first.present?
          ServerDevice.destroy_all("device_id = #{cur_dev.id} and id != #{d.id}")
          sd.reject! {|sd| sd.device_id == cur_dev.id && sd.id != d.id }
        end
        d.save
        cur_dev.insecure  = 'port,invite'
        cur_dev.server_id = created_server.id
        cur_dev.save
      end
    end

    sp.each do |serv_prov|
      prov = Provider.where(id: serv_prov.provider_id).first
      prov_dev = prov.device
      if prov_dev
        prov_dev.insecure = 'port,invite'
        prov_dev.save
      end
      # correct connection between provider and server (proxy)
      #serv_prov.server_id = created_server.id
      #serv_prov.save
      # it seems that this relation should not be present when proxy is on, wondering why?
      # it seems provider-server relations are not inpacted by proxy CCL settings, only devices-servers are
    end

    Device.update_all("dtmfmode = 'rfc2833', encryption = 'no'", "device_type = 'SIP'")
    if Confline.get_value('Default_device_type').to_s == 'SIP'
      Confline.set_value('Default_device_dtmfmode', 'rfc2833')
    end

    Confline.set_value('CCL_Active', ccl.to_i)

    return sd
  end

  def self.get_logo_details(user_id)
    logo_picture = get_value('Logo_Picture', user_id)
    version = get_value('Version', user_id)
    copyright_title = get_value('Copyright_Title', user_id)
    return logo_picture, version, copyright_title
  end

  def self.reseller_can_use_admins_rates?
    get_value('Allow_Resellers_to_use_Admin_Tariffs').to_i == 1
  end

  def self.new_user_defaults(owner_id)
    default_country_id = self.get_value('Default_Country_ID').to_i
    user = self.get_default_object(User, owner_id)
    address = self.get_default_object(Address, owner_id)
    tax = self.get_default_object(Tax, owner_id)

    [user, address, tax, default_country_id]
  end
end
