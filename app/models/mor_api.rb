# -*- encoding : utf-8 -*-
class MorApi
  require 'builder/xmlbase'

  def MorApi.check_params_with_key(params, request)
    #hack find user from params u and p
    user = User.where(["username = ?", params[:u].to_s]).first

      ret = {}
      ret[:user_id] = params[:user_id].to_i if params[:user_id] and params[:user_id].to_s !~ /[^0-9]/ and params[:user_id].to_i >= 0
      ret[:request_hash] = params[:hash].to_s if params[:hash] and params[:hash].to_s.length == 40
      ret[:period_start] = params[:period_start].to_i if params[:period_start] and params[:period_start].to_s !~ /[^0-9]/
      ret[:period_end] = params[:period_end].to_i if params[:period_end] and params[:period_end].to_s !~ /[^0-9]/
      ret[:direction] = params[:direction].to_s if params[:direction] and (params[:direction].to_s == 'outgoing' or params[:direction].to_s == 'incoming')
      ret[:calltype] = params[:calltype].to_s if params[:calltype] and ['all', 'answered', 'busy', 'no_answer', 'failed', 'missed', 'missed_inc', 'missed_inc_all', 'missed_not_processed_inc'].include?(params[:calltype].to_s)
      ret[:device] = params[:device].to_s if params[:device] and (params[:device].to_s !~ /[^0-9]/ or params[:device].to_s == 'all')
      ret[:balance] = params[:balance] if params[:balance] and params[:balance].to_s !~ /[^0-9.\-\+]/
      ret[:users] = params[:users].to_s if params[:users] and (params[:users] =~ /^postpaid$|^prepaid$|^all$|^[0-9,]+$/)
      ret[:block] = params[:block].to_s if params[:block] and (params[:block] =~ /true|false/)
      ret[:email] = params[:email].to_s if params[:email] and (params[:email] =~ /true|false/)
      ret[:mtype] = params[:mtype].to_s if params[:mtype] and (params[:mtype] !~ /[^0-9]/)
      ret[:tariff_id] = params[:tariff_id].to_i if params[:tariff_id] and (params[:tariff_id].to_s !~ /[^0-9]/)
      ret[:only_did] = params[:only_did].to_i if params[:only_did] and (params[:only_did].to_s !~ /[^0-9]/)

      ret[:key] = Confline.get_value("API_Secret_Key", user ? user.get_correct_owner_id : 0).to_s
      string =
          ret[:user_id].to_s +
              ret[:period_start].to_s +
              ret[:period_end].to_s +
              ret[:direction].to_s+
              ret[:calltype].to_s+
              ret[:device].to_s+
              ret[:balance].to_s+
              ret[:users].to_s+
              ret[:block].to_s+
              ret[:email].to_s+
              ret[:mtype].to_s+
              ret[:key].to_s+
              ret[:callerid].to_s+
              ret[:pin].to_s

      ret[:system_hash] = Digest::SHA1.hexdigest(string)
      ret[:device] = nil if ret[:device] == 'all'
      ret[:calltype] = 'no answer' if ret[:calltype] == 'no_answer'
      ret[:balance] = params[:balance].to_d

    if Confline.get_value("API_Disable_hash_checking", user ? user.get_correct_owner_id : 0).to_i == 0
      unless ret[:system_hash].to_s == ret[:request_hash]
        MorApi.create_error_action(params, request, 'API : Incorrect hash')
      end
      return ret[:system_hash].to_s == ret[:request_hash], ret
    else
      return true, ret
    end
  end

  def MorApi.create_error_action(params, request, name)
    Action.create({:user_id => -1, :date => Time.now(), :action => 'error', :data => name, :data2 => (request ? request.url.to_s[0..255] : ''), :data3 => (request ? request.remote_addr : ''), :data4 => params.inspect.to_s[0..255]})
  end


  def MorApi.check_params_with_all_keys(params, request)
    #hack find user from params u and p
    user = User.where(["username = ?", params[:u].to_s]).first

    MorLog.my_debug params.to_yaml
    ret = {}
    ret[:user_id] = params[:user_id].to_i if params[:user_id] and params[:user_id].to_s !~ /[^0-9]/ and params[:user_id].to_i >= 0
    ret[:request_hash] = params[:hash].to_s if params[:hash] and params[:hash].to_s.length == 40
    ret[:period_start] = params[:period_start].to_i if params[:period_start] and params[:period_start].to_s !~ /[^0-9]/
    ret[:period_end] = params[:period_end].to_i if params[:period_end] and params[:period_end].to_s !~ /[^0-9]/
    ret[:direction] = params[:direction].to_s if params[:direction] and (params[:direction].to_s == 'outgoing' or params[:direction].to_s == 'incoming')
    ret[:calltype] = params[:calltype].to_s if params[:calltype] and ['all', 'answered', 'busy', 'no_answer', 'failed', 'missed', 'missed_inc', 'missed_inc_all', 'missed_not_processed_inc'].include?(params[:calltype].to_s)
    ret[:device] = params[:device].to_s if params[:device] and (params[:device].to_s !~ /[^0-9]/ or params[:device].to_s == 'all')
    ret[:balance] = params[:balance] if params[:balance] and params[:balance].to_s !~ /[^0-9.\-\+]/
    ret[:users] = params[:users].to_s if params[:users] and (params[:users] =~ /^postpaid$|^prepaid$|^all$|^[0-9,]+$/)
    ret[:block] = params[:block].to_s if params[:block] and (params[:block] =~ /true|false/)
    ret[:email] = params[:email].to_s if params[:email] #and (params[:email] =~ /true|false/)
    ret[:mtype] = params[:mtype].to_s if params[:mtype] and (params[:mtype] !~ /[^0-9]/)
    ret[:tariff_id] = params[:tariff_id].to_i if params[:tariff_id] and (params[:tariff_id].to_s !~ /[^0-9]/)
    ret[:only_did] = params[:only_did].to_i if params[:only_did] and (params[:only_did].to_s !~ /[^0-9]/)

    ['u0', 'u1', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7', 'u8', 'u9', 'u10', 'u11', 'u12', 'u13', 'u14', 'u15', 'u16', 'u17', 'u18', 'u19', 'u20', 'u21', 'u22', 'u23', 'u24', 'u25', 'u26', 'u27', 'u28',
     'ay', 'am', 'ad', 'by', 'bm', 'bd', 'pswd', 'user_warning_email_hour' 'pgui', 'pcsv', 'ppdf',
     'recording_forced_enabled', 'i4', 'tax4_enabled', 'tax2_enabled', 'accountant_type_invalid',
     'block_at_conditional', 'tax3_enabled', 'accountant_type', 'tax1_value', 'show_zero_calls',
     'warning_email_active', 'compound_tax', 'tax4_name', 'allow_loss_calls', 'tax3_name', 'tax2_name',
     'credit', 'tax1_name', 'total_tax_name', 'tax2_value', 'tax4_value',
     'i1', 'tax3_value', 'cyberplat_active', 'i2', 'i3', 'recording_enabled', 'email_warning_sent_test',
     'own_providers', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9', 'did', 'forward_to',
     'callflow_action', 'state', 'forward_to_device', 'external_number', 'did_id', 'device_callerid', 'src_callerid', 'custom', 'fax_device'].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }

    ret[:s_user] = params[:s_user] if params[:s_user] and params[:s_user].to_s !~ /[^0-9]/
    ret[:s_call_type] = params[:s_call_type] if params[:s_call_type]
    ret[:s_device] = params[:s_device] if params[:s_device] and (params[:s_device].to_s !~ /[^0-9]/ or params[:s_device].to_s == 'all')
    ret[:s_provider] = params[:s_provider] if params[:s_provider] and (params[:s_provider].to_s !~ /[^0-9]/ or params[:s_provider].to_s == 'all')
    ret[:s_hgc] = params[:s_hgc] if params[:s_hgc] and (params[:s_hgc].to_s !~ /[^0-9]/ or params[:s_hgc].to_s == 'all')
    ret[:s_did] = params[:s_did] if params[:s_did] and (params[:s_did].to_s !~ /[^0-9]/ or params[:s_did].to_s == 'all')

    ['s_destination', 'order_by', 'order_desc', 'description', 'pin', 'type', 'devicegroup_id', 'phonebook_id', 'name', 'speeddial'].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }

    if params[:action] != 'card_from_group_sell'
      ret[:number] = params[:number] if params[:number]
    end

    ret[:s_user_id] = params[:s_user_id] if params[:s_user_id] and params[:s_user_id].to_s !~ /[^0-9]/
    ret[:s_from] = params[:s_from] if params[:s_from] and params[:s_from].to_s !~ /[^0-9]/
    ret[:s_till] = params[:s_till] if params[:s_till] and params[:s_till].to_s !~ /[^0-9]/
    ret[:lcr_id] = params[:lcr_id].to_s if params[:lcr_id] and (params[:lcr_id].to_s !~ /[^0-9]/)
    ret[:dst] = params[:dst].to_s if params[:dst]
    ret[:src] = params[:src].to_s if params[:src]
    ret[:message] = params[:message].to_s if params[:message]
    ret[:caller_id] = params[:caller_id].to_s if params[:caller_id]
    ret[:device_id] = params[:device_id].to_s if params[:device_id]
    ret[:provider_id] = params[:provider_id].to_s if params[:provider_id]

    ['s_transaction', 's_completed', 's_username', 's_first_name', 's_last_name', 's_paymenttype', 's_amount_max', 's_currency', 's_number', 's_pin',
     'p_currency', 'paymenttype', 'tax_in_amount', 'amount', 'transaction', 'payer_email', 'shipped_at', 'fee', 'id', 'quantity', 'callerid', 'cardgroup_id',
     'status', 'date_from', 'date_till', 's_reseller_did', 's_did_pattern', 'lcr_id', 'dst', 'src', 'message', 'caller_id', 'device_id',
     'device_location_id', 'location_id'].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }

    # adding send email params
    ["server_ip", "device_type", "device_username", "device_password", "login_url", "login_username", "username", "first_name",
     "last_name", "full_name", "nice_balance", "warning_email_balance", "nice_warning_email_balance",
     "currency", "user_email", "company_email", "company", "primary_device_pin", "login_password", "user_ip",
     "date", "auth_code", "transaction_id", "customer_name", "company_name", "url", "trans_id",
     "cc_purchase_details", "payment_amount", "payment_payer_first_name",
     "payment_payer_last_name", "payment_payer_email", "payment_seller_email", "payment_receiver_email", "payment_date", "payment_free",
     "payment_currency", "payment_type", "payment_fee", "call_list", 'email_name', 'email_to_user_id', 'caller_id', 'device_id', "calldate", "source", "destination", "billsec", 'calls_string', 'cli_number'].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }

    ret[:key] = Confline.get_value("API_Secret_Key", user ? user.get_correct_owner_id : 0).to_s
    #for future: notice - users should generate hash in same order.
    string = ""

    hash_param_order = ['user_id', 'period_start', 'period_end', 'direction', 'calltype', 'device', 'balance', 'users',
      'block', 'email', 'mtype', 'tariff_id', 'u0', 'u1', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7', 'u8', 'u9', 'u10', 'u11',
      'u12', 'u13', 'u14', 'u15', 'u16', 'u17', 'u18', 'u19', 'u20', 'u21', 'u22', 'u23', 'u24', 'u25', 'u26', 'u27',
      'u28', 'ay', 'am', 'ad', 'by', 'bm', 'bd', 'pswd', 'user_warning_email_hour', 'pgui', 'pcsv', 'ppdf',
      'recording_forced_enabled', 'i4', 'tax4_enabled', 'tax2_enabled', 'accountant_type_invalid',
      'block_at_conditional', 'tax3_enabled', 'accountant_type', 'tax1_value', 'show_zero_calls',
      'warning_email_active', 'compound_tax', 'tax4_name', 'allow_loss_calls', 'tax3_name', 'tax2_name', 'credit',
      'tax1_name', 'total_tax_name', 'tax2_value', 'tax4_value', 'i1', 'tax3_value', 'cyberplat_active', 'i2', 'i3',
      'recording_enabled', 'email_warning_sent_test', 'own_providers', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7',
      'a8', 'a9', 's_user', 's_call_type', 's_device', 's_provider', 's_hgc', 's_did', 's_destination', 'order_by',
      'order_desc', 'only_did', 'description', 'pin', 'type', 'devicegroup_id', 'phonebook_id', 'number', 'name',
      'speeddial', 's_user_id', 's_from', 'provider_id', 's_till', 's_transaction', 's_completed', 's_username',
      's_first_name', 's_last_name', 's_paymenttype', 's_amount_max', 's_currency', 's_number', 's_pin', 'p_currency',
      'paymenttype', 'tax_in_amount', 'amount', 'transaction', 'payer_email', 'fee', 'id', 'quantity', 'callerid',
      'cardgroup_id', 'status', 'date_from', 'date_till', 's_reseller_did', 's_did_pattern', 'lcr_id', 'dst', 'src',
      'message', "server_ip", "device_type", "device_username", "device_password", "login_url", "login_username",
      "username", "first_name", "last_name", "full_name", "nice_balance", "warning_email_balance",
      "nice_warning_email_balance", "currency", "user_email", "company_email", "company", "primary_device_pin",
      "login_password", "user_ip", "date", "auth_code", "transaction_id", "customer_name", "company_name", "url",
      "trans_id", "cc_purchase_details", "payment_amount", "payment_payer_first_name", "payment_payer_last_name",
      "payment_payer_email", "payment_seller_email", "payment_receiver_email", "payment_date", "payment_free",
      "payment_currency", "payment_type", "payment_fee", "call_list", 'email_name', 'email_to_user_id', 'caller_id',
      'device_id', "calldate", "source", "destination", "billsec", 'calls_string', 'did', 'forward_to',
      'callflow_action', 'state', 'forward_to_device', 'external_number', 'did_id', 'device_calerid', 'src_callerid',
      'custom', 'fax_device', 'device_location_id', 'location_id', 'cli_number']

    hash_param_order.each { |key|
      MorLog.my_debug key if ret[key.to_sym]
      string << ret[key.to_sym].to_s
    }

    #add key
    string << ret[:key].to_s

    ret[:system_hash] = Digest::SHA1.hexdigest(string) if ret[:key].to_s != ""
    ret[:device] = nil if ret[:device] == 'all'
    ret[:calltype] = 'no answer' if ret[:calltype] == 'no_answer'
    ret[:balance] = params[:balance].to_d

    if Confline.get_value("API_Disable_hash_checking", user ? user.get_correct_owner_id : 0).to_i == 0
      if ret[:key].to_s != ""
        if ret[:system_hash].to_s != ret[:request_hash]
          MorApi.create_error_action(params, request, 'API : Incorrect hash')
        end
      else
        MorApi.create_error_action(params, request, 'API : API must have Secret key')
      end

      return ret[:system_hash].to_s == ret[:request_hash], ret, hash_param_order
    else
      return true, ret, hash_param_order
    end
  end


