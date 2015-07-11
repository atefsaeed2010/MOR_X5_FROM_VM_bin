# -*- encoding : utf-8 -*-
class SmsautodialerController < ApplicationController

  layout "callc"
  before_filter :check_post_method, :only => [:redial_all_failed_calls, :campaign_update, :campaign_create, :campaign_destroy, :action_destroy, :action_add, :action_update, :number_destroy]
  before_filter :check_localization
  before_filter :authorize
  before_filter :check_user_type, :only => [:export_call_data_to_csv, :campaign_new, :campaign_destroy, :campaign_update, :redial_all_failed_calls, :action_add, :campaign_actions, :import_numbers_from_file, :campaign_edit, :campaign_change_status, :campaign_numbers, :delete_all_numbers]
  before_filter :find_campaign, :only => [:export_call_data_to_csv, :campaign_destroy, :view_campaign_actions, :campaign_update, :redial_all_failed_calls, :action_add, :campaign_actions, :import_numbers_from_file, :campaign_edit, :campaign_change_status, :campaign_numbers, :delete_all_numbers]
  before_filter :find_campaign_action, :only => [:play_rec, :action_update, :action_edit, :action_destroy]
  before_filter :find_adnumber, :only => [:reactivate_number, :number_destroy]
  before_filter :check_params_campaign, :only => [:campaign_create, :campaign_update]
  before_filter :check_sms_addon

  def index
    user_campaigns
    redirect_to :action => :user_campaigns and return false
  end

  # --------- Admin campaigns -------------

  def campaigns
    (dont_be_so_smart and redirect_to :root) if (reseller? and current_user.reseller_right('sms_addon').to_i != 2)
    @page_title = _('SMS_Campaigns')
    @page_icon = 'phone.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/SMS_Addon_Mass_SMS'

    current_user_id = current_user.id
    session_campaigns_order = session[:campaigns_order]
    @campaigns = []

    @options = session_campaigns_order ? session_campaigns_order : {:order_by => 'username', :order_desc => 0, :page => 1}

    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (@options[:order_by] = "name" if !@options[:order_by])
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    @options[:page] = params[:page].to_i if params[:page]

    session[:campaigns_order] = @options

    order_by = campaigns_order_by(@options)

    session_items_per_page = session[:items_per_page]
    @page = @options[:page].to_i
    total_campaigns = SmsCampaign.where(:owner_id => current_user_id).size
    @total_pages = (total_campaigns / session_items_per_page.to_d).ceil

    @page = @total_pages if @page > @total_pages
    @page = 1 if @page < 1
    offset = session_items_per_page * (@page-1)

    @options[:page] = @page

    @campaigns = SmsCampaign.select("sms_campaigns.*").
                                    joins('INNER JOIN users ON (users.id = sms_campaigns.user_id)').
                                    where(:owner_id => current_user_id).
                                    limit(@page * session_items_per_page).
                                    offset(offset).
                                    order(order_by)

  end


  def view_campaign_actions
    @page_title = _('Actions_for_campaign') + ": " + @campaign.name
    @page_icon = "actions.png"
    @actions = @campaign.sms_adactions
  end

  def campaigns_order_by(options)
    order_by_str = ''

    case options[:order_desc]
      when 0
        order_by_desc = ' ASC'
      when 1
        order_by_desc = ' DESC'
    end

    case options[:order_by]
      when 'username'
        order_by_str << 'username'
      when 'name'
        order_by_str << 'sms_campaigns.name'
      when 'type'
        order_by_str << 'sms_campaigns.campaign_type'
      when 'status'
        order_by_str << 'sms_campaigns.status'
      when 'start_time'
        order_by_str << 'sms_campaigns.start_time'
      when 'stop_time'
        order_by_str << 'sms_campaigns.stop_time'
    end

    order_by_str << order_by_desc if !order_by_str.blank?

    return order_by_str
  end

  # ------------ User campaigns -------------

  def user_campaigns
    if admin? or reseller?
      redirect_to :action => :campaigns and return false
    end

    @page_title = _('SMS_Campaigns')
    @page_icon = 'phone.png'

    params_page = params[:page]
    params_order_desc = params[:order_desc]
    params_order_by = params[:order_by]
    session_user_campaigns_order = session[:user_campaigns_order]
    items_per_page =  session[:items_per_page]
    current_user_id = current_user.id

    @options = session_user_campaigns_order ? session_user_campaigns_order : {:order_by => 'name', :order_desc => 0, :page => 1}

    @options[:order_by] = params_order_by.to_s if params_order_by
    @options[:order_desc] = params_order_desc.to_i if params_order_desc
    @options[:page] = params_page.to_i if params_page

    session[:user_campaigns_order] = @options

    order_by = campaigns_order_by(@options)

    @page = @options[:page].to_i
    total_campaigns = SmsCampaign.where(:user_id => current_user_id).size
    @total_pages = (total_campaigns / items_per_page.to_d).ceil

    @page = @total_pages if @page > @total_pages
    @page = 1 if @page < 1
    offset = items_per_page * (@page-1)

    @options[:page] = @page

    @campaigns = SmsCampaign.where(:user_id => current_user_id).limit(@page * items_per_page).offset(offset).order(order_by)
  end

  def campaign_new
    if admin? or reseller?
      redirect_to :action => :campaigns
    end

    @user = current_user
    current_user_type = current_user.usertype
    if current_user_type == 'user' or current_user_type == 'accountant'
      @devices = current_user.devices.where("device_type != 'FAX'")
    else
      @devices = Device.select("devices.id, devices.description, devices.extension, devices.device_type, devices.istrunk, devices.name, devices.ani, devices.username").joins("LEFT JOIN users ON (users.id = devices.user_id)").where(["device_type != 'FAX' AND owner_id = ? AND name NOT LIKE 'mor_server_%'", corrected_user_id]).order("extension")
    end

    if @devices.size == 0
      flash[:notice] = _('Please_create_device_for_sms_campaign')
      redirect_to :action => 'user_campaigns' and return false
    end

    @page_title = _('New_campaign')
    @page_icon = "add.png"

    @campaign = SmsCampaign.new

    @ctypes = ["simple"]

  end

  def campaign_create
    @campaign = SmsCampaign.create_by_user(current_user, params)
    if @campaign.save
      flash[:status] = _('Campaign_was_successfully_created')
      redirect_to :action => 'user_campaigns'
    else
      flash_errors_for(_('Campaign_was_not_created'), @campaign)
      redirect_to :action => 'campaign_new'
    end
  end


  def campaign_destroy
    @campaign.destroy
    flash[:status] = _('Campaign_deleted')
    redirect_to :action => 'user_campaigns'
  end


  def campaign_edit
    @page_title = _('Edit_campaign')
    @page_icon = "edit.png"
    @ctypes = ["simple"]

    @user = current_user
    current_user_type = current_user.usertype
    if current_user_type == 'user' or current_user_type == 'accountant'
      @devices = current_user.devices.where("device_type != 'FAX'")
    else
      @devices = Device.select("devices.id, devices.description, devices.extension, devices.device_type, devices.istrunk, devices.name, devices.ani, devices.username").joins("LEFT JOIN users ON (users.id = devices.user_id)").where(["device_type != 'FAX' AND owner_id = ? AND name NOT LIKE 'mor_server_%'", corrected_user_id]).order("extension")
    end
  end


  def campaign_update
    @campaign.update_by(params)
    if @campaign.save
      flash[:status] = _('Campaigns_details_was_successfully_changed')
      redirect_to :action => 'user_campaigns'
    else
      flash_errors_for(_('Campaigns_details_not_changed'), @campaign)
      redirect_to :action => 'campaign_edit', :id => @campaign.id
    end
  end

  def campaign_change_status
    notice, status_changed = @campaign.change_status
    if @campaign.save and status_changed
      flash[:status] = notice
    else
      flash_errors_for(_('Campaigns_details_not_changed'), @campaign)
      flash[:notice] =notice
      Action.add_action_hash(current_user, :target_type => 'campaign', :action => "failed_ad_campaign_activation", :target_id => @campaign.id, :data2 => notice)
    end
    redirect_to :action => 'user_campaigns'
  end

  # --------- Numbers ---------

  def campaign_numbers
    @page_title = _('Numbers_for_campaign') + ": " + @campaign.name
    @page_icon = "details.png"

    campaign_sms_adnumbers = @campaign.sms_adnumbers
    fpage, @total_pages, options = Application.pages_validator(session, params, campaign_sms_adnumbers.size.to_d)
    @page = options[:page]
    @numbers = campaign_sms_adnumbers.limit(session[:items_per_page]).offset(fpage)
  end

  def number_destroy
    sms_campaign_id = @number.sms_campaign_id
    @number.destroy
    flash[:status] = _('number_successfully_deleted')
    redirect_to :controller => :smsautodialer, :action => :campaign_numbers, :id => sms_campaign_id
  end


  def delete_all_numbers
    for num in @campaign.sms_adnumbers
      num.destroy
    end

    flash[:status] = _('All_numbers_deleted')
    redirect_to :action => 'campaign_numbers', :id => params[:id]
  end


  def import_numbers_from_file

    @page_title = _('Number_import_from_file')
    @page_icon = "excel.png"

    params_step = params[:step]
    params_file = params[:file]
    @step = 1
    @step = params_step.to_i if params_step

    campaign_id = @campaign.id
    if @step == 2
      if params_file
        @file = params_file
        if  @file.size > 0
          if !@file.respond_to?(:original_filename) or !@file.respond_to?(:read) or !@file.respond_to?(:rewind)
            flash[:notice] = _('Please_select_file')
            redirect_to :action => "import_numbers_from_file", :id => campaign_id, :step => "0" and return false
          end
          if get_file_ext(@file.original_filename, "csv") == false
            @file.original_filename
            flash[:notice] = _('Please_select_CSV_file')
            redirect_to :action => "import_numbers_from_file", :id => campaign_id, :step => "0" and return false
          end
          @file.rewind
          file = @file.read
          session[:file_size] = file.size

          tname = CsvImportDb.save_file(campaign_id, file, "/tmp/")
          session["atodialer_number_import_#{campaign_id}".to_sym] = tname
          colums ={}
          colums[:colums] = [{:name=>"f_number", :type=>"VARCHAR(50)", :default=>''},
                             {:name=>"f_error", :type=>"INT(4)", :default=>0},
                             {:name=>"nice_error", :type=>"INT(4)", :default=>0},
                             {:name=>"not_found_in_db", :type=>"INT(4)", :default=>0},
                             {:name=>"id", :type=>'INT(11)', :inscrement=>' NOT NULL auto_increment '}]
          begin
            CsvImportDb.load_csv_into_db(tname, ',', '.', '', "/tmp/", colums)

            @total_numbers, @imported_numbers = @campaign.insert_numbers_from_csv_file(tname)


            if @total_numbers.to_i == @imported_numbers.to_i
              flash[:status] = _('Numbers_imported')
            else
              flash[:status] = _('M_out_of_n_numbers_imported', @imported_numbers, @total_numbers)
            end

          rescue => exception
            MorLog.log_exception(exception, Time.now.to_i, params[:controller], params[:action])
            CsvImportDb.clean_after_import(tname, "/tmp/")
            flash[:notice] = _('MySQL_permission_problem_contact_Kolmisoft_to_solve_it')
            redirect_to :action => "import_numbers_from_file", :id => campaign_id, :step => "0" and return false
          end
        else
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "import_numbers_from_file", :id => campaign_id, :step => "0" and return false
        end
      else
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "import_numbers_from_file", :id => campaign_id, :step => "0" and return false
      end
    end

  end

  def bad_numbers_from_csv
    @page_title = _('Bad_rows_from_CSV_file')
    params_id = params[:id].to_i
    if ActiveRecord::Base.connection.tables.include?(session["atodialer_number_import_#{params_id}".to_sym])
      @rows = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session["atodialer_number_import_#{params_id}".to_sym]} WHERE f_error = 1")
    end

    render(:layout => "layouts/mor_min")
  end


  def reactivate_number
    @number.status = "new"
    @number.save
    flash[:status] = _('Number_reactivated') + ": " + @number.number
    redirect_to :action => 'campaign_numbers', :id => @number.sms_campaign_id

  end

  #-------------- Actions --------------

  def campaign_actions
    @page_title = _('Actions_for_campaign') + ": " + @campaign.name
    @page_icon = "actions.png"
    @actions = @campaign.sms_adactions
  end


  def action_add
    action_type = params[:action_type]
    campaign_id = @campaign.id
    action = SmsAdaction.new({:priority => @campaign.sms_adactions.size + 1, :sms_campaign_id => campaign_id, :action => action_type})
    if action.save
      flash[:status] = _('Action_added')
      redirect_to :action => 'campaign_actions', :id => campaign_id
    else
      flash[:notice] = _('Action_was_not_correct')
      redirect_to :action => 'campaign_actions', :id => campaign_id
    end

  end


  def action_destroy
    campaign_id = @action.sms_campaign_id
    @action.destroy_action
    flash[:status] = _('Action_deleted')
    redirect_to :action => 'campaign_actions', :id => campaign_id
  end


  def action_edit
    @page_title = _('Edit_action')
    @page_icon = "edit.png"
    @campaign = @action.sms_campaign
    @ivrs = current_user.ivrs if allow_manage_providers?
  end

  def action_update
    @action.update_action(params)
    @action.save
    redirect_to :action => 'campaign_actions', :id => @action.sms_campaign_id
  end


  def play_rec
    @filename2 = @action.file_name
    @page_title = ""
    @Adaction_Folder = Web_Dir + "/ad_sounds/"
    @title = confline("Admin_Browser_Title")
    render(:layout => "play_rec")
  end


  def redial_all_failed_calls
    if SmsAdnumber.update_all(" status = 'new' , executed_time = NULL", "status = 'executed' and sms_campaign_id = #{@campaign.id}")
      flash[:status] = _('All_calls_failed_redial_was_successful')
    else
      flash[:notice] = _('All_calls_failed_redial_was_not_successful')
    end
    if session[:usertype] == 'admin'
      redirect_to :action => :campaigns and return false
    else
      user_campaigns
      redirect_to :action => :user_campaigns and return false
    end
  end

  def campaign_statistics
    @page_title = _('Campaign_Stats')
    change_date
    @date = Time.mktime(session[:year_from], session[:month_from], session[:day_from])
    year, month, day = last_day_month('till')
    @edate = Time.mktime(year, month, day)
    params_campaign_id = params[:campaign_id]
    @campaign_id = params_campaign_id ? params_campaign_id.to_i : -1

    campaign_owner_id = ((@current_user.is_admin? or @current_user.is_accountant?) ? 0 : @current_user.id)
    @campaigns = SmsCampaign.where(:user_id => campaign_owner_id)
    @Calltime_graph = ""
    @answered_percent = @no_answer_percent = @failed_percent = @busy_percent = 0
    @calls_busy = @calls_failed = @calls_no_answer = @calls_answered = 0
    @numbers = []
    @channels = []
    @channels_number = []

    #if selected campaign
    if @campaign_id != -1
      @campaing_stat = SmsCampaign.where(:id => @campaign_id).first
      campaing_stat_name = @campaing_stat.name
      data = SmsAdnumber.where(:sms_campaign_id => @campaign_id)
      data.each do |numbers|
        @numbers << numbers.number
        @channels << numbers.channel
      end

      #if there are numbers
      if @numbers and !@numbers.compact.empty?
        #count dialed, completed, total call time, total call time longer than 10s
        @dialed = @campaing_stat.executed_numbers_count.to_s
        @complete = @campaing_stat.completed_numbers_count
        #if there are channels in db
        if @channels and !@channels.compact.empty?
          # create regexp ('Local/number@|..')
          @channels.each do |channel|
            @channels_number << channel.scan(/(.*@)/).flatten.first if channel
          end
          @channels_number = @channels_number.join('|')
          #find device
          @scr_device = @campaing_stat.device_id
          @total = @campaing_stat.count_completed_user_billsec(@scr_device, @channels_number, session_from_date, session_till_date)
          @total_longer_than_10 = @campaing_stat.count_completed_user_billsec_longer_than_ten(@scr_device, @channels_number, session_from_date, session_till_date)
          country_times_pie= "\""
          if @channels and @channels_number != ""
            @calls = Call.select("count(*) as counted_calls, disposition").where("src_device_id = #{@scr_device} AND channel REGEXP '#{@channels_number}' AND disposition in ('ANSWERED', 'NO ANSWER','FAILED','BUSY') AND calldate BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' group by disposition")
            #count percent
            @calls.each do |call|
              counted_calls = all.counted_calls.to_i
              disposition = call.disposition
              @calls_answered = counted_calls if disposition == 'ANSWERED'
              @calls_no_answer = counted_calls if disposition == 'NO ANSWER'
              @calls_failed = counted_calls if disposition == 'FAILED'
              @calls_busy = counted_calls if disposition == 'BUSY'
            end
            @calls_all = @calls_answered + @calls_no_answer + @calls_failed + @calls_busy

            all_calls = @calls_all.to_i
            if  all_calls > 0
              @answered_percent = @calls_answered*100/ all_calls
              @no_answer_percent = @calls_no_answer*100/ all_calls
              @failed_percent = @calls_failed*100/ all_calls
              @busy_percent = @calls_busy*100/ all_calls
            end
            #create string fo pie chart
            country_times_pie += "ANSWERED" + ";" + @calls_answered.to_s+ ";true\\n"
            country_times_pie += "NO ANSWER" +";" + @calls_no_answer.to_s+ ";false\\n"
            country_times_pie += "BUSY" +";" + @calls_busy.to_s+ ";false\\n"
            country_times_pie += "FAILED" + ";" +@calls_failed.to_s+ ";false\\n"
          else
            country_times_pie += _('No_result') + ";1;false\\n"
          end
          country_times_pie += "\""
          @pie_chart = country_times_pie

          iteration = 0
          @a_date = []
          @a_calls = []

          while @date < @edate
            @a_date[iteration] = @date.strftime("%Y-%m-%d")
            date_local = @a_date[iteration]
            @a_calls[iteration] = 0
            sql = 'SELECT COUNT(calls.id) as \'calls\', SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) as \'billsec\' FROM calls ' +
                'WHERE (calls.calldate BETWEEN \'' + date_local + ' 00:00:00\' AND \'' + date_local + " 23:59:59\' AND src_device_id = #{@scr_device} AND channel REGEXP '#{@channels_number}' )"
            res = ActiveRecord::Base.connection.select_all(sql)
            @a_calls[iteration] = res[0]["calls"].to_i
            @date += (60 * 60 * 24)
            iteration+=1
          end

          index = iteration
          ine = 0
          #create string fo column chart
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
      end
    end

  end

  def   export_call_data_to_csv

    @numbers = @campaign.sms_adnumbers

    sep, dec = current_user.csv_params

    csv_string = []

    for number in @numbers
      str = []
      executed_time = number.executed_time
      completed_time = number.completed_time
      str << number.number
      str << executed_time.to_s if !executed_time.blank?
      str << completed_time.to_s if !completed_time.blank?

      csv_string << str.join(sep) if str and str.size.to_i > 0
    end

    string = csv_string.join("\n")
    if params[:test].to_i == 1
      render :text => string
    else
      send_data(string, :type => 'text/csv; charset=utf-8; header=present', :filename => 'Campaign_call_data.csv')
    end

  end

  private

  def check_user_type
    if admin? or reseller?
      dont_be_so_smart
      redirect_to :action => :campaigns
    end
  end

  def find_campaign
    params_id = params[:id]
    if admin? or reseller?
      @campaign = SmsCampaign.where(:id => params_id).first
    else
      @campaign = current_user.sms_campaigns.where(:id => params_id).first
    end

    unless @campaign
      flash[:notice] = _('Campaign_was_not_found')
      if admin? or reseller?
        redirect_to :action => :campaigns and return false
      else
        redirect_to :action => :user_campaigns and return false
      end
    end
  end

  def find_campaign_action
    @action = SmsAdaction.where(:id => params[:id]).includes(:sms_campaign).first
    unless @action
      flash[:notice] = _('Action_was_not_found')
      if admin?
        redirect_to :action => :campaigns and return false
      else
        redirect_to :action => :user_campaigns and return false
      end
    end

    access = check_user_id_with_session(@action.sms_campaign.user_id)
    return false if !access
  end

  def find_adnumber
    @number = SmsAdnumber.where(:id => params[:id]).includes(:sms_campaign).first
    unless @number
      flash[:notice] = _('Number_was_not_found')
      if admin?
        redirect_to :action => :campaigns and return false
      else
        user_campaigns
        redirect_to :action => :user_campaigns and return false
      end
    end
    access = check_user_id_with_session(@number.sms_campaign.user_id)
    return false if !access
  end

  def check_params_campaign
    if !params[:campaign]
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def check_sms_addon
    authorization_fault = _('You_are_not_authorized_to_view_this_page')
    if !sms_active?
      flash[:notice] = authorization_fault
      redirect_to :root and return false
    end
    if reseller? and current_user.reseller_right('sms_addon').to_i != 2
      flash[:notice] = authorization_fault
      redirect_to :root and return false
    end
    current_user_owner = current_user.owner
    if current_user_owner.is_reseller? and current_user_owner.reseller_right('sms_addon').to_i != 2
      flash[:notice] = authorization_fault
      redirect_to :root and return false
    end
  end
end
