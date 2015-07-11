# -*- encoding : utf-8 -*-
class AutodialerController < ApplicationController

  layout 'callc'

  before_filter :access_denied, only: [:campaign_new, :user_campaigns, :import_numbers_from_file, :campaign_actions, :campaign_change_status,
                :campaign_edit, :campaign_numbers, :number_destroy, :delete_all_numbers], if: lambda { !(session[:usertype] == 'user')}

  before_filter :check_post_method, only: [:redial_all_failed_calls, :campaign_update, :campaign_create, :campaign_destroy, :action_destroy, :action_add, :action_update, :number_destroy]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_campaign, only: [:export_call_data_to_csv, :campaign_destroy, :view_campaign_actions, :campaign_update, :redial_all_failed_calls, :action_add, :campaign_actions, :import_numbers_from_file, :campaign_edit, :campaign_change_status, :campaign_numbers, :delete_all_numbers]
  before_filter :find_campaign_action, only: [:play_rec, :action_update, :action_edit, :action_destroy]
  before_filter :find_adnumber, only: [:reactivate_number, :number_destroy]
  before_filter :check_params_campaign, only: [:campaign_create, :campaign_update]
  before_filter :deprecated_functionality, only: [:campaign_new, :user_campaigns, :campaign_change_status, :redial_all_failed_calls, :campaign_destroy, :campaign_numbers, :campaign_update, :campaign_actions, :campaign_edit, :campaign_update, :import_numbers_from_file ]
  before_filter :allow_add_campaign?, only: [:campaign_new]

  def index
      user_campaigns
      (redirect_to action: :user_campaigns) && (return false)
  end

  # --------- Admin campaigns -------------
  def campaigns
    (dont_be_so_smart && (redirect_to :root)) if (current_user.usertype == 'reseller' && current_user.reseller_right('autodialer').to_i != 2)
    @page_title = _('Campaigns')
    @campaigns = Campaign.select("campaigns.*, #{SqlExport.nice_user_sql}")
                         .joins('JOIN users ON campaigns.user_id = users.id')
                         .where(['users.hidden = 0 AND users.owner_id = ?', current_user.id])
                         .order('campaigns.user_id, campaigns.name').all
    @total_numbers, @total_dialed, @total_completed, @total_profit = [0, 0, 0, 0]
  end

  def view_campaign_actions
    @page_title = _('Actions_for_campaign') + ': ' + @campaign.name
    @page_icon = 'actions.png'
    @actions = @campaign.adactions
  end

  # ------------ User campaigns -------------

  def user_campaigns
    @page_title = _('Campaigns')
    @user = current_user
    @campaigns = ad_active? ? @user.campaigns : @user.campaigns.limit(1)

    @allow_add_campaign = ((Campaign.count < 1) || ad_active?)
  end

  def campaign_new
    @user = current_user
    current_user_type = current_user.usertype

    if current_user_type == 'user' || current_user_type == 'accountant'
      @devices = current_user.devices.where("device_type != 'FAX'").all
    else
      @devices = Device.select('devices.id, devices.description, devices.extension, devices.device_type, devices.istrunk, devices.name, devices.ani, devices.username').
                        joins('LEFT JOIN users ON (users.id = devices.user_id)').
                        where(["device_type != 'FAX' AND owner_id = ? AND name not like 'mor_server_%'", corrected_user_id]).
                        order('extension').all
    end

    if @devices.size == 0
      flash[:notice] = _('Please_create_device_for_campaign')
      (redirect_to action: 'user_campaigns') && (return false)
    end

    @page_title = _('New_campaign')
    @page_icon = 'add.png'

    @campaign = Campaign.new

    @ctypes = ['simple']
    time_now = Time.now
    time_now_year = time_now.year
    time_now_month = time_now.month
    time_now_day = time_now.day
    t0 = Time.mktime(time_now_year, time_now_month, time_now_day, '00', '00')
    t1 = Time.mktime(time_now_year, time_now_month, time_now_day, '23', '59')

    @from_hour = t0.hour
    @from_min = t0.min
    @till_hour = t1.hour
    @till_min = t1.min
  end

  def campaign_create
    params_campaign = params[:campaign]
    params_time_from = params[:time_from]
    params_time_till = params[:time_till]
    time_from = time_in_local_tz(params_time_from[:hour], params_time_from[:minute], '00')
    time_till = time_in_local_tz(params_time_till[:hour], params_time_till[:minute], '59')
    @campaign = Campaign.create_by_user(current_user, params, time_from, time_till)
    errors = @campaign.errors.count
    if errors.to_i == 0 and @campaign.save
      flash[:status] = _('Campaign_was_successfully_created')
      redirect_to action: 'user_campaigns'
    else
      flash_errors_for(_('Campaign_was_not_created'), @campaign)
      redirect_to action: 'campaign_new'
    end
  end

  def campaign_destroy
    @campaign.destroy
    flash[:notice] = _('Campaign_deleted')
    redirect_to action: 'user_campaigns'
  end

  def campaign_edit
    @page_title = _('Edit_campaign')
    @page_icon = 'edit.png'
    @ctypes = ['simple']

    start_time, stop_time = [@campaign.start_time, @campaign.stop_time]

    from = time_in_user_tz(start_time.hour, start_time.min, '00')
    till = time_in_user_tz(stop_time.hour, stop_time.min, '59')

    @from_hour, @from_min = [from.hour, from.min]
    @till_hour, @till_min = [till.hour, till.min]

    @user = current_user
    current_user_type = current_user.usertype
    if current_user_type == 'user' or current_usertype == 'accountant'
      @devices = current_user.devices.where("device_type != 'FAX'")
    else
      @devices = Device.select('devices.id, devices.description, devices.extension, devices.device_type, devices.istrunk, devices.name, devices.ani, devices.username').
                        joins('LEFT JOIN users ON (users.id = devices.user_id)').
                        where(["device_type != 'FAX' AND owner_id = ? AND name not like 'mor_server_%'", corrected_user_id]).
                        order('extension')
    end
  end


  def campaign_update
    params_campaign = params[:campaign]
    params_time_from = params[:time_from]
    params_time_till = params[:time_till]

    time_from = time_in_local_tz(params_time_from[:hour], params_time_from[:minute], '00')
    time_till = time_in_local_tz(params_time_till[:hour], params_time_till[:minute], '59')
    @campaign.update_by(params_campaign, time_from, time_till)
    errors = @campaign.errors.count
    if errors.to_i == 0 && @campaign.save
      flash[:status] = _('Campaigns_details_was_successfully_changed')
      redirect_to action: 'user_campaigns'
    else
      flash_errors_for(_('Campaigns_details_not_changed'), @campaign)
      redirect_to action: 'campaign_edit', id: @campaign.id
    end
  end


  def campaign_change_status
    notice, status_changed = @campaign.change_status
    if @campaign.save && status_changed
      flash[:status] = notice
    else
      flash_errors_for(_('Campaigns_details_not_changed'), @campaign)
      flash[:notice] =notice
      Action.add_action_hash(current_user, target_type: 'campaign', action: 'failed_ad_campaign_activation', target_id: @campaign.id, data2: notice)
    end
    redirect_to action: 'user_campaigns'
  end

  # --------- Numbers ---------

  def campaign_numbers
    @page_title = _('Numbers_for_campaign') + ': ' + @campaign.name
    @page_icon = 'details.png'
    campaign_adnumbers = @campaign.adnumbers
    campaign_adnumbers_size_decimal = campaign_adnumbers.size.to_d
    session_items_per_page = session[:items_per_page]

    @allow_import_numbers = (ad_active? || Adnumber.where(campaign_id: @campaign.id).count < 10)

    @adnumbers_number =  ad_active? ? campaign_adnumbers_size_decimal : campaign_adnumbers.limit(10).size.to_d

    fpage, @total_pages, options = Application.pages_validator(session, params, @adnumbers_number)
    @page = options[:page]
    @numbers = campaign_adnumbers.offset(fpage).limit(session_items_per_page)

    unless ad_active?
      @numbers = @numbers[0...10]
      @numbers = @numbers[0...(10 % session_items_per_page.to_i)] if (@page == @total_pages) && (campaign_adnumbers_size_decimal > 10)
    end
  end

  def number_destroy
    campaign_id = @number.campaign_id
    @number.destroy
    flash[:status] = _('number_successfully_deleted')
    redirect_to controller: :autodialer, action: :campaign_numbers, id: campaign_id
  end


  def delete_all_numbers
    for num in @campaign.adnumbers
      num.destroy
    end

    flash[:status] = _('All_numbers_deleted')
    redirect_to action: 'campaign_numbers', id: params[:id]
  end


  def import_numbers_from_file

    adnumber_count_campaign_id = Adnumber.where(campaign_id: @campaign.id).count
    if (!ad_active?) && adnumber_count_campaign_id >= 10
      flash[:notice] = _('You_have_no_view_permission')
      (redirect_to :root) && (return false)
    end

    @page_title = _('Number_import_from_file')
    @page_icon = 'excel.png'

    @step = 1
    params_step = params[:step]
    params_file = params[:file]
    @step = params_step.to_i if params_step

    if @step == 2
      if params_file
        @file = params_file
        if  @file.size > 0
          if (!@file.respond_to?(:original_filename)) || (!@file.respond_to?(:read)) || (!@file.respond_to?(:rewind))
            flash[:notice] = _('Please_select_file')
            (redirect_to action: 'import_numbers_from_file', id: @campaign.id, step: '0') && (return false)
          end
          file_original_filename = @file.original_filename
          if get_file_ext(file_original_filename, 'csv') == false
            file_original_filename
            flash[:notice] = _('Please_select_CSV_file')
            (redirect_to action: 'import_numbers_from_file', id: @campaign.id, step: '0') && (return false)
          end
          @file.rewind
          file = @file.read
          session[:file_size] = file.size

          tname = CsvImportDb.save_file(@campaign.id, file, '/tmp/')
          session["atodialer_number_import_#{@campaign.id}".to_sym] = tname
          colums ={}
          colums[:colums] = [{name: 'f_number', type: 'VARCHAR(50)', default: ''},{name: 'f_error', type: 'INT(4)', default: 0}, {name: 'nice_error', type: 'INT(4)', default: 0}, {name: 'not_found_in_db', type: 'INT(4)', default: 0}, {name: 'id', type: 'INT(11)', inscrement: ' NOT NULL auto_increment '}]
          begin
            CsvImportDb.load_csv_into_db(tname, ',', '.', '', '/tmp/', colums)

            trial = {}
            unless ad_active?
              trial[:status] = 'autodialer'
              trial[:limit] = 10 - adnumber_count_campaign_id
              trial[:limit] = 0 if trial[:limit] < 0
            end

            @total_numbers, @imported_numbers, @bad_numbers_quantity = @campaign.insert_numbers_from_csv_file(tname, trial)

            if @total_numbers.to_i == @imported_numbers.to_i
              flash[:status] = _('Numbers_imported')
            else
              flash[:status] = _('M_out_of_n_numbers_imported', @imported_numbers, @total_numbers)
            end

          rescue => e
            MorLog.log_exception(e, Time.now.to_i, params[:controller], params[:action])
            CsvImportDb.clean_after_import(tname, '/tmp/')
            flash[:notice] = _('MySQL_permission_problem_contact_Kolmisoft_to_solve_it')
            (redirect_to action: 'import_numbers_from_file', id: @campaign.id, step: 0) && (return false)
          end
        else
          flash[:notice] = _('Please_select_file')
          (redirect_to action: "import_numbers_from_file", id: @campaign.id, step: '0') && (return false)
        end
      else
        flash[:notice] = _('Please_upload_file')
        (redirect_to action: 'import_numbers_from_file', id: @campaign.id, step: '0') && (return false)
      end
    end

  end

  def bad_numbers_from_csv
    params_id = params[:id].to_i
    session_autodial_number_import = session["atodialer_number_import_#{params_id}".to_sym]
    @page_title = _('Bad_rows_from_CSV_file')
    if ActiveRecord::Base.connection.tables.include?(session_autodial_number_import)
      @rows = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session_autodial_number_import} WHERE f_error = 1")
    end

    render(layout: 'layouts/mor_min')
  end


  def reactivate_number
    @number.status = 'new'
    @number.save
    flash[:status] = _('Number_reactivated') + ': ' + @number.number
    redirect_to :action => 'campaign_numbers', id: @number.campaign_id

  end

  #-------------- Actions --------------

  def campaign_actions
    @page_title = _('Actions_for_campaign') + ': ' + @campaign.name
    @page_icon = 'actions.png'
    @actions = @campaign.adactions
    @ivrs = Ivr.where(user_id: current_user.owner_id).count
  end


  def action_add
    action_type = params[:action_type]
    campaign_id = @campaign.id
    action = Adaction.new({priority: @campaign.adactions.size + 1, campaign_id: campaign_id, action: action_type})
    action.data = 'silence1' if action_type == 'PLAY'
    action.data = '1' if action_type == 'WAIT'
    action.save
    flash[:status] = _('Action_added')
    redirect_to action: 'campaign_actions', id: campaign_id
  end


  def action_destroy
    campaign_id = @action.campaign_id
    @action.destroy_action
    flash[:notice] = _('Action_deleted')
    redirect_to action: 'campaign_actions', id: campaign_id
  end


  def action_edit
    @page_title = _('Edit_action')
    @page_icon = 'edit.png'
    @campaign = @action.campaign
    @ivrs = Ivr.where(all_users_can_use: 1, user_id: current_user.owner_id)
  end

  def action_update
    path, final_path = @action.campaign.final_path

    notice = @action.update_action(params, current_user)
    @action.save
    if notice == 'dont_be_so_smart'
      dont_be_so_smart
    elsif !notice.blank?
      flash[:notice] = notice
    end

    redirect_to action: 'campaign_actions', id: @action.campaign_id

  end


  def play_rec
    @filename2 = @action.file_name
    @page_title = ''
    @Adaction_Folder = Web_Dir + '/ad_sounds/'
    @title = confline('Admin_Browser_Title')
    render(layout: 'play_rec')
  end


  def redial_all_failed_calls
    if Adnumber.update_all(" status = 'new' , executed_time = NULL", "status = 'executed' and campaign_id = #{@campaign.id}")
      flash[:status] = _('All_calls_failed_redial_was_successful')
    else
      flash[:notice] = _('All_calls_failed_redial_was_not_successful')
    end
    if session[:usertype] == 'admin'
      (redirect_to action: :campaigns) && (return false)
    else
      user_campaigns
      (redirect_to action: :user_campaigns) && (return false)
    end
  end

  def campaign_statistics
    params_campaign_id = params[:campaign_id]
    @page_title = _('Campaign_Stats')
    change_date
    session_year_from = session[:year_from]
    session_month_from = session[:month_from]
    session_day_from = session[:day_from]
    @select_date = {
        from: Time.mktime(session_year_from, session_month_from, session_day_from, session[:hour_from], session[:minute_from]),
        till: Time.mktime(session[:year_till], session[:month_till], session[:day_till], session[:hour_till], session[:minute_till])
    }
    @date = Time.mktime(session_year_from, session_month_from, session_day_from)
    year, month, day = last_day_month('till')
    @edate = Time.mktime(year, month, day)
    @campaign_id = params_campaign_id ? params_campaign_id.to_i : -1
    # ticket #5472 campaigns.owner_id seems to be 0 all the time, maybe it's
    # representing owner of the user that created campaign.
    # seems that campaigns.user_id is representing creator/owner of the campaign
    campaign_owner_id = ((@current_user.is_admin? or @current_user.is_accountant?) ? 0 : @current_user.id)
    @campaigns = Campaign.where("owner_id = #{campaign_owner_id} OR user_id = #{campaign_owner_id}").all
    @Calltime_graph = ''
    @answered_percent = @no_answer_percent = @failed_percent = @busy_percent = 0
    @calls_busy = @calls_failed = @calls_no_answer = @calls_answered = 0
    @numbers = []
    @channels = []
    @channels_number = []

    # if selected campaign
    if @campaign_id != -1
      @campaing_stat = Campaign.where(id: @campaign_id).first
      campaing_stat_name = @campaing_stat.name
      data = Adnumber.where(campaign_id: @campaign_id).all
      data.each do |numbers|
        @numbers << numbers.number
        @channels << numbers.channel
      end

      # if there are numbers
      if @numbers && (!@numbers.compact.empty?)
        # count dialed, completed, total call time, total call time longer than 10s
        @dialed = @campaing_stat.executed_numbers_count.to_s
        @complete = @campaing_stat.completed_numbers_count
        # if there are channels in db
        if @channels && (!@channels.compact.empty?)
          # create regexp ('Local/number@|..')
          @channels.each do |channel|
            @channels_number << channel.scan(/(.*@)/).flatten.first if channel
          end
          @channels_number = @channels_number.join('|')
          # find device
          @scr_device = @campaing_stat.device_id
          @total = @campaing_stat.count_completed_user_billsec(@scr_device, @channels_number, session_from_date, session_till_date)
          @total_longer_than_10 = @campaing_stat.count_completed_user_billsec_longer_than_ten(@scr_device, @channels_number, session_from_date, session_till_date)
          country_times_pie= ''
          if @channels && (@channels_number != '')
            @calls = Call.find_by_sql("select count(*) as counted_calls, disposition from calls where src_device_id = #{@scr_device} AND channel REGEXP '#{@channels_number}' AND disposition in ('ANSWERED', 'NO ANSWER','FAILED','BUSY') AND calldate BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' group by disposition")
            # count percent
            @calls.each do |call|
              call_counted_calls = call.counted_calls.to_i
              call_disposition = call.disposition
              @calls_answered = call_counted_calls if call_disposition == 'ANSWERED'
              @calls_no_answer = call_counted_calls if call_disposition == 'NO ANSWER'
              @calls_failed = call_counted_calls if call_disposition == 'FAILED'
              @calls_busy = call_counted_calls if call_disposition == 'BUSY'
            end
            @calls_all = @calls_answered+@calls_no_answer+@calls_failed+@calls_busy

            calls_all = @calls_all.to_i
            if  calls_all > 0
              @answered_percent = @calls_answered*100/ calls_all
              @no_answer_percent = @calls_no_answer*100/ calls_all
              @failed_percent = @calls_failed*100/ calls_all
              @busy_percent = @calls_busy*100/ calls_all
            end
            # create string fo pie chart
            country_times_pie += 'ANSWERED' + ';' + @calls_answered.to_s + ";true\\n"
            country_times_pie += 'NO ANSWER' +';' + @calls_no_answer.to_s + ";false\\n"
            country_times_pie += 'BUSY' + ';' + @calls_busy.to_s + ";false\\n"
            country_times_pie += 'FAILED' + ';' + @calls_failed.to_s + ";false\\n"
          else
            country_times_pie += _('No_result') + ";1;false\\n"
          end
          @pie_chart = country_times_pie

          i = 0
          @a_date = []
          @a_calls = []

          while @date < @edate
            @a_date[i] = @date.strftime("%Y-%m-%d")
            @a_calls[i] = 0
            a_date = @a_date[i]
            sql = 'SELECT COUNT(calls.id) as \'calls\', SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) as \'billsec\' FROM calls ' +
                'WHERE (calls.calldate BETWEEN \'' + a_date + ' 00:00:00\' AND \'' + a_date + " 23:59:59\' AND src_device_id = #{@scr_device} AND channel REGEXP '#{@channels_number}' )"
            res = ActiveRecord::Base.connection.select_all(sql)
            @a_calls[i] = res[0]['calls'].to_i
            @date += (60 * 60 * 24)
            i+=1
          end

          index = i
          ine = 0
          # create string fo column chart
          @Calls_graph = ""
          while ine <= index - 1
            @Calls_graph +=@a_date[ine].to_s + ";" + @a_calls[ine].to_s + "\\n"
            ine= ine + 1
          end
        else
          flash[:notice] = _('No_calls_with_campaign') + campaing_stat_name
        end
      else
        flash[:notice] = _('No_numbers_in_campaign') + campaing_stat_name
        (redirect_to action: :campaign_statistics) && (return false)
      end
    end

  end

  def   export_call_data_to_csv
    IvrActionLog.link_logs_with_numbers

    @numbers = @campaign.adnumbers.includes([:ivr_action_logs]).all

    sep, dec = current_user.csv_params

    csv_string = []

    for number in @numbers
      s = []
      number_completed_time = number.completed_time
      number_executed_time = number.executed_time
      number_ivr_action_logs = number.ivr_action_logs

      s << number.number
      s << nice_date_time(number_executed_time).to_s unless number_executed_time.blank?
      s << nice_date_time(number_completed_time).to_s unless number_completed_time.blank?

      if number_ivr_action_logs.size.to_i > 0
        for action in number_ivr_action_logs
          s << nice_date_time(action.created_at).to_s
          s << action.action_text.to_s.gsub(sep, '')
        end
      end

      csv_string << s.join(sep) if s && (s.size.to_i > 0)
    end

    csv_string_with_br = csv_string.join("\n")
    if params[:test].to_i == 1
      render :text => csv_string_with_br
    else
      send_data(csv_string_with_br, type: 'text/csv; charset=utf-8; header=present', filename: 'Campaign_call_data.csv')
    end

  end

  private

  def find_campaign
    current_user_type = current_user.usertype

    @campaign = Campaign.where("id = #{params[:id]} AND (user_id = #{current_user_id} OR owner_id = #{current_user_id})").first

    unless @campaign
      flash[:notice] = _('Campaign_was_not_found')
      if current_user_type.to_s == "reseller" and current_user.reseller_right('autodialer').to_i != 2
        flash[:notice] = _('You_are_not_authorized_to_view_this_page')
        (redirect_to :root) && (return false)
      elsif ["admin", "accountant", "reseller"].include?(current_user_type)
        dont_be_so_smart
        (redirect_to :root) && (return false)
      else
        (redirect_to action: user_campaigns) && (return false)
      end
    end
  end

  def find_campaign_action
    @action = Adaction.where({id: params[:id]}).includes([:campaign]).first
    unless @action
      flash[:notice] = _('Action_was_not_found')
      if current_user.is_admin?
        (redirect_to action: :campaigns) && (return false)
      else
        (redirect_to action: :user_campaigns) && (return false)
      end
    end

    camp = @action.campaign
    params_ivr = params[:ivr]
    ivr = Ivr.where(id: params_ivr.to_i, all_users_can_use: 1).first if params_ivr

    if camp.blank? || (params_ivr && ivr.blank?)
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    a=check_user_id_with_session(camp.user_id)
    return false if !a
  end

  def find_adnumber
    @number = Adnumber.where(id: params[:id]).includes([:campaign]).first
    unless @number
      flash[:notice] = _('Number_was_not_found')
      if session[:usertype] == 'admin'
        (redirect_to action: :campaigns) && (return false)
      else
        user_campaigns
        (redirect_to action: :user_campaigns) && (return false)
      end
    end
    a=check_user_id_with_session(@number.campaign.user_id)
    return false if !a
  end

  def check_params_campaign
    if (!params[:campaign]) || (!params[:time_from]) || (!params[:time_till])
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def deprecated_functionality
    current_user_type = current_user.usertype
    if ['admin', 'accountant', 'reseller'].include?(current_user_type)
      if current_user_type.to_s == 'reseller' && current_user.reseller_right('autodialer').to_i != 2
        flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      else
        flash[:notice] = _('Deprecated_functionality') + " <a href='http://wiki.kolmisoft.com/index.php/Deprecated_functionality' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png'/></a>".html_safe
      end
      (redirect_to :root) && (return false)
    end
  end

  def allow_add_campaign?
    if !ad_active? && Campaign.count >= 1
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    end
  end

  def time_in_local_tz(hours, minutes, seconds = '00')
    time_str = [hours, minutes, seconds].join(':')

    time = Time.zone.parse(time_str).localtime
    time
  end
end
