# -*- encoding : utf-8 -*-
class EmailsController < ApplicationController
  require 'enumerator'
  require 'net/pop'
  include ApplicationHelper
  #require 'pop_ssl'
  BASE_DIR = "/tmp/attachements"
  layout "callc"

  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize, :except => [:email_callback]
  before_filter :find_email, :only => [:edit, :update, :show_emails, :list_users, :destroy, :send_emails, :send_emails_from_cc]
  before_filter :find_session_user, :only => [:edit, :update, :show_emails, :destroy]

  def index
    redirect_to :action => :list and return false
  end

  def new
    @page_title = _('New_email')
    @page_icon = "add.png"
    @help_link = 'http://wiki.kolmisoft.com/index.php/Email_variables'
    @email = Email.new
    #   @user = User.find(session[:user_id])
  end

  def create
    @page_title = _('New_email')
    @page_icon = "add.png"

    @email = Email.new(params[:email])
    @email.assign_attributes(date_created: Time.now, callcenter: session[:user_cc_agent], owner: current_user)
    if @email.save
      flash[:status] = _('Email_was_successfully_created')
      if session[:user_cc_agent].to_i != 1
        redirect_to :action => 'list'
      else
        redirect_to :action => 'emeils_callcenter'
      end
    else
      flash[:notice] = _('Email_was_not_created')
      render :new
    end
  end

=begin
 In before filter : @email, @user
=end

  def edit
    @help_link = 'http://wiki.kolmisoft.com/index.php/Email_variables'
    @page_title = _('Edit_email')+': ' + @email.name
    @page_icon = "edit.png"
    ['subject', 'body'].each { |attribute|
      @email.assign_attributes(attribute => to_utf(@email.send(attribute)).html_safe)
    }
  end

=begin
 In before filter : @email, @user
=end

  def update
    @user = User.where(:id => session[:user_id]).first
    unless @user
      flash[:notice] = _('User_was_not_found')
      render :controller => "callc", :action => 'main'
    end

    if @email.update_attributes(params[:email])
      @email.save
      flash[:status] = _('Email_was_successfully_updated')
      # redirect_to :action => 'list', :id => params[:id], :ccc=>@ccc
      if session[:user_cc_agent].to_i != 1
        redirect_to :action => 'list'
      else
        redirect_to :action => 'emeils_callcenter'
      end
    else
      flash[:notice] = _('Email_was_not_updated') + ": " + _("Wrong_email_variables") + " <a href='http://wiki.kolmisoft.com/index.php/Email_variables'>wiki</a>"
      render :action => 'edit', :id => params[:id], :ccc => @ccc
    end
  end

  def list
    @page_title = _('Emails')
    @page_icon = "email.png"

    @emails = Email.select('*').where(["owner_id= ? and (callcenter='0' or callcenter is null)", session[:user_id]]).joins("LEFT JOIN (SELECT data, data2, COUNT(*) as emails FROM actions WHERE action = 'email_sent' GROUP BY data2) as actions ON (emails.id = actions.data2)").all
    @email_sending_enabled = Confline.get_value("Email_Sending_Enabled", 0).to_i == 1
    if @emails.size.to_i == 0 and session[:usertype] == "reseller"
      user=User.find(session[:user_id])
      user.create_reseller_emails
      @emails = Email.where(["owner_id= ? and (callcenter='0' or callcenter is null)", session[:user_id]]).
                      joins("LEFT JOIN (SELECT data, data2, COUNT(*) as emails FROM actions WHERE action = 'email_sent' GROUP BY data2) as actions ON (emails.id = actions.data2)")
    end
  end

  def emeils_callcenter
    @page_title = _('Emails')
    @page_icon = "email.png"
    if session[:usertype].to_s != "admin"
      @emails = Email.where(["(owner_id= ? or owner_id='0') and callcenter='1'", session[:user_id]])
    else
      @emails = Email.where("callcenter='1'")
    end
    @email_sending_enabled = Confline.get_value("Email_Sending_Enabled", 0).to_i == 1
  end

=begin
 In before filter : @email, @user
=end

  def show_emails
    @page_title = _('show_emails')+": " + @email.name
    @page_icon = "email.png"
  end

=begin
 In before filter : @email
