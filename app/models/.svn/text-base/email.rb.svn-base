# -*- encoding : utf-8 -*-
class Email < ActiveRecord::Base

  attr_protected

  extend UniversalHelpers
  require 'enumerator'
  require 'net/pop'
  #require 'tmail'

  ALLOWED_VARIABLES = ["server_ip", "device_type", "device_username", "device_password", "login_url", "login_username", "username", "first_name",
                       "last_name", "full_name", "balance", "nice_balance", "warning_email_balance", "nice_warning_email_balance",
                       "currency", "user_email", "company_email", "email", "company", "primary_device_pin", "login_password", "user_ip",
                       "amount", "date", "auth_code", "transaction_id", "customer_name", "description", "company_name", "url", "trans_id", "email",
                       "cc_purchase_details", "payment_amount", "payment_payer_first_name",
                       "payment_payer_last_name", "payment_payer_email", "payment_seller_email", "payment_receiver_email", "payment_date", "payment_free",
                       "payment_currency", "payment_type", "payment_fee", "call_list", "user_id", "device_id", "caller_id", "calldate", "source", "destination", "billsec"
  ]

  belongs_to :owner, class_name: 'User'

  def destroy_everything
    #rate details
    for rd in self.ratedetails
      rd.destroy
    end

    #advanced rate details
    for ard in self.aratedetails
      ard.destroy
    end

    self.destroy
  end

  validate do |email|
    email.must_have_valid_variables
  end

  def Email.address_validation(addres)
    out = false
    if addres.match(/^[a-zA-Z0-9_\+-]+(\.[a-zA-Z0-9_\+-]+)*@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*\.([a-zA-Z0-9_]{2,15})$/)
      out = true
    end
    out
  end

  # PAY ATTENTION
  # variable names should differ because if you name variable 'a' all other variables will be replace by its content!! ! !
  def Email.email_variables(user, device = nil, variables = {}, options = {})
    nnd = options[:nice_number_digits].to_i if options[:nice_number_digits]
    nnd = Confline.get_value("Nice_Number_Digits") if !nnd
    nnd = 2 if !nnd or nnd == ""
    user = User.includes([:devices, :address]).where(["users.id = ?", user.to_i]).first if user.class != User
    device = user.primary_device if !device
    currency = Currency.find(1)
    user_currency_exchange_rate = Currency.where(name: user.currency.name.to_s).first.try(:exchange_rate).to_f
    user.usertype == "reseller" ? owner_id = user.id : owner_id = user.owner_id
    company_email = Confline.get_value("Company_Email", owner_id)
    opts = {
        :owner => user.owner_id.to_s,
        :server_ip => Confline.get_value("Asterisk_Server_IP").to_s,
        :device_type => "",
        :device_username => "",
        :device_password => "",
        :primary_device_pin => "",
        :login_url => Web_URL.to_s + Web_Dir.to_s,
        :login_username => user.username.to_s,
        :username => user.username.to_s,
        :login_password => "*****",
        :user_ip => "",
        :amount => "",
        :date => "",
        :auth_code => "",
        :transaction_id => "",
        :customer_name => "",
        :description => "",
        :first_name => user.first_name.to_s,
        :last_name => user.last_name.to_s,
        :full_name => nice_user(user),
        :balance => Email.nice_number(user.balance.to_f * user_currency_exchange_rate).to_s,
        :nice_balance => User.current ? Email.nice_number(user.balance * Currency.count_exchange_rate(User.current.currency.name, user.currency.name), {:nice_number_digits => nnd, :global_decimal => options[:global_decimal], :change_decimal => options[:change_decimal]}).to_s : user.currency.name,
        :warning_email_balance => user.warning_email_balance.to_s,
        :nice_warning_email_balance => Email.nice_number(user.warning_email_balance.to_s, {:nice_number_digits => nnd, :global_decimal => options[:global_decimal], :change_decimal => options[:change_decimal]}),
        :currency => user.currency.name,
        :user_email => options[:user_email_card] ? options[:user_email_card] : (user.address == nil ? '' : user.address.email),
        :cc_purchase_details => "",
        :company_email => company_email,
        :email => company_email,
        :company => Confline.get_value("Company", owner_id),
        :payment_amount => "",
        :payment_payer_first_name => "",
        :payment_payer_last_name => "",
        :payment_payer_email => "",
        :payment_seller_email => "",
        :payment_receiver_email => "",
        :payment_date => "",
        :payment_fee => "",
        :payment_currency => "",
        :payment_type => "",
        :user_id => "",
        :device_id => "",
        :caller_id => "" ,
        :calldate=>"",
        :source=>"",
        :destination=>"",
        :billsec=>""
    }
    if device
      opts = opts.merge({
                            :device_type => device.device_type.to_s,
                            :device_username => device.username.to_s,
                            :device_password => device.secret.to_s,
                            :primary_device_pin => device.pin.to_s
                        })
    end
    if variables[:payment] && variables[:payment_notification] && variables[:payment_type]
      opts = opts.merge({
                            :payment_amount => variables[:payment].amount,
                            :payment_payer_first_name => variables[:payment].first_name,
                            :payment_payer_last_name => variables[:payment].last_name,
                            :payment_payer_email => variables[:payment].payer_email,
                            :payment_seller_email => variables[:payment].user.owner.email,
                            :payment_receiver_email => (variables[:payment_notification].respond_to?(:account)) ? variables[:payment_notification].account : variables[:payment_notification].receiver_email,
                            :payment_date => variables[:payment].date_added,
                            :payment_fee => variables[:payment].fee,
                            :payment_currency => variables[:payment].currency,
                            :payment_type => variables[:payment_type]
                        })
    end
    opts = opts.merge(variables)
    return opts
  end

  def Email.map_variables_for_api(params)
    opts = {}
    ALLOWED_VARIABLES.each{ |var|
      opts[var.to_sym] = params[var.to_sym].to_s
    }
    return opts
  end

  def Email.nice_number(number, options = {})
    n = "0.00"
    if options[:nice_number_digits].to_i > 0
      n = sprintf("%0.#{options[:nice_number_digits]}f", number.to_d) if number
    else
      nn ||= Confline.get_value("Nice_Number_Digits").to_i
      nn = 2 if nn == 0
      n = sprintf("%0.#{nn}f", number.to_d) if number
    end
    if options[:change_decimal]
      n = n.gsub('.', options[:global_decimal])
    end
    n
  end

  def Email.send_email(email, email_to, email_from, action, options = {})
    user_owner_id = options[:owner].to_i
    User.exists_resellers_confline_settings(user_owner_id) if user_owner_id != 0

    sending_batch_size = Confline.get_value('Email_Batch_Size', user_owner_id).to_i
    sending_batch_size = 50 if sending_batch_size.to_i == 0

    #end
      options[:smtp_server], options[:smtp_user] = Confline.get_value('Email_Smtp_Server', user_owner_id).to_s.strip,
                                                   Confline.get_value('Email_Login', user_owner_id).to_s.strip
      options[:smtp_pass], options[:smtp_port]   = Confline.get_value('Email_Password', user_owner_id).to_s.strip,
                                                   Confline.get_value('Email_Port', user_owner_id).to_s.strip

    string = []
    options[:from] = email_from
    if defined?(NO_EMAIL) and NO_EMAIL.to_i == 1
      status = _('Email_sent')
      string << status
      return string
    end
    email_to.each_slice(sending_batch_size) { |users_slice|
      begin
        users_slice.each do |user|
          options[:email_to_address] = user.get_email_to_address

          if action == 'sms_email_sent'
            options[:email_to_address] = nil
          end

          if options[:email_to_address].present?
            tmail = Email.create_umail(user, action, email, options)
            status = system(tmail)
            options[:status] = status
            if status
              status = _('Email_sent')
            else
              if options[:api].to_i == 1
                status = _('Incorrect_Email_settings')
              else
                status = _('Something_is_wrong_please_consult_help_link')
                status += "<a id='exception_info_link' href='http://wiki.kolmisoft.com/index.php/Configuration_from_GUI#Emails' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' /></a>".html_safe
              end
            end
            Action.create_email_sending_action(user, action, email, options)
          else
            status = _('Emeil_is_empty')
            status += ' ' + user.first_name + ' ' + user.last_name if user.class.to_s == 'User'
          end
          string << status
        end
      end
    }
    return string
  end

  def Email.create_umail(user, type, email, options={})

    from, smtp_server, smtp_user, smtp_pass, smtp_port =  options[:from],
                                                          options[:smtp_server],
                                                          options[:smtp_user],
                                                          options[:smtp_pass],
                                                          options[:smtp_port]

    smtp_connection =  "'#{smtp_server.to_s}:#{smtp_port.to_s}'"
    smtp_connection << " -xu '#{smtp_user}' -xp '#{smtp_pass}'" if smtp_user.present?

    mail_subject = email.subject
    case type
    when 'sms_email_sent'
      email_body = EmailsController::nice_email_sent(email, {:body => options[:message]})
      subject = options[:to]
    when 'send_email'
      email_body = EmailsController::nice_email_sent(email, options[:assigns])
    when 'send_all'
      email_body = EmailsController::nice_email_sent(email, Email.email_variables(user))
    end

    tmail = ApplicationController::send_email_dry(from, options[:email_to_address], email_body + ' ', mail_subject, '', smtp_connection, email.format)

    tmail
  end

  def must_have_valid_variables
    body.scan(/<%=?(\s*\S+\s*)%>|<%[^=]?[0-9a-zA-Z +=]*%>/).flatten.each do |var|
      unless !var.blank? and ALLOWED_VARIABLES.include?(var.to_s.strip)
        errors.add(:body, 'invalid variable') # it is not translated because we do not print errors in the form!
        return false
      end
    end
  end

  def self.email_pop3_cronjob_creates(res, gres)
    for r in res
      time = r['sending_date'].to_time
      min = ((Time.now - time).to_i / 60)
      user = User.find(r['user_id'])
      ruser = User.find(r['reseller_id'])
      if min.to_i < r['sms_email_wait_time'].to_i
        gres << r
      else
        if r['time_out_charge_user'].to_i == 1
          #       my_debug "nuskaiciau uz per ilga laika"
          sms = SmsMessage.find(r['sms_id'])
          user = User.find(r['user_id'])
          ruser = User.find(r['reseller_id'])

          #       my_debug("userio_balansas : " + user.frozen_balance)
          #       my_debug("resellerio_balansas : " + ruser.frozen_balance)
          if ruser.id.to_i != 0
            user.frozen_balance = user.frozen_balance - r['user_price'].to_d
            user.save
          else
            user.frozen_balance = user.frozen_balance - r['user_price'].to_d
            user.save
            ruser.frozen_balance = ruser.frozen_balance - r['reseller_price'].to_d
            ruser.save
          end
          sms.status_code = 5
          sms.save
        else
          #       my_debug "grazinau uz per ilga laika"
          if ruser.id.to_i != 0
            user.balance = user.balance + r['user_price'].to_d
            user.frozen_balance = user.frozen_balance - r['user_price'].to_d
            user.save
          else
            user.balance = user.balance + r['user_price'].to_d
            user.frozen_balance = user.frozen_balance - r['user_price'].to_d
            user.save
            ruser.balance = ruser.balance + r['reseller_price'].to_d
            ruser.frozen_balance = ruser.frozen_balance - r['reseller_price'].to_d
            ruser.save
          end
          sms = SmsMessage.find(r['sms_id'])
          sms.status_code = 4
          sms.user_rate = 0
          sms.user_price = 0
          sms.reseller_rate = 0
          sms.reseller_price = 0
          sms.provider_rate = 0
          sms.provider_price = 0
          sms.save
        end
      end

    end

    return gres
  end

  def self.email_pop3_cronjob(gres, msg)
    for r in gres
      #================ no keywords ===============================
      if msg.match(r['number']) and msg.match(r['sms_provider_domain']) and (r['wait_for_bad_email'].to_i == 1 or r['wait_for_good_email'].to_i == 1)
        user = User.find(r['user_id'])
        #           my_debug("user : " + user.username)
        ruser = User.find(r['reseller_id'])
        #           my_debug("reseller : " + ruser.username)
        sms = SmsMessage.find(r['sms_id'])
        #           my_debug("user_balance : " + user.balance.to_s)
        #           my_debug("user_frozen_balance : " + user.frozen_balance.to_s)
        #           my_debug("resseller_balance : " + ruser.balance.to_s)
        #           my_debug("resseller_frozen_balance : " + ruser.frozen_balance.to_s)
        if  r['nan_keywords_charge_user'].to_i == 1
          #                my_debug "nan_keywords_charge_user"
          user_price = r['user_price'].to_d
          ruser_price = r['reseller_price'].to_d
          user_price_b = 0
          ruser_price_b = 0
          sms.status_code = 5
        else
          #                my_debug "nan_keywords_charge_user"
          user_price = r['user_price'].to_d
          ruser_price = r['reseller_price'].to_d
          user_price_b = r['user_price'].to_d
          ruser_price_b = r['user_price'].to_d
          sms.status_code = 4
        end

        if r['wait_for_bad_email'].to_i == 1 and msg.match(r['email_bad_keywords'])
          #                 my_debug "wait_for_bad_email"
          user_price = r['user_price'].to_d
          ruser_price = r['reseller_price'].to_d
          user_price_b = r['user_price'].to_d
          ruser_price_b = r['user_price'].to_d
          sms.status_code = 4
        end

        if r['wait_for_good_email'].to_i == 1 and msg.match(r['email_good_keywords'])
          #                 my_debug "wait_for_good_email"
          user_price = r['user_price'].to_d
          ruser_price = r['reseller_price'].to_d
          user_price_b = 0
          ruser_price_b = 0
          sms.status_code = 5
        end
        #            my_debug "--------------VEIKSMAI------------------"
        if user.owner_id.to_i == 0
          #                  my_debug(user.balance.to_s+ " + " + user_price_b.to_s)
          user.balance = user.balance + user_price_b
          #                  my_debug(user.frozen_balance.to_s+ " - " + user_price.to_s)
          user.frozen_balance = user.frozen_balance - user_price
          user.save
        else
          #                my_debug(user.balance.to_s+ " + " + user_price_b.to_s)
          user.balance = user.balance + user_price_b
          #               my_debug(user.frozen_balance.to_s+ " - " + user_price.to_s)
          user.frozen_balance = user.frozen_balance - user_price
          #               my_debug(ruser.balance.to_s+ " + " + ruser_price_b.to_s)
          ruser.balance = ruser.balance + ruser_price_b
          #               my_debug(ruser.frozen_balance.to_s+ " - " + ruser_price.to_s)
          ruser.frozen_balance = ruser.frozen_balance - ruser_price
          user.save
          ruser.save
        end
        sms.save
        #           my_debug "---------------------------------------"
        #           my_debug "po "
        #           my_debug("user_balance : " + user.balance.to_s)
        #           my_debug("user_frozen_balance : " + user.frozen_balance.to_s)
        #           my_debug("resseller_balance : " + ruser.balance.to_s)
        #           my_debug("resseller_frozen_balance : " + ruser.frozen_balance.to_s)
        #           my_debug "*****************************************************************"
      end

    end
  end
end