=begin
  This is THE method to add error string to xml object.

  *Params*
  +string+ - error message
  +xml_object+ - xml object to return with error message.

  *Returns*
  +xml+
  or
  +xml object+
=end
  def MorApi.return_error(string, doc = nil)
    if doc
      doc.status { doc.error(string) }
      return doc
    else
      doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
      doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
      doc.status { doc.error(string) }
      return out_string
    end
  end

  def MorApi.list_device_content(doc, device)
    Device.content_columns.each do |column_object|
      column = column_object.name
      add_tag(doc, column, device[column].to_s)
    end
  end

  def MorApi.list_codecs(doc, device)
    device_codecs = device.codecs
    # lambda which checks if codecs are available for device
    active = lambda { |codec| codec if device_codecs.include?(codec) }

    # lambda that creates [audio/video] xml tag
    list = lambda do |codec_type|
      codecs =  device.codecs_order(codec_type).select(&active)
      # web browsers do not escape 'video' tag, so that it is necessary to change it to 'video_codecs'
      tag_name = codec_type + '_codecs'
      add_tag(doc, tag_name, codecs.map(&:name).join(', '))
    end

    doc.codecs{ ['audio', 'video'].each(&list) }
  end

  def MorApi.add_tag(doc, name, content)
    doc.tag!(name){
      doc.text!(content)
    }
  end


  def MorApi.loggin_output(doc, user)
    doc.action {
      doc.name("login")
      doc.status("ok")
      doc.user_id("#{user.id.to_s}")
      doc.status_message("Successfully logged in")
    }
    return doc
  end

  def MorApi.failed_loggin_output(doc, remote_address)
    doc.action {
      doc.name("login")
      doc.status("failed")
      if Action.disable_login_check(remote_address).to_i == 0
        doc.status_message("Please wait 10 seconds before trying to login again")
      else
        doc.status_message("Login failed")
      end
    }
    return doc
  end

  def MorApi.logout_output(doc)
    doc.action {
      doc.name("logout")
      doc.status("ok")
    }
    return doc
  end

  def MorApi.failed_logout_output(doc)
    doc.action {
      doc.name("logout")
      doc.status("failed")
    }
    return doc
  end

  def MorApi.error_fro_callback(params)
    username = params[:u].to_s
    user = User.where(:username => username).first

    if username.length <= 0 or !user
      return 'Not authenticated'
    else
      device = Device.where(:id => params[:device]).first
      if !params[:device] or !device or device.user_id != user.id
        return 'Bad device'
      elsif !params[:src] or params[:src].length <= 0
        return 'No source'
      end
      return nil
    end
  end

  def MorApi.find_legs(device, src)
    legA = Confline.get_value("Callback_legA_CID", 0)
    legB = Confline.get_value("Callback_legB_CID", 0)
    custom_legA = Confline.get_value2('Callback_legA_CID', 0)
    custom_legB = Confline.get_value2('Callback_legB_CID', 0)

    legA_cid = (legA == 'device' ? device.callerid_number : (legA == 'custom' ? custom_legA : src))
    legB_cid = (legB == 'device' ? device.callerid_number : (legB == 'custom' ? custom_legB : src))

    legA_cid = src if legA_cid.blank?
    legB_cid = src if legB_cid.blank?

    return legA_cid, legB_cid
  end

  def self.conflines_update_validation(params, user_id)
    errors = []

    default_user_quickforwards_rule_id = params[:default_user_quickforwards_rule_id]

    if default_user_quickforwards_rule_id.present?
      params[:default_user_quickforwards_rule_id] =
          {default_user_quickforwards_rule_id: default_user_quickforwards_rule_id, user_id: user_id}
    end

    params.each do |key, value|
      method_name = "conflines_update_validation_#{key.to_s}".to_sym
      errors << send(method_name, value) if respond_to? method_name
    end

    params[:default_user_quickforwards_rule_id] = default_user_quickforwards_rule_id

    return errors.compact
  end

  def self.conflines_update_update_values(params, user_id)
    if params[:allow_api].present?
      Confline.set_value('Allow_API', params[:allow_api].to_s, user_id)
    end

    if params[:api_secret_key].present?
      Confline.set_value('API_Secret_Key', params[:api_secret_key].to_s, user_id)
    end

    if params[:default_user_password_length].present?
      Confline.set_value('Default_User_password_length', params[:default_user_password_length].to_s, user_id)
    end

    if params[:default_user_credit].present?
      Confline.set_value('Default_User_credit', params[:default_user_credit].to_s.strip.sub(/[\,\.\;]/, '.'), user_id)
    end

    if params[:default_user_balance].present?
      Confline.set_value('Default_User_balance', params[:default_user_balance].to_s.strip.sub(/[\,\.\;]/, '.'), user_id)
    end

    if params[:default_user_postpaid].present?
      Confline.set_value('Default_User_postpaid', params[:default_user_postpaid].to_s, user_id)
    end

    if params[:default_user_allow_loss_calls].present?
      Confline.set_value('Default_User_allow_loss_calls', params[:default_user_allow_loss_calls].to_s, user_id)
    end

    if params[:default_user_call_limit].present?
      Confline.set_value('Default_User_call_limit', params[:default_user_call_limit].to_s, user_id)
    end

    if params[:default_user_recording_enabled].present?
      Confline.set_value('Default_User_recording_enabled', params[:default_user_recording_enabled].to_s, user_id)
    end

    if params[:default_user_recording_forced_enabled ].present?
      Confline.set_value('Default_User_recording_forced_enabled',
                         params[:default_user_recording_forced_enabled ].to_s, user_id)
    end

    if params[:default_device_call_limit].present?
      Confline.set_value('Default_device_call_limit', params[:default_device_call_limit].to_s, user_id)
    end

    if params[:default_user_time_zone].present?
      Confline.set_value('Default_User_time_zone', params[:default_user_time_zone].to_s.strip, user_id)
    end

    if params[:default_user_currency].present?
      params_currency = Currency.where(name: params[:default_user_currency].to_s.strip).first.try(:id)
      Confline.set_value('Default_User_currency_id', params_currency, user_id)
    end

    if params[:default_user_quickforwards_rule_id].present?
      params_quickforward = params[:default_user_quickforwards_rule_id].to_s.strip == '0' ? 0 :
          QuickforwardsRule.where(id: params[:default_user_quickforwards_rule_id].to_s.strip,
                                  user_id: user_id).first.try(:id)

      Confline.set_value('Default_User_quickforwards_rule_id', params_quickforward, user_id)
    end

    if params[:default_device_canreinvite].present?
      Confline.set_value('Default_device_canreinvite', params[:default_device_canreinvite].to_s.strip, user_id)
    end

    if params[:default_device_nat].present?
      Confline.set_value('Default_device_nat', params[:default_device_nat].to_s.strip, user_id)
    end

    if params[:default_device_qualify].present?
      Confline.set_value('Default_device_qualify', params[:default_device_qualify].to_s, user_id)
    end

    if params[:default_device_grace_time].present?
      Confline.set_value('Default_device_grace_time', params[:default_device_grace_time].to_s, user_id)
    end

    if params[:default_device_audio_codecs].present?
      params_codecs = params[:default_device_audio_codecs].to_s.strip.split(',')
      possible_codecs = Codec.where(codec_type: :audio).pluck(:name)

      params_codecs.delete_if { |codec_name| !possible_codecs.include?(codec_name) }
      if params_codecs.present?
        active_codecs = params_codecs.size.to_i

        params_codecs << possible_codecs.
            delete_if { |codec_name| params_codecs.include?(codec_name) }

        params_codecs.flatten!.each_with_index do |codec, index|
          Confline.set_value("Default_device_codec_#{codec}", index < active_codecs ? '1' : '0', user_id)
          Confline.set_value2("Default_device_codec_#{codec}", index, user_id)
        end
      end
    end

    if params[:default_device_video_codecs].present?
      params_codecs = params[:default_device_video_codecs].to_s.strip.split(',')
      possible_codecs = Codec.where(codec_type: :video).pluck(:name)

      params_codecs.delete_if { |codec_name| !possible_codecs.include?(codec_name) }
      if params_codecs.present?
        active_codecs = params_codecs.size.to_i

        params_codecs << possible_codecs.
            delete_if { |codec_name| params_codecs.include?(codec_name) }

        params_codecs.flatten!.each_with_index do |codec, index|
          Confline.set_value("Default_device_codec_#{codec}", index < active_codecs ? '1' : '0', user_id)
          Confline.set_value2("Default_device_codec_#{codec}", index, user_id)
        end
      end
    end
  end

  private

  def self.conflines_update_validation_allow_api(allow_api)
    'allow_api must be 0 or 1' unless /^[0-1]$/ === allow_api.to_s
  end

  def self.conflines_update_validation_api_secret_key(api_secret_key)
    'api_secret_key length must be higher than 5' unless api_secret_key.to_s.length >= 6
  end

  def self.conflines_update_validation_default_user_password_length(default_user_password_length)
    unless ((/^[0-9]+$/ === default_user_password_length.to_s) && (default_user_password_length.to_i.between?(6, 30)))
      'default_user_password_length must be between 6 and 30'
    end
  end

  def self.conflines_update_validation_default_user_credit(default_user_credit)
    unless /^([\d]+([\,\.\;][\d]+){0,1})|(-1)$/ === default_user_credit.to_s
      'default_user_credit must be positive number or -1 for infinity'
    end
  end

  def self.conflines_update_validation_default_user_balance(default_user_balance)
    unless /^-?[\d]+([\,\.\;][\d]+){0,1}$/ === default_user_balance.to_s
      'default_user_balance must be number'
    end
  end

  def self.conflines_update_validation_default_user_postpaid(default_user_postpaid)
    'default_user_postpaid must be 0 or 1' unless /^[0-1]$/ === default_user_postpaid.to_s
  end

  def self.conflines_update_validation_default_user_allow_loss_calls(default_user_allow_loss_calls)
    'default_user_allow_loss_calls must be 0 or 1' unless /^[0-1]$/ === default_user_allow_loss_calls.to_s
  end

  def self.conflines_update_validation_default_user_call_limit(default_user_call_limit)
    'default_user_credit must be positive integer' unless /^[0-9]+$/ === default_user_call_limit.to_s
  end

  def self.conflines_update_validation_default_user_recording_enabled(default_user_recording_enabled)
    'default_user_recording_enabled must be 0 or 1' unless /^[0-1]$/ === default_user_recording_enabled.to_s
  end

  def self.conflines_update_validation_default_user_recording_forced_enabled(default_user_recording_forced_enabled)
    unless /^[0-1]$/ === default_user_recording_forced_enabled.to_s
      'default_user_recording_forced_enabled  must be 0 or 1'
    end
  end

  def self.conflines_update_validation_default_device_call_limit(default_device_call_limit)
    'default_device_call_limit must be positive integer' unless /^[0-9]+$/ === default_device_call_limit.to_s
  end

  def self.conflines_update_validation_default_user_time_zone(default_user_time_zone)
    unless ActiveSupport::TimeZone.all.each_with_index.collect { |tz| tz.name.to_s }.
        include?(default_user_time_zone.to_s.strip)

      'default_user_time_zone name was not correct'
    end
  end

  def self.conflines_update_validation_default_user_currency(default_user_currency)
    params_currency = Currency.where(name: default_user_currency.to_s.strip).first.try(:id)

    'default_user_currency name was not correct' unless params_currency
  end

  def self.conflines_update_validation_default_user_quickforwards_rule_id(options)
    params_quickforward = options[:default_user_quickforwards_rule_id].to_s.strip == '0' ? 0 :
        QuickforwardsRule.where(id: options[:default_user_quickforwards_rule_id].to_s.strip,
                                user_id: options[:user_id]).first.try(:id)

    'default_user_quickforwards_rule_id was not found' unless params_quickforward
  end

  def self.conflines_update_validation_default_device_canreinvite(default_device_canreinvite)
    unless ['yes', 'no', 'nonat', 'update', 'update,nonat'].include?(default_device_canreinvite.to_s.strip)
      "default_device_canreinvite can only be one of the following: 'yes', 'no', 'nonat', 'update', 'update,nonat'"
    end
  end

  def self.conflines_update_validation_default_device_nat(default_device_nat)
    unless ['yes', 'no', 'force_rport', 'comedia'].include?(default_device_nat.to_s.strip)
      "default_device_nat can only be one of the following: 'yes', 'no', 'force_rport', 'comedia'"
    end
  end

  def self.conflines_update_validation_default_device_qualify(default_device_qualify)
    unless ((default_device_qualify.to_s == 'no') || (default_device_qualify.to_i >= 1000))
      "default_device_qualify can only be 'no' or >= 1000 integer"
    end
  end

  def self.conflines_update_validation_default_device_grace_time(default_device_grace_time)
    'default_device_grace_time must be positive integer' unless /^[0-9]+$/ === default_device_grace_time.to_s
  end
end