=end

  def list_users
    @page_title = _('Email_sent_to_users')+": " + @email.name
    @page_icon = "view.png"

    @page = 1
    @page = params[:page].to_i if params[:page] and params[:page].to_i > 0

    @total_pages = (Action.count(:conditions => ["data2 = ? AND action = 'email_sent'", params[:id]]).to_d / session[:items_per_page].to_d).ceil

    @actions = Action.where(["data2 = ? AND action = 'email_sent'", params[:id]]).
                      offset((@page-1)*session[:items_per_page]).
                      limit(session[:items_per_page]).all
  end

=begin
 In before filter : @email
=end

  def destroy
    @email.destroy
    flash[:status] = _('Email_deleted')
    if session[:user_cc_agent].to_i != 1
      redirect_to :action => 'list'
    else
      redirect_to :action => 'emeils_callcenter'
    end
  end

=begin
 In before filter : @email
=end

  def send_emails
    @page_title = _('Send_email') + ": " + @email.name
    @page_icon = "email_go.png"

    @email_sending_enabled = Confline.get_value("Email_Sending_Enabled", 0).to_i == 1

    if !@email_sending_enabled or @email.template != 0
      dont_be_so_smart
      redirect_to :controller => "emails", :action => "list" and return false
    end

    default = {
        :shu => 'true',
        :sbu => 'true'
    }

    @options = (( !session[:emails_send_user_list_opt]) ? default : session[:emails_send_user_list_opt])

    default.each { |key, value| @options[key] = params[key] if params[key] }

    @users = get_users_with_emails

    session[:emails_send_user_list_opt] = @options
    @user_id_max = User.find_by_sql("SELECT MAX(id) AS result FROM users")
    # find selected users and send email to them
    @users_list = []
    to_email = params[:to_be_sent]
    if to_email
      to_email.each do |user_id, do_it|
        if do_it == "yes"
          user = User.find(user_id)
          @users_list << user
        end
      end
      if @users_list.blank?
        flash[:notice] = _('no_users_selected')
        redirect_to :action => 'list'
      else
        send_all(@users_list, @email)
      end

      #sent email to users
    end

    if @users_list.size > 0
      redirect_to :action => 'list'
    end
  end

  def users_for_send_email
    default = {
        :shu => 'true',
        :sbu => 'true'
    }

    @options = (( !session[:emails_send_user_list_opt]) ? default : session[:emails_send_user_list_opt])

    default.each { |key, value| @options[key] = params[key] if params[key] }

    @users = get_users_with_emails

    @user_id_max = User.find_by_sql("SELECT MAX(id) AS result FROM users")

    session[:emails_send_user_list_opt] = @options
    render :layout=>false
  end

=begin
 In before filter : @email
