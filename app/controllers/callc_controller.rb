# -*- encoding : utf-8 -*-
class CallcController < ApplicationController

  #require 'rami'
  require 'digest/sha1'
  #require 'enumerator'
  include ApplicationHelper

  layout :mobile_standard

  before_filter :check_localization, :except => [:pay_subscriptions, :monthly_actions]
  before_filter :authorize, :except => [:login, :try_to_login, :pay_subscriptions, :monthly_actions, :forgot_password]
  before_filter :find_registration_owner, :only => [:signup_start, :signup_end]
  skip_before_filter :redirect_callshop_manager, :only => [:logout]
  before_filter :check_users_count, :only => [:signup_start, :signup_end]

  @@monthly_action_cooldown = 2.hours
  @@daily_action_cooldown = 2.hours
  @@hourly_action_cooldown = 20.minutes

  def index
    if session[:usertype]
      redirect_to :action => 'login' and return false
    else
      redirect_to :action => 'logout' and return false
    end
  end

  def login
    @show_login  = params[:shl].to_s.to_i
    @u = params[:u].to_s

    if params[:session_expired]
      flash[:notice] = _('session_expired')
    end

    @owner = params[:id] ? User.where(:uniquehash => params[:id]).first : User.where(:id => 0).first
    @owner_id, @defaulthash = @owner ? [@owner.id, @owner.get_hash] : [0, '']
    @allow_register = allow_register?(@owner)

    session[:login_id] = @owner_id

    flags_to_session(@owner)

    # do some house cleaning
    global_check

    if Confline.get_value('Show_logo_on_register_page', @owner_id).to_s == ''
      Confline.set_value('Show_logo_on_register_page', 1, @owner_id)
    end

    @page_title = _('Login')
    @page_icon = 'key.png'

    if session[:login] == true
      redirect_to :root and return false
    end

    set_time

    if Confline.get_value('Show_logo_on_register_page', @owner_id).to_i == 1
      session[:logo_picture], session[:version], session[:copyright_title] = Confline.get_logo_details(@owner_id)
    else
      session[:logo_picture], session[:version], session[:copyright_title] = [''] * 3
    end

    if request.env['HTTP_X_MOBILE_GATEWAY']
      respond_to do |format|
        format.wml { render 'login.wml.builder' }
      end
    end

  end

  def try_to_login

    #		my_debug Digest::SHA1.hexdigest('101')
    session[:layout_t] = params[:layout_t].to_s if params[:layout_t]
    unless params['login']
      dont_be_so_smart
      redirect_to :root and return false
    end

    @username = params['login']['username'].to_s
    @psw = params['login']['psw'].to_s
    @type = 'user'
    @login_ok = false
    @user = User.where(username: @username, password: Digest::SHA1.hexdigest(@psw)).first

    if @user.try(:owner)
      @login_ok = true
      renew_session(@user)
      store_url
    end

    session[:login] = @login_ok

    if @login_ok == true
      add_action(session[:user_id], "login", request.env["REMOTE_ADDR"].to_s)

      @user.mark_logged_in
      bad_psw = (params['login']['psw'].to_s == 'admin' and @user.id == 0) ? _('ATTENTION!_Please_change_admin_password_from_default_one_Press')+ " <a href='#{Web_Dir}/users/edit/0'> #{_('Here')} </a> " + _('to_do_this') : ''
      flash[:notice] = bad_psw if !bad_psw.blank?
      request_user_agent = request.env['HTTP_USER_AGENT']
      if (request_user_agent) && (request_user_agent.match('iPhone') || request_user_agent.match('iPod'))
        flash[:status] = _('login_successfully')
        redirect_to(action: 'main_for_pda') && (return false)
      else
        flash[:status] = _('login_successfully')
        if group = current_user.usergroups.includes(:group).where("usergroups.gusertype = 'manager' AND groups.grouptype = 'callshop'").references(:group).first and current_user.usertype != 'admin'
          session[:cs_group] = group
          session[:lang] = Translation.where(:id => group.group.translation_id).first.short_name
          redirect_to :controller => "callshop", :action => "show", :id => group.group_id and return false
        else
          redirect_to :root and return false
        end
      end
    else

      add_action_second(0, "bad_login", @username.to_s + "/" + @psw.to_s, request.env["REMOTE_ADDR"].to_s)

      us = User.where(:id => session[:login_id]).first
      u_hash = us ? us.uniquehash : ''
      flash[:notice] = _('bad_login')
      show_login = Action.disable_login_check(request.env["REMOTE_ADDR"].to_s).to_i == 0 ? 1 : 0
      redirect_to :action => "login", :id=>u_hash, :shl=>show_login, :u=>@username and return false
    end
  end

  def main_for_pda
    # my_debug session[:layout_t]
    @page_title = _('Start_page')
    @user = User.where(:id => session[:user_id]).first
    @username = @user.full_name
  end

  def logout
    add_action(session[:user_id], 'logout', '')

    user = User.where(:id => session[:user_id]).first
    if user
      user.mark_logged_out
      owner = user.owner
      user_id = user.id
    end
    owner ||= User.where(id: 0).first
    owner_id = owner.try(:id) || 0

    owner_id = user_id if user and reseller?

    session[:login] = false
    session.destroy

    flash[:notice] = _('logged_off')

    if Confline.get_value("Logout_link", owner_id).to_s.blank?
      if user.try(:is_reseller?)
        id = user.get_hash
      elsif owner.try(:get_hash)
        id = owner.get_hash
      end
      redirect_to action: 'login', id: id
    elsif user.try(:is_reseller?)
      redirect_to get_logout_link(user_id), id: user.get_hash
    else
      redirect_to get_logout_link(owner_id)
    end
  end

  def forgot_password
    email = to_utf(params[:email])
    if email and !email.blank?
      @r, @st = User.recover_password(email)

      flash[:notice_forgot] = @r.dup and @r.clear if @r.include?(_('Email_not_sent_because_bad_system_configurations'))
    end
    render layout: false
  end


  def main
    @show_currency_selector=1

    if not session[:user_id]
      redirect_to :action => "login" and return false
    end

    dont_be_so_smart if params[:dont_be_so_smart] == true

    @page_title = _('Start_page')
    session[:layout_t]="full"
    @user = User.includes(:tax).where(:id => session[:user_id]).first

    unless @user
      redirect_to action: 'logout' and return false
    end

    session[:integrity_check] = current_user.integrity_recheck_user
    session[:integrity_check] = Device.integrity_recheck_devices if session[:integrity_check].to_i == 0
    @username = nice_user(@user)

    if Confline.get_value('Hide_quick_stats').to_i == 0 and params.key? :refresh_stats
      show_quick_stats
    end

    if session[:usertype] == 'reseller'
      reseller = User.where(:id => session[:user_id]).first
      reseller.check_default_user_conflines
    end
    @show_gateways = (admin? or payment_gateway_active?) ? true : false

    @pp_enabled = session[:paypal_enabled]
    @wm_enabled = session[:webmoney_enabled]
    @vouch_enabled = session[:vouchers_enabled]
    @lp_enabled = session[:linkpoint_enabled]
    @cp_enabled = session[:cyberplat_enabled]

    @ob_enabled = session[:ouroboros_enabled]
    @ob_link_name = session[:ouroboros_name]
    @ob_link_url = session[:ouroboros_url]
    @ob_enabled = 0 if @user.owner_id > 0 # do not show for reseller users
    @addresses = Phonebook.where(:user_id => session[:user_id]).all

    @engine = ::GatewayEngine.find(:enabled, {:for_user => current_user.id}).enabled_by(current_user.owner_id)
    @enabled_engines = @engine.gateways

    if  request.env["HTTP_X_MOBILE_GATEWAY"]
      @notice = params[:sms_notice].to_s
      respond_to do |format|
        format.wml { render 'main.wml.builder' }
      end
    end
  end

  def show_quick_stats
    if Confline.get_value("Hide_quick_stats").to_i == 1
      @page_title = _('Quick_stats')
    end

    @ex = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    @user = User.includes(:tax).where(:id => session[:user_id]).first

    unless @user
      redirect_to :action => "logout" and return false
    end

    time_now = Time.now
    year = time_now.year.to_s
    month = time_now.month.to_s
    day = time_now.day.to_s

    month_t = year + '-' + good_date(month)
    last_day = last_day_of_month(year, good_date(month))
    day_t = year + '-' + good_date(month) + '-' + good_date(day)
    session[:callc_main_stats_options] ? options = session[:callc_main_stats_options] : options = {}
    show_from_db = !options[:time] || options[:time] < time_now ? 0 : 1

    if show_from_db == 0
      @quick_stats = @user.quick_stats(month_t, last_day, day_t)
      options[:quick_stats] = @quick_stats
      options[:time] = Time.now + 2.minutes
    else
      @quick_stats = options[:quick_stats]
    end

    session[:callc_main_stats_options] = options
  end

  def user_settings
    @user = User.where(:id => session[:user_id]).first
  end

  def ranks
    # today = Time.now.strftime("%Y-%m-%d")
    # today = "2006-07-26" #debug

    #counting month_normative for 1 user which was counted most time ago
    user = User.order("month_plan_updated ASC").first
    user.months_normative(Time.now.strftime("%Y-%m"))

    @users = User.where(:usertype => 'user', :show_in_realtime_stats => '1').all

    @h = Hash.new

    @total_billsec = 0;
    @total_calls = 0;
    @total_missed_not_processed = 0;
    @total_new_calls = 0;

    for user in @users

      @ranks_type = params[:id]

      if @ranks_type == "duration"
        calls_billsec = 0
        #          for call in user.calls("answered",today,today)
        #            calls_billsec += call.duration #billsec
        #          end

        calls_billsec = user.total_duration("answered", today, today) + user.total_duration("answered_inc", today, today)
        @h[user.id] = calls_billsec

        @total_billsec += calls_billsec
        @ranks_title = _('most_called_users')
        @ranks_col1 = _('time')
        @ranks_col2 = _('Calls')
      end

    end

    @a = @h.sort { |a, b| b[1]<=>a[1] }

    @b = []
    @c = []
    @d = []
    @e = [] #till normative
    @f = [] #class of normative
    @g = [] #percentage of normative
    @h = [] #new calls

    for a in @a

      if @ranks_type == "duration"
        user = User.where(:id => a[0]).first

        @b[a[0]] = user.total_calls("answered", today, today) + user.total_calls("answered_inc", today, today)
        #User.find(a[0]).calls("answered",today,today).size
        @d[a[0]] = user.total_calls("missed_not_processed", "2000-01-01", today)
        #User.find(a[0]).calls("missed_not_processed","2000-01-01",today).size
        @total_missed_not_processed += @d[a[0]]
        @total_calls += @b[a[0]]
        if @b[a[0]] != 0
          @c[a[0]] = a[1] / @b[a[0]]
        else
          @c[a[0]] = 0
        end

        #my_debug session[:time_to_call_per_day].to_i * 3600 - a[1]

        #@e[a[0]] = session[:time_to_call_per_day].to_d * 3600 - a[1]
        normative = user.calltime_normative.to_d * 3600
        @e[a[0]] = normative - a[1]
        @f[a[0]] = "red"


        if normative == 0
          @g[a[0]] = 0
        else
          @g[a[0]] = ((1 - (@e[a[0]] / normative)) * 100).to_i
        end

        # user has not started
        if  a[1] == 0
          @e[a[0]] = 0
          @f[a[0]] = "black"
        end

        # user has finished
        if @e[a[0]] < 0
          @e[a[0]] = a[1] - normative
          @f[a[0]] = "black"
        end

        @h[a[0]] = user.new_calls(Time.now.strftime("%Y-%m-%d")).size
        @total_new_calls += @h[a[0]]

      end
    end

    @avg_billsec = 0
    @avg_billsec = @total_billsec / @total_calls if @total_calls > 0

    render(:layout => false)
  end

  def show_ranks
    @page_title = _('Statistics')
    render(:layout => "layouts/realtime_stats")
  end

  def realtime_stats
    @page_title = _('Realtime')

    if params[:rt]
      if params[:rt][:calltime_per_day]
        session[:time_to_call_per_day] = params[:rt][:calltime_per_day]
      end
    else
      if !session[:time_to_call_per_day]
        session[:time_to_call_per_day] = 3.0
      end
    end

    @ttcpd = session[:time_to_call_per_day]
  end

  def global_settings
    @page_title = _('global_settings')
    cond = 'exten = ? AND context = ? AND priority IN (2, 3) AND appdata like ?'
    ext = Extline.where(cond, '_X.', 'mor', 'TIMEOUT(response)%').first
    @timeout_response = (ext ? ext.appdata.gsub('TIMEOUT(response)=', '').to_i : 20)
    ext = Extline.where(cond, '_X.', 'mor', 'TIMEOUT(digit)%').first
    @timeout_digit = (ext ? ext.appdata.gsub('TIMEOUT(digit)=', '').to_i : 10)
    @translations = Translation.order('position ASC').all
  end

  def global_settings_save
    Confline.set_value('Load_CSV_From_Remote_Mysql', params[:load_csv_from_remote_mysql].to_i, 0)
    redirect_to(action: 'global_settings') && (return false)
  end

  def reconfigure_globals
    @page_title = _('global_settings')
    @type = params[:type]

    if @type == 'devices'
      @devices = Device.where('user_id > 0').all
      for dev in @devices
        a = configure_extensions(dev.id, {:current_user => current_user})
        return false if !a
      end
    end

    if @type == 'outgoing_extensions'
      reconfigure_outgoing_extensions
    end
  end

  def global_change_timeout
    if Extline.update_timeout(params[:timeout_response].to_i, params[:timeout_digit].to_i)
      flash[:status] = _('Updated')
    else
      flash[:notice] = _('Invalid values')
    end
    redirect_to(action: 'global_settings') && (return false)
  end

  def global_change_fax_path_setup
    if Confline.set_value('Fax2Email_Folder', params[:fax2email_folder].to_s, 0)
      flash[:status] = _('Updated')
    else
      flash[:notice] = _('Invalid values')
    end
    redirect_to(action: 'global_settings') && (return false)
  end

  def global_set_tz
    if Confline.get_value('System_time_zone_ofset_changed').to_i == 0
      sql = "UPDATE users SET time_zone = '#{ActiveSupport::TimeZone[Time.now.utc_offset/3600].name}';"
      ActiveRecord::Base.connection.execute(sql)
      Confline.set_value('System_time_zone_ofset_changed', 1)
      flash[:status] = _('Time_zone_for_users_set_to') + " #{ActiveSupport::TimeZone[Time.now.utc_offset/3600].name} "
    else
      flash[:notice] = _('Global_Time_zone_set_replay_is_dont_allow')
    end
    redirect_to(action: 'global_settings') && (return false)
  end

  def set_tz_to_users
    users = User.all
    for u in users
      Time.zone = u.time_zone
      u.time_zone = ActiveSupport::TimeZone[Time.zone.now.utc_offset().hour.to_d + params[:add_time].to_d].name
      u.save
    end

    flash[:status] = _('Time_zone_for_users_add_value') + " + #{params[:add_time].to_d} "
    redirect_to action: 'global_settings' and return false
  end

  def signup_start
    @page_title = _('Sign_up')
    @page_icon = 'signup.png'
    @countries = Direction.order('name ASC').all

    @agreement = Confline.get('Registration_Agreement', @owner.id)

    Confline.load_recaptcha_settings

    if Confline.get_value('reCAPTCHA_enabled').to_i == 1
      configs = Recaptcha.configuration
      unless RecaptchaVerificator.verify_keys(configs.public_key, configs.private_key)
        flash[:notice] = _('configuration_error_contact_system_admin')
        redirect_to controller: 'callc', action: 'login' and return false
      end
    end

    if Confline.get_value('Show_logo_on_register_page', @owner.id).to_i == 1
      session[:logo_picture], session[:version], session[:copyright_title] = Confline.get_logo_details(@owner.id)
    end
    @vat_necessary = Confline.get_value("Registration_Enable_VAT_checking").to_i == 1 && Confline.get_value("Registration_allow_vat_blank").to_i == 0
  end

  def signup_end
    @page_title = _('Sign_up')
    @page_icon = 'signup.png'

    #error checking
    keys = [
      :username,
      :password,
      :password2,
      :device_type,
      :first_name,
      :last_name,
      :client_id,
      :vat_number,
      :address,
      :postcode,
      :city,
      :county,
      :state,
      :country_id,
      :phone,
      :mob_phone,
      :fax,
      :email
    ]

    keys.each { |key| session["reg_#{key}".to_sym] = params[key] }
    reg_ip= request.remote_ip

    owner = User.where(:uniquehash => params[:id]).first

    if !params[:id] or !owner
      reset_session
      dont_be_so_smart
      redirect_to :action => "login" and return false
    end
    show_debug = true
    if show_debug
      File.open('/tmp/new_log.txt', 'a+') {|f| f.write("\n Start #{Time.now}") }
    end
    notice = User.validate_from_registration(params,owner.id)

    #checkin reseller users quantity
    if owner and (owner.usertype == 'reseller')
      limit_it = (User.where(owner_id: owner.id).count >= 2)
      if limit_it and (((owner.own_providers == 0) and not reseller_active?) or ((owner.own_providers == 1) and  not reseller_pro_active?))
        if owner.id == 0
          if reseller_pro_active?
            notice = _('resellers_pro_restriction')
          else
            notice = _('resellers_restriction')
          end
        else
          notice = _('reseller_users_restriction')
        end
      end
    end

    capt = true
    if Confline.get_value("reCAPTCHA_enabled").to_i == 1
      usern = User.new
      capt = verify_recaptcha(usern) ? true : (false; notice = _('Please_enter_captcha'))
    end
    if show_debug
      File.open('/tmp/new_log.txt', 'a+') {|f| f.write("\n End #{Time.now}") }
    end
    if capt and !notice or notice.blank?
      reset_session


      if Confline.get_value('Show_logo_on_register_page', @owner.id).to_i == 1
        session[:logo_picture], session[:version], session[:copyright_title] = Confline.get_logo_details(@owner.id)
      end
      @user, @send_email_to_user, @device, notice2 = User.create_from_registration(params, @owner, reg_ip, free_extension(), new_device_pin(), random_password(12), next_agreement_number)
      session[:reg_owner_id] = @user.owner_id
      unless notice2
        flash[:status] = _('Registration_successful')
        a = Thread.new { configure_extensions(@device.id, {:current_user => @owner}); ActiveRecord::Base.connection.close }
      else
        flash[:notice] = notice2
      end
    else
      flash[:notice] = notice
      redirect_to(action: 'signup_start', id: params[:id]) && (return false)
    end
  end
  #cronjob runs every hour
  # 0 * * * * wget -o /dev/null -O /dev/null http://localhost/billing/callc/hourly_actions

  def hourly_actions
    #    backups_hourly_cronjob
    if active_heartbeat_server
      periodic_action("hourly", @@hourly_action_cooldown) {
        # check/make auto backup
        #    bt = Thread.new {
        Backup.backups_hourly_cronjob(session[:user_id])
        # }
        # =========== send b warning email for users ==================================
        MorLog.my_debug("Starting checking for balance warning", 1)
        User.check_users_balance
        send_balance_warning
        MorLog.my_debug("Ended checking for balance warning", 1)

        if payment_gateway_active?
          if Confline.get_value("ideal_ideal_enabled").to_i == 1
            MorLog.my_debug("Starting iDeal check")
            payments = Payment.where(:paymenttype => "ideal_ideal", :completed => 0, :pending_reason => "waiting_response").all
            MorLog.my_debug("Found #{payments.size} waiting payments")
            # There m ay be possibe to do some caching if performance becomes an issue.
            if payments.size > 0
              payments.each { |payment|
                gateway = ::GatewayEngine.find(:first, {:engine => "ideal", :gateway => "ideal", :for_user => payment.user_id}).enabled_by(payment.owner_id).query ## this is cacheable
                success, message = gateway.check_response(payment)
                MorLog.my_debug("#{success ? "Done" : "Fail"} : #{message}")
              }
            end
            MorLog.my_debug("Ended iDeal check")
          end
        end
        # bt.join
        #======================== Cron actions =====================================
        CronAction.do_jobs
        #======================== System time ofset =====================================
        #sql = 'select HOUR(timediff(now(),convert_tz(now(),@@session.time_zone,\'+00:00\'))) as u;'
        #z = ActiveRecord::Base.connection.select_all(sql)[0]['u']
        #MorLog.my_debug("GET global time => #{z.to_yaml}", 1)
        #t = z.to_s.to_i
        #old_tz= Confline.get_value('System_time_zone_ofset')
        #if t.to_i != old_tz.to_i and Confline.get_value('System_time_zone_daylight_savings').to_i == 1
        # ========================== System time ofset update users ================================
        #diff = t.to_i - old_tz.to_i
        #sql = "UPDATE users SET time_zone = ((time_zone + #{diff.to_d}) % 24);;"
        #ActiveRecord::Base.connection.execute(sql)
        #MorLog.my_debug("System time ofset update users", 1)
        #end
        #Confline.set_value('System_time_zone_ofset', t.to_i, 0)
        #MorLog.my_debug("confline => #{Confline.get_value('System_time_zone_ofset')}", 1)
        #======================== Devices  =====================================
        check_devices_for_accountcode

        update_timezone_offsets
      }
    else
      MorLog.my_debug("Backup not made because this server has different IP than Heartbeat IP from Conflines")
    end
  end

  #cronjob runs every midnight
  # 0 0 * * * wget -o /dev/null -O /dev/null http://localhost/billing/callc/daily_actions
  def daily_actions

    if active_heartbeat_server  # to be sure to run this only once per day
      periodic_action("daily", @@daily_action_cooldown) {

        # =========== get Currency rates from yahoo.com =================
        update_currencies

        #============ delete old files ==================================
        delete_files_after_csv_import
        system("rm -f /tmp/get_tariff_*") #delete tariff export zip files

        # =========== block users if necessary ==========================
        block_users
        block_users_conditional

        # =========== pay subscriptions ====== ==========================
        @time = Time.now - 1.day
        pay_subscriptions(@time.year.to_i, @time.month.to_i, @time.day.to_i, "is_a_day")
      }
    end
  end

  #cronjob runs every 1st day of month
  # 0 * * * * wget -o /dev/null -O /dev/null http://localhost/billing/callc/monthly_actions

  def monthly_actions
    if active_heartbeat_server
      periodic_action("monthly", @@monthly_action_cooldown) {

        # --------- count/deduct subscriptions --------
        year = Time.now.year.to_i
        month = Time.now.month.to_i - 1

        if month == 0
          year -= 1
          month = 12
        end

        my_debug("Saving balances for users for: " +year.to_s + " " + month.to_s)
        save_user_balances(year, month)

        my_debug("Counting subscriptions for: " +year.to_s + " " + month.to_s)
        pay_subscriptions(year, month)
        # ----- end count/deduct subscriptions --------
      }
    end
  end

  def periodic_action(type, cooldown)
    db_time = Time.now.to_s(:db)
    MorLog.my_debug "#{db_time} - #{type} actions starting sleep"
    sleep(rand * 10)
    MorLog.my_debug "#{db_time} - #{type} actions starting sleep end"
    begin
      time_set = Time.parse(Confline.get_value("#{type}_actions_cooldown_time"))
    rescue ArgumentError
      time_set = Time.now - 1.year
    end
    current_time = Time.now
    unless time_set and time_set + cooldown > current_time
      Confline.set_value("#{type}_actions_cooldown_time", current_time.to_s(:db))
      MorLog.my_debug "#{type} actions starting"
      yield
      MorLog.my_debug "#{type} actions finished"
    else
      MorLog.my_debug("#{cooldown} has not passed since last run of #{type.upcase}_ACTIONS")
      render :text => "To fast."
    end
  end

  def pay_subscriptions_test
    if session[:usertype] == "admin" and !params[:year].blank? and !params[:month].blank?
      a = pay_subscriptions(params[:year], params[:month])
      return false if !a
    else
      render :text => "NO!"
    end
  end


  def test_pdf_generation
    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")

    # ---------- Company details ----------

    pdf.text(session[:company], {:left => 40, :size => 23})
    pdf.text(Confline.get_value("Invoice_Address1"), {:left => 40, :size => 12})
    pdf.text(Confline.get_value("Invoice_Address2"), {:left => 40, :size => 12})
    pdf.text(Confline.get_value("Invoice_Address3"), {:left => 40, :size => 12})
    pdf.text(Confline.get_value("Invoice_Address4"), {:left => 40, :size => 12})

    # ----------- Invoice details ----------

    pdf.fill_color('DCDCDC')
    pdf.draw_text(_('INVOICE'), {:at => [330, 700], :size => 26})
    pdf.fill_color('000000')
    pdf.draw_text(_('Date') + ": " + 'invoice.issue_date.to_s', {:at => [330, 685], :size => 12})
    pdf.draw_text(_('Invoice_number') + ": " + 'invoice.number.to_s', {:at => [330, 675], :size => 12})

    pdf.image(Actual_Dir+"/public/images/rails.png")
    pdf.text("Test Text : ąčęėįšųūž_йцукенгшщз")
    pdf.render

    flash[:status] = _('Pdf_test_pass')
    redirect_to :root and return false
  end

  def global_change_confline
    if params[:heartbeat_ip]
      Confline.set_value("Heartbeat_IP", params[:heartbeat_ip].to_s.strip)
      flash[:status] = "Heartbeat IP set"
    end
    redirect_to :action => :global_settings and return false
  end

  def additional_modules
    @page_title = _('Additional_modules')
  end

  def additional_modules_save
    ccl, ccl_old, first_srv, def_asterisk, reseller_server,
        @resellers_devices = Confline.additional_modules_save_assign(params)

    if ccl.to_s != ccl_old.to_s and params[:indirect].to_i == 1
      @sd = ServerDevice.all
      @sp = Serverprovider.all

      if ccl.to_i == 0
        # assign all fax/virtual devices to only one default asterisk server from carrier class setting
        assign_all_devices_to_one_asterisk

        Confline.additional_modules_save_no_ccl(ccl, @sd, @sp, @resellers_devices, def_asterisk, reseller_server)

        flash[:status] = _('Settings_saved')

        # removing session so that users couldn't use addons.
        Rails.cache.clear
        reset_session
        redirect_to :action => :additional_modules and return true
      elsif ccl.to_i == 1
        ip = params[:ip_address]
        host = params[:host]
        # assign all fax/virtual devices to all asterisk servers via server_devices table
        assign_all_devices_to_all_asterisk

        if ip.blank? or !check_ip_validity(ip) or not Server.where(server_ip: ip).count.zero?
          flash[:notice] = _('Incorrect_Server_IP')
          redirect_to :action => :additional_modules and return false
        elsif host.blank? or !check_hostname_validity(host) or not Server.where(hostname: host).count.zero?
          flash[:notice] = _('Incorrect_Host')
          redirect_to :action => :additional_modules and return false
        else
          old_id = Server.select("MAX(id) AS last_old_id").first.last_old_id rescue 0
          new_id = old_id.to_i + 1

          created_server = Server.new(:server_ip => ip, :hostname => host, :server_type => "sip_proxy", :comment => "SIP Proxy", :active => 0)
          if created_server.save and
              (Device.where(:name => "mor_server_" + new_id.to_s)
              .update_all(:nat => "yes", :allow => "alaw;g729;ulaw;g723;g726;gsm;ilbc;lpc10;speex;adpcm;slin;g722"))

            @sd = Confline.additional_modules_save_with_ccl(@sd, @sp, created_server, ccl)
          else
            created_server_errors_values = created_server.errors.values.first
            flash[:notice] = _(created_server_errors_values.first, "mor_server_#{created_server.id}") if created_server_errors_values
            redirect_to :action => :additional_modules and return false
          end
        end
      else
        flash[:notice] = _('additional_modules_fail')
        redirect_to :action => :additional_modules and return false
      end
    end

    # removing session so that users couldn't use addons.
    Rails.cache.clear
    reset_session

    flash[:status] = _('Settings_Saved')
    redirect_to :action => :additional_modules
  end

  # IP validation
  def check_ip_validity(ip=nil)
   regexp = /^\b(?![0.]*$)(?:25[0-5]|(?:2[0-4]|1\d|[1-9])?\d)(?:\.(?:25[0-5]|(?:2[0-4]|1\d|[1-9])?\d)){3}\b$/
   (regexp.match(ip) ? (return true) : (return false))
  end

  # Hostname validation
  def check_hostname_validity(hostname=nil)
    regexp = /(^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$)|(^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$)$/
    (regexp.match(hostname) ? (return true) : (return false))
  end

  private

  def assign_all_devices_to_all_asterisk
    asterisk_servers = Server.where(server_type: :asterisk).pluck(:id)
    all_devices = Device.where(device_type: [:fax, :virtual]).pluck(:id)

    asterisk_servers.each do |server_id|
      all_devices.each do |device_id|
        unless ServerDevice.where(server_id: server_id, device_id: device_id).first
          server_device = ServerDevice.new_relation(server_id, device_id)
          server_device.save
        end
      end
    end
  end

  def assign_all_devices_to_one_asterisk
    asterisk_server = Server.where(id: Confline.get_value('Default_asterisk_server').to_i).first.try(:id) ||
        Server.where(server_type: :asterisk).order(id: :asc).first.try(:id).to_i

    all_devices = Device.where(device_type: [:fax, :virtual])

    ServerDevice.where(device_id: all_devices).destroy_all
    all_devices.pluck(:id).each do |device_id|
      server_device = ServerDevice.new_relation(asterisk_server, device_id)
      server_device.save
    end
    all_devices.update_all(server_id: asterisk_server)
  end

  def check_devices_for_accountcode
    retry_lock_error(3) { ActiveRecord::Base.connection.execute('UPDATE devices set accountcode = id WHERE accountcode = 0;') }
  end

  # if Heartbeat IP is set, check if current server IP is same as Heartbeat IP
  def active_heartbeat_server
    heartbeat_ip = Confline.get_value('Heartbeat_IP').to_s
    # remote_ip = `/sbin/ifconfig | grep '#{heartbeat_ip} '`
    remote_ip = `ip -o -f inet addr show | grep "#{heartbeat_ip}/"`

    if !heartbeat_ip.blank? and remote_ip.to_s.length == 0
      render :text => "Heartbeat IP incorrect" and return false
    end

    return true
  end

  # saves users balances at the end of the month to use them in future in invoices to show users how much they owe to system owner
  def save_user_balances(year, month)

    @year = year.to_i
    @month = month.to_i

    date = "#{@year.to_s}-#{@month.to_s}"

    if months_between(Time.mktime(@year, @month, "01").to_date, Time.now.to_date) < 0
      render :text => "Date is in future" and return false
    end

    users = User.all

    # check all users for actions, if action not present - create new one and save users balance
    for user in users
      old_action = Action.where(:data => date, :user_id => user.id).first
      if not old_action
        MorLog.my_debug("Creating new action user_balance_at_month_end for user with id: #{user.id}, balance: #{user.raw_balance}")
        Action.add_action_hash(user, {action: 'user_balance_at_month_end', data: date, data2: user.raw_balance.to_s, data3: Currency.get_default.name})
      else
        MorLog.my_debug("Action user_balance_at_month_end for user with id: #{user.id} present already, balance: #{old_action.data2}")
      end
    end

  end


  def pay_subscriptions(year, month, day=nil, is_a_day=nil)
    email_body = []
    email_body_reseller = []
    doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)

    @year = year.to_i
    @month = month.to_i
    @day = day ? day.to_i : 1
    send = false

    if not day and months_between(Time.mktime(@year, @month, @day).to_date, Time.now.to_date) < 0
      render :text => "Date is in future" and return false
    end
    email_body << "Charging for subscriptions.\nDate: #{@year}-#{@month}\n"
    email_body_reseller << "========================================\nSubscriptions of Reseller's Users"

    @users = User.includes(:tax, :subscriptions).where('blocked != 1 AND subscriptions.id IS NOT NULL').references(:subscriptions).order('users.owner_id ASC').all
    generation_time = Time.now
    doc.subscriptions() {
      doc.year(@year)
      doc.month(@month)
      doc.day(@day) if day
      @users.each_with_index { |user, i|
        user_time = Time.now
        subscriptions = user.pay_subscriptions(@year, @month, day, is_a_day)
        if subscriptions.size > 0
          doc.user(:username => user.username, :user_id => user.id, :first_name => user.first_name, :balance => user.balance, :user_type => user.user_type) {
            send = true
            email_body << "#{i+1} User: #{nice_user(user)}(#{user.username}):"   if user.owner_id.to_i == 0
            email_body_reseller << "#{i+1} User: #{nice_user(user)}(#{user.username}):"     if user.owner_id.to_i != 0
            doc.blocked("true") if user.blocked.to_i == 1
            email_body << "  User was blocked." if user.blocked.to_i == 1  and user.owner_id.to_i == 0
            email_body_reseller <<   "  User was blocked." if user.blocked.to_i == 1 and user.owner_id.to_i != 0
            subscriptions.each { |sub_hash|
              email_body << "  Service: #{sub_hash[:subscription].service.name} - #{nice_number(sub_hash[:price])}"
              doc.subscription {
                doc.service(sub_hash[:subscription].service.name)
                doc.price(nice_number(sub_hash[:price]))
              }
            }
            email_body << ""  if user.owner_id.to_i == 0
            email_body_reseller <<  ""  if user.owner_id.to_i != 0
            doc.balance_left(nice_number(user.balance))
          }
        end

        logger.debug "User time: #{Time.now - user_time}"
      }
    }
    logger.debug("Generation took: #{Time.now - generation_time}")
    email_body +=  email_body_reseller if email_body_reseller and email_body_reseller.size.to_i > 0
    if send
      email_time = Time.now
      email = Email.new(:body => email_body.join("\n"), :subject => "subscriptions report", :format => "plain", :id => "subscriptions report")
      status = EmailsController::send_email(email, Confline.get_value("Email_from", 0), [User.where(:id => 0).first], {:owner => 0})
      out_string <<  '<br/>' + status
      logger.debug("Email took: #{Time.now - email_time}")
    end
    if session[:usertype] == "admin"
      render :xml => out_string.html_safe
    else
      render :text => ""
    end
  end

  def delete_files_after_csv_import
    MorLog.my_debug('delete_files_after_csv_import', 1)
    select = []
    select << "SELECT table_name"
    select << "FROM   INFORMATION_SCHEMA.TABLES"
    select << "WHERE  table_schema = 'mor' AND"
    select << "       table_name like 'import%' AND"
    select << "       create_time < ADDDATE(NOW(), INTERVAL -1 DAY);"
    tables = ActiveRecord::Base.connection.select_all(select.join(' '))
    if tables
      tables.each { |t|
        MorLog.my_debug("Found table : #{t['table_name']}", 1)
        Tariff.clean_after_import(t['table_name'])
      }
    end
  end


  def update_currencies
    begin
      Currency.transaction do
        my_debug('Trying to update currencies')
        notice = Currency.update_currency_rates
        if notice
          my_debug('Currencies updated')
        else
          my_debug("Currencies NOT updated. Yahoo closed the connection before the transaction was completed.")
        end
      end
    rescue => e
      my_debug(e)
      my_debug("Currencies NOT updated")
      return false
    end
  end

  def backups_hourly_cronjob
    redirect_to :controller => 'backups', :action => 'backups_hourly_cronjob'
  end

  def block_users
    date = Time.now.strftime("%Y-%m-%d")
    #my_debug date
    users = User.where(:block_at => date).all
    #my_debug users.size if users
    for user in users
      user.blocked = 1
      user.save
    end
    my_debug('Users for blocking checked')
  end

  def block_users_conditional
    day = Time.now.day
    #my_debug day
    users = User.where("block_at_conditional = '#{day}' AND balance < 0 AND postpaid = 1 AND block_conditional_use = '1'").all
    #my_debug users.size if users
    for user in users

      invoices = Invoice.where("user_id = #{user.id} AND paid = 0").count
      #my_debug "not paid invoices: #{invoices}"

      if invoices > 0
        user.blocked = 1
        user.save
      end

    end
    my_debug('Users for conditional blocking checked')
  end

  def send_balance_warning

    enable_debug = 1

    administrator = User.where(id: 0).first
    users = User.includes(:address).where("warning_email_active = 1 AND " +
                                            "((((warning_email_sent = 0) OR (warning_email_sent_admin = 0) OR (warning_email_sent_manager = 0)) " +
                                            "AND warning_email_hour = -1) " +
                                          "OR " +
                                            "(warning_email_hour != -1) " +
                                          ") AND ( " +
                                            "(balance < warning_email_balance) OR " +
                                            "(balance < warning_email_balance_admin) OR " +
                                            "(balance < warning_email_balance_manager) " +
                                          ")").references(:address).all
    if users.size.to_i > 0
      users.each do |user|
        email_to_address = user.get_email_to_address.to_s
        num = num_admin = num_manager = ''
        manager = User.where(id: user.responsible_accountant_id).first

        user_owner_admin = user.owner_id == 0

        email_hour = user.warning_email_hour
        user_current_time    = Time.now.in_time_zone(user.time_zone).hour
        admin_current_time   = Time.now.in_time_zone(administrator.time_zone).hour
        manager_current_time = manager ? Time.now.in_time_zone(manager.time_zone).hour : 0

        if enable_debug == 1 and (email_hour == user_current_time or
            email_hour == admin_current_time or email_hour == manager_current_time)
          MorLog.my_debug("Need to send warning_balance email to: #{user.id} #{user.username} #{email_to_address}")
        end
        email= Email.where(:name => 'warning_balance_email', :owner_id => user.owner_id).first
        local_user_email = Email.where(name: 'warning_balance_email_local', owner_id: 0).first
        unless email
          owner = user.owner
          if owner.usertype == "reseller"
            owner.check_reseller_emails
            email= Email.where(:name => 'warning_balance_email', :owner_id => user.owner_id).first
          end
        end
        variables = email_variables(user)
        admin_email = administrator.email.to_s

        begin
          email_from = Confline.get_value('Email_from', user.owner_id) .to_s
          email_sent_string = _('Email_sent')
          old_email_sent, old_email_sent_admin, old_email_sent_manager  = user.warning_email_sent,
                                                                          user.warning_email_sent_admin,
                                                                          user.warning_email_sent_manager

          if (user.balance < user.warning_email_balance and user.warning_email_sent.to_i != 1 and email_hour == -1) or
             (email_hour == user_current_time)
            variables[:user_email] = email_to_address
            num = send_balance_warning_email(email, email_from, user, variables)
          end

          if ((user.balance < user.warning_email_balance_admin and user.warning_email_sent_admin.to_i != 1 and email_hour == -1) or
              (email_hour == admin_current_time)) and user_owner_admin
            variables[:user_email] = admin_email
            num_admin = send_balance_warning_email(local_user_email, email_from, administrator, variables)
          end

          acc_email = manager.try(:email).to_s
          if manager.present? and user_owner_admin and (
            (user.balance < user.warning_email_balance_manager and user.warning_email_sent_manager.to_i != 1 and email_hour == -1) or
            (email_hour == manager_current_time))

            variables[:user_email] = acc_email
            num_manager = send_balance_warning_email(local_user_email, email_from, manager, variables)
          end

          if (num.to_s == email_sent_string)
            Action.add_action_hash(user.owner_id, {:action => 'warning_balance_send', :target_type => email_to_address, :target_id => user.id, :data => user.id, :data2 => email.id})
            if enable_debug == 1
              MorLog.my_debug("warning_balance_sent: #{user.id} #{user.username}, to user: #{email_to_address}")
            end
            user.warning_email_sent = 1
          end

          if (num_admin.to_s == email_sent_string) and user_owner_admin
            Action.add_action_hash(user.owner_id, {:action => 'warning_balance_send', :target_type => admin_email, :target_id => 0, :data => user.id, :data2 => email.id})
            if enable_debug == 1
              MorLog.my_debug("warning_balance_sent: #{user.id} #{user.username}, to admin: #{admin_email}")
            end
            user.warning_email_sent_admin = 1
          end

          if (num_manager.to_s == email_sent_string) and user_owner_admin
            acc_email = manager.email.to_s
            Action.add_action_hash(user.owner_id, {:action => 'warning_balance_send', :target_type => acc_email, :target_id => manager.id, :data => user.id, :data2 => email.id})
            if enable_debug == 1
              MorLog.my_debug("warning_balance_sent: #{user.id} #{user.username}, to manager: #{acc_email}")
            end
            user.warning_email_sent_manager = 1
          end
          user.save

          if enable_debug == 1
            email_not_sent_string = _('email_not_sent')
            if num.to_s == email_not_sent_string
              MorLog.my_debug("Email could not be sent for USER")
            end
            if num_admin.to_s == email_not_sent_string and user_owner_admin
              MorLog.my_debug("Email could not be sent for ADMIN")
            end
            if num_manager.to_s == email_not_sent_string and user_owner_admin
              MorLog.my_debug("Email could not be sent for MANAGER")
            end

            if email_hour == -1
              if old_email_sent == user.warning_email_sent and old_email_sent == 1
                MorLog.my_debug("Email was already sent to USER")
              end
              if old_email_sent_admin == user.warning_email_sent_admin and old_email_sent_admin == 1 and user_owner_admin
                MorLog.my_debug("Email was already sent to ADMIN")
              end
              if old_email_sent_manager == user.warning_email_sent_manager and old_email_sent_manager == 1 and user_owner_admin
                MorLog.my_debug("Email was already sent to MANAGER")
              end
            end
          end
        rescue => exception
          if enable_debug == 1
            MorLog.my_debug("warning_balance email not sent to: #{user.id} #{user.username} #{email_to_address}, because: #{exception.message.to_s}")
          end
          Action.new(:user_id => user.owner_id, :target_id => user.id, :target_type => "user", :date => Time.now.to_s(:db), :action => "error", :data => 'Cant_send_email', :data2 => exception.message.to_s).save
        end
      end
    else
      if enable_debug == 1
        MorLog.my_debug("No users to send warning email balance")
      end
    end
    MorLog.my_debug("Sent balance warning action finished")
  end


  def find_registration_owner
    unless params[:id] and (@owner = User.where(:uniquehash => params[:id]).first)
      dont_be_so_smart
      redirect_to :action => "login" and return false
    end

    if Confline.get_value("Registration_enabled", @owner.id).to_i == 0
      dont_be_so_smart
      redirect_to :action => "login", :id => @owner.uniquehash and return false
    end
  end

  def check_users_count
    owner = User.where(uniquehash: params[:id]).first
    own_providers = owner.own_providers
    limit_it = ((own_providers == 1 and not reseller_pro_active?) or (own_providers == 0 and not reseller_active?))
    if owner and (owner.usertype == 'reseller') and limit_it and (User.where(owner_id: owner.id).count >= 2)
      flash[:notice] = _('Registration_is_unavailable')
      redirect_to :action => "login/#{params[:id]}" and return false
    end
  end

  def send_balance_warning_email(email, email_from, user, variables)
    user_id = user.id.to_i
    user_owner_id = user.owner_id.to_i
    status = _('email_not_sent')

    if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
      smtp_server = Confline.get_value('Email_Smtp_Server', user_owner_id).to_s.strip
      smtp_user = Confline.get_value('Email_Login', user_owner_id).to_s.strip
      smtp_pass = Confline.get_value('Email_Password', user_owner_id).to_s.strip
      smtp_port = Confline.get_value('Email_Port', user_owner_id).to_s.strip

      smtp_connection =  "'#{smtp_server.to_s}:#{smtp_port.to_s}'"
      smtp_connection << " -xu '#{smtp_user}' -xp '#{smtp_pass}'" if smtp_user.present?

      to = variables[:user_email]
      email_body = nice_email_sent(email, variables)
      begin
        system_call = ApplicationController::send_email_dry(email_from.to_s, to.to_s, email_body, email.subject.to_s, '', smtp_connection, email.format)

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
  end

  def update_timezone_offsets
    timezones = ActiveSupport::TimeZone.all
    timezones.each do |timezone|
      find_timezone_by_name = Timezone.where("zone = \"#{timezone.name}\"").first
      tz_to_db = find_timezone_by_name.blank? ? Timezone.new : find_timezone_by_name
      tz_to_db.zone = timezone.name
      tz_to_db.offset = Time.now.in_time_zone("#{timezone.name}").utc_offset
      tz_to_db.save
    end
  end

  def allow_register?(owner)
    if owner
      less_than_two_users_owned = User.where(owner_id: owner.id).count < 2
      is_reseller = owner.own_providers == 0
      is_reseller_pro = owner.own_providers == 1
      is_admin = owner.usertype == 'admin'
      return less_than_two_users_owned ||  (is_reseller && reseller_active?) || (is_reseller_pro && reseller_pro_active?) || is_admin
    else
      return false
    end
  end

  def set_time
    t = Time.now

    session[:year_from] = session[:year_till] = t.year
    session[:month_from] = session[:month_till] = t.month
    session[:day_from] = session[:day_till] = t.day

    session[:hour_from] = 0
    session[:minute_from] = 0

    session[:hour_till] = 23
    session[:minute_till] = 59
  end

  def get_logout_link(user_id)
    logout_link = Confline.get_value('Logout_link', user_id).to_s
    link = (logout_link.include?('http') ? '' : 'http://') + logout_link
    link
  end
end