=end

  def send_emails_from_cc
    @page_title = _('Send_email') + ": " + @email.name.to_s
    @page_icon = "email_go.png"

    @search_agent= params[:agent]
    @agents = User.where("call_center_agent=1")

    @clients = CcClient.whit_main_contact(@search_agent)


    @page = 1
    @page = params[:page].to_i if params[:page]

    @total_pages = (@clients.size.to_d / session[:items_per_page].to_d).ceil
    @all_clients = @clients
    @clients = []
    @a_number = []
    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_clients.size - 1 if iend > (@all_clients.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @clients << @all_clients[i]
    end

    # find selected users and send email to them
    @clients_list = []
    # my_debug params[:to_be_sent].to_yaml
    to_email = params[:to_be_sent]
    if to_email
      to_email.each do |client_id, do_it|
        if do_it == "yes"
          client = CcClient.whit_email(client_id)
          @clients_list << client
        end
      end

      #sent email to users
      send_all(@clients_list, @email)
    end

    if @clients_list.size > 0
      redirect_to :action => 'emeils_callcenter'
    end
  end

  def send_all(users, email)
    e =[]
    status = Email.send_email(email, users, Confline.get_value('Email_from', session[:user_id].to_i), 'send_all', {:owner => session[:user_id], })
    email_sent = _('Email_sent')
    if status.first == email_sent
      flash[:status] = email_sent
    else
      flash[:notice] = _('Something_is_wrong_please_consult_help_link')
      flash[:notice] += "<a id='exception_info_link' href='http://wiki.kolmisoft.com/index.php/Configuration_from_GUI#Emails' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' /></a>".html_safe
    end
  end

  #send_all

  def EmailsController::send_test(id)
    user = User.find(id)
    email = Email.where(["name = 'registration_confirmation_for_user' AND owner_id = ?", id]).first

    users = []
    users << user
    variables = Email.email_variables(user, nil, {:owner => id})

    # ticket #9050 - send test_email the same way invoices are sent
    #send_email(email, Confline.get_value("Email_from", id), users, variables)

    status = _('email_not_sent')
    if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
      smtp_server = Confline.get_value('Email_Smtp_Server', id).to_s.strip
      smtp_user = Confline.get_value('Email_Login', id).to_s.strip
      smtp_pass = Confline.get_value('Email_Password', id).to_s.strip
      smtp_port = Confline.get_value('Email_Port', id).to_s.strip

      from = Confline.get_value('Email_from', id).to_s
      to = variables[:user_email]
      email_body = nice_email_sent(email, variables)
      begin
        system_call = ApplicationController::send_email_dry(from.to_s, to.to_s, email_body, email.subject.to_s, '', "'#{smtp_server.to_s}:#{smtp_port.to_s}' -xu '#{smtp_user.to_s}' -xp '#{smtp_pass.to_s}'", email.format)

        if defined?(NO_EMAIL) and NO_EMAIL.to_i == 1
          #do nothing
        else
          a = system(system_call)
          status = _('Email_sent') if a
        end
      rescue
        return status
      end
    else
      status = _('Email_disabled')
    end

    return status
    # redirect_to :root and return false
  end

  def EmailsController::send_to_users_paypal_email(order)
    email = Email.where("name = 'calling_cards_data_to_paypal' AND owner_id = #{0}").first

    users = []
    users << order
    user_mail = order.email
    cards = order.cards

    admin = []
    adm = User.find(0)
    admin << adm

    admin_email = adm.email
    details = (ActionController::Base.new.render_to_string partial: 'emails/email_calling_cards_purchase', locals: {:cards => cards}).html_safe
    user = User.new({:usertype => 'user', :username => 'Card', :first_name => order.first_name, :last_name => order.last_name})
    varables = Email.email_variables(user, nil, {:cc_purchase_details => details}, {:user_email_card => order.email})
    EmailsController::send_email(email, admin_email, users, varables)
    MorLog.my_debug '_____________________________'
    MorLog.my_debug admin_email
    MorLog.my_debug user_mail
    MorLog.my_debug '_____________________________'
    EmailsController::send_email(email, user_mail, admin, {:cc_purchase_details => details})
  end

  def EmailsController::send_email(email, email_from, users, assigns = {})
    if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
      email_from.gsub!(' ', '_') #so nasty, but rails has a bug and doest send from_email if it has spaces in it
      status = Email.send_email(email, users, email_from, 'send_email', {:assigns => assigns, :owner => assigns[:owner], :api => assigns[:api]})
      status.uniq.each { |i| @e = i + '<br>' }
      return @e
    else
      return _('Email_disabled')
    end
  end


  def EmailsController::nice_email_sent(email, assigns = {})
    email_builder = ActionView::Base.new(nil, assigns)
    email_builder.render(
        :inline => EmailsController::nice_email_body(email.body),
        :locals => assigns
    ).gsub("'", "&#8216;")
  end

  def EmailsController::nice_email_body(email_body)
    p = email_body.gsub(/(<%=?\s*\S+\s*%>)/) { |s| s.gsub(/<%=/, '??!!@proc#@').gsub(/%>/, '??!!@proc#$') }
    p = p.gsub(/<%=|<%|%>/, '').gsub('??!!@proc#@', '<%=').gsub('??!!@proc#$', '%>')
    p.gsub(/(<%=?\s*\S+\s*%>)/) { |s| s if Email::ALLOWED_VARIABLES.include?(s.match(/<%=?\s*(\S+)\s*%>/)[1]) }
  end

  def EmailsController::send_invoices(email, to, from, files = [], number = 0)

     smtp_server = Confline.get_value('Email_Smtp_Server', email[:owner_id].to_i).to_s.strip
     smtp_user = Confline.get_value('Email_Login', email[:owner_id].to_i).to_s.strip
     smtp_pass = Confline.get_value('Email_Password', email[:owner_id].to_i).to_s.strip
     smtp_port = Confline.get_value('Email_Port', email[:owner_id].to_i).to_s.strip

     smtp_connection =  "'#{smtp_server.to_s}:#{smtp_port.to_s}'"
     smtp_connection << " -xu '#{smtp_user}' -xp '#{smtp_pass}'" if smtp_user.present?

     filename_number = validate_filename(number)

     begin
	     files.each do |file|
	       File.open('/home/mor/tmp/' + filename_number + '_' + file[:filename].to_s.gsub(' ','_'), 'wb') {|f| f.write(file[:file]) }
	     end

	     filenames = files.map { |file| "'/home/mor/tmp/" + filename_number + "_" + file[:filename].to_s.gsub(' ','_') + "'" }.join(" ").to_s
       system_call = ApplicationController::send_email_dry(from.to_s, to.to_s, email.body.to_s, email.subject.to_s, "-a #{filenames}", smtp_connection, email.format)

       if defined?(NO_EMAIL) and NO_EMAIL.to_i == 1
          #do nothing
       else
          sending = system(system_call)
       end

	     files.each do |file|
          File.delete("/home/mor/tmp/" + filename_number + "_" + file[:filename].to_s.gsub(" ","_"))
	     end
     rescue
       return false
     end
    return "true" if sending
  end

  def email_pop3_cronjob
    pop3_server = Confline.get_value("SMS_Email_pop3_Server")
    login = Confline.get_value("SMS_Email_Login")
    psw = Confline.get_value("SMS_Email_Password")

    sql = "SELECT sms_messages.*, sms_providers.*, sms_messages.id as 'sms_id' FROM sms_messages
         LEFT JOIN sms_providers on (sms_providers.id = sms_messages.provider_id)
         WHERE sms_providers.provider_type = 'sms_email' AND  sms_messages.status_code = '0'"
    res = ActiveRecord::Base.connection.select_all(sql)

    gres = []

    gres = Email.email_pop3_cronjob_creates(res, gres)

    Net::POP3.enable_ssl(OpenSSL::SSL::VERIFY_NONE)
    Net::POP3.start(pop3_server, Net::POP3.default_pop3s_port, login, psw) do |pop|
      if pop.mails.empty?
        a= 'No mail.'
        #     my_debug a
      else
        pop.each_mail do |email|
          msg = email.pop
          Email.email_pop3_cronjob(gres, msg)
          email.delete
        end

      end

    end
    redirect_to :controller => "emails", :action => "list" and return false
  end


  def email_callback
    if callback_active?
      if params[:subject].to_s.downcase == 'change'
        old_callerid = params[:param1].to_s
        new_callerid = params[:param2].to_s
        Callerid.set_callback_from_emails(old_callerid, new_callerid)
      end

      if params[:subject].to_s.downcase == 'callback'
        auth_callerid = params[:param1].to_s.gsub(/[^0-9]/, "")
        first_number = params[:param2].to_s.gsub(/[^0-9]/, "")
        second_number = params[:param3].to_s.gsub(/[^0-9]/, "")

        my_debug params.to_yaml

        auth_dev_callerid = Callerid.where("cli = '#{auth_callerid}'").first
        if auth_dev_callerid and auth_dev_callerid.email_callback.to_i == 1

          MorLog.my_debug "email2callback by #{auth_callerid} authenticated."
          #Initiating callback between #{ first_number} and #{second_number}"

          if first_number.to_i > 0 and second_number.to_i > 0

            device = Device.where("id = #{auth_dev_callerid.device_id}").first

            if device

              st = originate_call(device.id, first_number, "Local/#{first_number}@mor_cb_src/n", "mor_cb_dst", second_number, device.callerid)

              if st.to_i == 0
                MorLog.my_debug "email callback - originating callback to '#{first_number}' and '#{second_number}'"
                Action.add_action_second(0, "email_callback_originate", "done", "originating callback to '#{first_number}' and '#{second_number}'")
              else
                MorLog.my_debug "#{_('Cannot_connect_to_asterisk_server')} :: email callback - originating callback to '#{first_number}' and '#{second_number}'"
                Action.add_action_second(0, "email_callback_originate", _('Cannot_connect_to_asterisk_server'), "originating callback to '#{first_number}' and '#{second_number}'")
              end
            else
              MorLog.my_debug "email2callback error - auth. device not found"
              Action.add_action_second(0, "email_callback_originate", "error", "auth. device not found, '#{first_number}' - '#{second_number}'")
            end

          else
            MorLog.my_debug "email2callback can't be initiated because bad numbers '#{first_number}' and/or '#{second_number}'"
            Action.add_action_second(0, "email_callback_originate", "error", "can't be initiated because bad numbers '#{first_number}' and/or '#{second_number}'")
          end

        else
          MorLog.my_debug "email2callback fail by auth_callerid: #{auth_callerid}"
          Action.add_action_second(0, "email_callback_originate", "error", "fail by auth_callerid: #{auth_callerid}, dst: '#{second_number}'")
        end

      end


      if params[:subject].to_s.downcase != 'callback' and params[:subject].to_s.downcase != 'change'
        MorLog.my_debug "ERROR, Subject is not correct , [#{params[:subject]}]"
        Action.add_action_second(0, "email_callback", "error - Unknown Action", "#{params[:subject]}")
      end
    else
      MorLog.my_debug "ERROR, Callback addon is disabled"
      Action.add_action_second(0, "email_callback", "error - Callback addon is disabled", '')
    end
  end


=begin rdoc
 Sends conmirmation email for user after registration.
=end

  def EmailsController.send_user_email_after_registration(user, device, password, reg_ip, free_ext)
    if Confline.get_value("Send_Email_To_User_After_Registration") == "1"
      #send mail to user with device details
      email = Email.where(["name = 'registration_confirmation_for_user' AND owner_id= ?", user.owner_id]).first
      users = [user]
      variables = Email.email_variables(user, device, {:login_password => password, :user_ip => reg_ip})
      num = EmailsController.send_email(email, Confline.get_value("Email_from", user.owner_id), users, variables)

      if num.to_s.gsub('<br>', '') == _('Email_sent')
        return 1, false
      else
        return 0, true
      end
    end
    return 0, false
  end


=begin rdoc
 Send mail to admin with registered user details
=end

  def EmailsController.send_admin_email_after_registration(user, device, password, reg_ip, free_ext, owner_id = 0)
    if Confline.get_value("Send_Email_To_Admin_After_Registration") == "1"
      #
      email = Email.where(["name = 'registration_confirmation_for_admin' AND owner_id= ?", owner_id]).first
      users = [User.where(:id => owner_id).first]
      variables = Email.email_variables(user, device, {:user_ip => reg_ip, :password => password, :free_ext => free_ext})
      num = EmailsController.send_email(email, Confline.get_value("Email_from", owner_id), users, variables)

      #      if num
      #        #flash[:notice] = _('EMAIL_SENDING_ERROR')
      #        action = Action.new
      #        action.user_id = user.id
      #        action.action = "error"
      #        action.date = Time.now
      #        action.data = 'Cant_send_email'
      #        action.data2 = num.to_s
      #        action.save
      #      end
    end
  end


  private

  def get_users_with_emails
    cond = []
    if @options[:shu].to_s == 'false'
      cond <<  'hidden = 0'
    end

    if @options[:sbu].to_s == 'false'
      cond <<  'blocked = 0'
    end

    condition = "#{cond.size.to_i >0 ? ' AND ' : ''} #{cond.join(' AND ')}"
    @users = User.includes(:address).where(["owner_id = ? AND addresses.email != '' AND addresses.id > 0 AND addresses.email IS NOT NULL #{condition}", session[:user_id]]).references(:address).all
  end

  def find_email
    @email = Email.where(:id => params[:id]).first
    unless @email
      flash[:notice] = _('Email_was_not_found')
      redirect_to :root and return false
    end
    check_user_for_email(@email)
  end

  def find_session_user
    @user = User.where(:id => session[:user_id]).first
    unless @user
      flash[:notice] = _('User_was_not_found')
      render :controller => "callc", :action => 'main'
    end
  end

  def check_user_for_email(email)
    if email.class.to_s =="Fixnum"
      email = Email.where(:id =>  email).first
    end
    if email.owner_id != session[:user_id]
      dont_be_so_smart
      redirect_to :controller => "emails", :action => "list" and return false
    end
    return true
  end

end
