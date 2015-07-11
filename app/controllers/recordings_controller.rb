# -*- encoding : utf-8 -*-
class RecordingsController < ApplicationController

  layout "callc"

  before_filter :check_localization
  before_filter :addon_on?
  before_filter :authorize
  before_filter :check_post_method, :only => [:destroy_recording, :destroy, :update, :update_recordings, :list_users_update]
  before_filter :res_authorization, :only => [:show]

  before_filter { |c|
    view = [:index, :list, :play_rec, :play_recording, :show, :get_recording]
    edit = [:edit, :update, :setup, :update_recordings, :calls2recordings_disabled, :destroy, :destroy_recording]
    allow_read, allow_edit = c.check_read_write_permission(view, edit, { role: 'accountant', right: 'acc_recordings_manage', ignore: true })
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  def index
    redirect_to action: 'list_recordings' and return false
  end

=begin
  def setup
    @page_title = _('Recordings')
    @page_icon = "music.png"
    if !recordings_addon_active?
      dont_be_so_smart
      redirect_to :root and return false
    end
    @devices = Device.find_by_sql("SELECT devices.* FROM devices JOIN users ON (devices.user_id = users.id) WHERE user_id > 0 AND users.hidden = 0 ORDER BY extension ASC")
  end
=end

  def get_recording
    rec_id	   = params[:rec]
    rec		   = Recording.where(id: params[:rec]).first
    rec_users      = User.where(id: [rec.user_id, rec.dst_user_id]) if rec
    is_authorized  = (rec_users.collect(&:owner_id) + [rec.user_id, rec.dst_user_id] + [0]).include? correct_owner_id if rec

    if rec_id.blank? || rec_users.blank?
      dont_be_so_smart
      redirect_to :root and return false
    elsif !is_authorized
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :root and return false
    else
      rec_mp3 = File.read("/home/mor/public/recordings/#{rec.uniqueid}.mp3") rescue nil
      if  !rec or !rec_mp3
        flash[:notice] = _('Recording_was_not_found')
        redirect_to :root and return false
      else
        rec_user = User.where(id: rec.user_id).first
        rec_user = User.where(id: rec.dst_user_id).first if rec_user.blank?
        send_data(File.open("/home/mor/public/recordings/#{rec.uniqueid}.mp3").read, filename: rec.datetime.strftime("%F_%T_") + nice_user(rec_user).gsub(" ", "_").to_s + '_[' + rec.uniqueid + '].mp3')
      end
    end
  end

  def update_recordings
    Device.order('extension ASC').each do |dev|
      dev.record_forced = 0
      dev.record_forced = 1 if params[dev.id.to_s] == '1'
      dev.save
    end
    redirect_to action: 'setup' and return false
  end

  # maps calls to recordings
  def calls2recordings_disabled
    # cdr2calls
    recs = Recording.where("call_id = '0'")

    temp = []
    recs.each do |rec|
      call = rec.get_call
      if call
        rec.call = call
        rec.save
        temp << call
      end
    end
    temp
  end

  def show
    unless recordings_addon_active?
      dont_be_so_smart
      redirect_to :root and return false
    end
    @device = Device.where(:id => params[:show_rec]).first
    unless @device
      flash[:notice] = _('Device_not_found')
      redirect_to :root and return false
    end

    @user = @device.user
    device_id = @device.user

    @page_title = _('Recordings')
    @page_icon = 'music.png'

    # calls2recordings
    change_date

    from_t = session[:current_user_time_from]
    till_t = session[:current_user_time_till]

    @page = 1
    @page = params[:page].to_i if params[:page]
    @from = ((@page - 1) * session[:items_per_page]).to_i
    @to = (session[:items_per_page]).to_i
    @s_dev = device_id
    # @recs = Recording.find(:all, :conditions => ["SUBSTRING(datetime,1,10) BETWEEN ? AND ? AND (src_device_id = ? OR dst_device_id = ?)",session_from_date,session_till_date, @device.id, @device.id], :order => "datetime DESC")

    #    sql = "SELECT * FROM recordings WHERE SUBSTRING(datetime,1,10) BETWEEN '#{session_from_date}' AND '#{session_till_date}' AND (src_device_id = '#{@device.id}' OR dst_device_id = '#{@device.id}') ORDER BY datetime DESC "
    sql = "SELECT recordings.*, providers.name AS provider_name FROM recordings LEFT JOIN calls ON recordings.call_id = calls.id LEFT JOIN providers ON providers.id = calls.provider_id WHERE recordings.datetime BETWEEN '#{from_t}' AND '#{till_t}' AND (recordings.src_device_id = '#{device_id}' OR recordings.dst_device_id = '#{device_id}') ORDER BY recordings.datetime DESC LIMIT #{@from}, #{@to}"

    my_debug sql

    @recs = Recording.find_by_sql(sql)
    @total_pages = Recording.count(:all, conditions: "datetime BETWEEN '#{from_t}' AND '#{till_t}' AND (src_device_id = '#{device_id}' OR dst_device_id = '#{device_id}')")
    (@total_pages % session[:items_per_page] > 0) ? (@rest = 1) : (@rest = 0)
    @total_pages = @total_pages / session[:items_per_page] + @rest
    @page_select_options = { action: 'show', controller: 'recordings', show_rec: @s_dev }
    @show_recordings_with_zero_billsec = (Confline.get_value('Show_recordings_with_zero_billsec').to_i == 1)
  end

  def play_rec
    @page_title = ''
    @rec = Recording.where(id: params[:rec]).first
    unless @rec
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :root and return false
    end
    @title = Confline.get_value('Admin_Browser_Title')
    @call = @rec.call
    render(layout: 'play_rec')
  end

=begin rdoc
 Plays recording in new popup window.

 *Params*:

 +id+ - Recording ID.
=end

  def play_recording
    @page_title = ''
    @rec = Recording.where(id: params[:id]).first
    unless @rec
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :root and return false
    end
    @recording = ''
    if @rec
      server_path = get_server_path(@rec.local)
      a = check_user_for_recording(@rec)
      return false unless a

      @title = Confline.get_value('Admin_Browser_Title')
      @call = @rec.call

      @recording = server_path.to_s + @rec.mp3
    end
    render(layout: 'play_rec')
  end

=begin rdoc
 Lists recordings for admin and reseller.
=end

  def list
    @page_title = _('Recordings')
    @page_icon = 'music.png'

    unless recordings_addon_active?
      dont_be_so_smart
      redirect_to :root and return false
    end

    if params[:id].to_i == 0
      redirect_to action: 'recordings' and return false
    end

    @server_path = get_server_path(1)
    @remote_server_path = get_server_path(0)

    if session[:usertype] == 'admin' or 'reseller' or 'accountant'
      id = params[:id]
    else
      id = session[:user_id]
    end
    @user = User.where(id: id).first

    unless @user.is_user?
      flash[:notice] = _('Recordings_were_not_found')
      redirect_to :root and return false
    end

    change_date
    set_variables_by_params

    conditions_str = []
    conditions_var = []

    conditions_str << 'recordings.datetime BETWEEN ? AND ?'
    conditions_var += [@date_from, @date_till]

    set_condition(conditions_str, conditions_var)

    if @user
      conditions_str << '(recordings.user_id = ? OR recordings.dst_user_id = ?)'
      conditions_var += [@user.id]*2
      @search = 1
    end

    @search = 0 if params[:clear].to_i == 1
    @size = Recording.count(conditions: [conditions_str.join(' AND ')] +conditions_var).to_i
    @items_per_page = Confline.get_value('Items_Per_Page').to_i
    @total_pages = (@size.to_d / @items_per_page.to_d).ceil
    @recordings = Recording.includes(:call).where([conditions_str.join(' AND ')] + conditions_var).references(:call).limit(@items_per_page).offset((@page - 1) * @items_per_page).order('datetime DESC').all
    @page_select_params = {
        s_source: @search_source,
        s_destination: @search_destination
    }
    @show_recordings_with_zero_billsec = (Confline.get_value('Show_recordings_with_zero_billsec').to_i == 1)
  end

  # Lists recordings for user.
  def list_recordings
    @page_title = _('Recordings')
    @page_icon = 'music.png'

    unless user?
      dont_be_so_smart
      redirect_to :root and return false
    end

    @user = User.where(id: session[:user_id]).first

    @server_path = get_server_path(1)
    @remote_server_path = get_server_path(0)

    change_date
    set_variables_by_params

    conditions_str = []
    conditions_var = []

    conditions_str << 'recordings.datetime BETWEEN ? AND ?'
    conditions_var += [@date_from, @date_till]
    conditions_str << 'deleted = ?'
    conditions_var << 0

    if @search_source != '' && @search_destination != ''
      conditions_str << '(recordings.src LIKE ? OR recordings.dst LIKE ? )'
      conditions_var += [@search_source, @search_destination]
      @search = 1
    else
      set_condition(conditions_str, conditions_var)
    end

    @search = 0 if params[:clear].to_i == 1
    conditions_str << '((recordings.user_id = ? AND visible_to_user = 1) OR (recordings.dst_user_id = ? AND visible_to_dst_user = 1))'
    conditions_var += [@user.id, @user.id]

    @items_per_page = Confline.get_value('Items_Per_Page').to_i
    @size = Recording.where([conditions_str.join(' AND ')] +conditions_var).count.to_i
    @recordings = Recording.includes(:call).where([conditions_str.join(' AND ')] + conditions_var).references(:call).limit(@items_per_page).offset((@page - 1) * @items_per_page).order('calls.calldate DESC').all
    @total_pages = (@size.to_d / @items_per_page.to_d).ceil
    @page_select_params = {
        s_source: @search_source,
        s_destination: @search_destination
    }

    @show_recordings_with_zero_billsec = (Confline.get_value('Show_recordings_with_zero_billsec').to_i == 1)
  end

  # Recording edit action for admin and reseller.
  def edit
    @page_title = _('Edit_Recording')
    @page_icon = 'edit.png'
    @recording = Recording.where(id: params[:id]).first
    unless @recording
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :root and return false
    end
    access = check_user_for_recording(@recording)
    return false unless access
  end

=begin rdoc
  Recording edit action for user.
=end

  def edit_recording
    @page_title = _('Edit_Recording')
    @page_icon = 'edit.png'
    @recording = Recording.where(id: params[:id]).first
    unless @recording
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :root and return false
    end
    a = check_user_for_recording(@recording)
    return false unless a
  end

=begin rdoc
 Recording update action for admin and reseller.
=end

  def update
    @recording = Recording.where(id: params[:id]).first
    unless @recording
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :root and return false
    end
    a = check_user_for_recording(@recording)
    return false unless a

    @recording.comment = params[:recording][:comment].to_s
    if @recording.save
      flash[:notice] = _('Recording_was_updated')
    else
      flash[:notice] = _('Recording_was_not_updated')
    end
    redirect_to(action: 'list_recordings') and return false
  end

=begin rdoc
 Recording update action for user
=end

  def update_recording
    @recording = Recording.where(id: params[:id]).first
    unless @recording
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :root and return false
    end
    access = check_user_for_recording(@recording)
    return false unless access

    @recording.comment = params[:recording][:comment].to_s
    if @recording.save
      flash[:notice] = _('Recording_was_updated')
    else
      flash[:notice] = _('Recording_was_not_updated')
    end
    redirect_to(action: 'recordings') and return false
  end

=begin rdoc

=end

  def list_users
    @page_title = _('Users')
    @page_icon = 'vcard.png'
    @roles = Role.where("name !='guest'").all
    @items_per_page = Confline.get_value('Items_Per_Page').to_i

    @search = params[:search_on].try(:to_i) || 0
    @page = params[:page].try(:to_i) || 1
    @search_username = params[:s_username] || ''
    @search_fname = params[:s_first_name] || ''
    @search_lname = params[:s_last_name] || ''
    @search_agrnumber = params[:s_agr_number] || ''
    @search_sub = params[:sub_s].try(:to_i) || -1
    @search_type = params[:user_type] || -1
    @search_account_number = params[:s_acc_number] || ''
    @search_clientid = params[:s_clientid] || ''

    @users, @size = User.list_for_recordings(params, session)

    @total_pages = (@size / @items_per_page.to_d).ceil
    @page_select_params = {
        s_username: @search_username,
        s_first_name: @search_fname,
        s_last_name: @search_lname,
        s_agr_number: @search_agrnumber,
        sub_s: @search_sub,
        user_type: @search_type,
        s_acc_number: @search_account_number,
        s_clientid: @search_clientid
    }
  end

  def recordings
    @page_title = _('Recordings')
    @page_icon = 'music.png'
    change_date
    owner_id = correct_owner_id

    unless recordings_addon_active?
      dont_be_so_smart
      redirect_to :root and return false
    end

    set_variables_by_params

    params[:s_user_id] ? @user = params[:s_user_id] : @user = 'all'
    @user.sub!('-2', 'all') if params[:s_user].blank?
    params[:s_device] ? @device = params[:s_device].to_i : @device = 'all'

    # check if params were past not with fake form
    if ['-2', 'all'].exclude?(@user)
      user = User.where(id: @user).first
      if user.try(:owner_id) != owner_id
        dont_be_so_smart
        redirect_to :root
        return false
      end
    end

    conditions_str = ['?']
    conditions_var = ['1']

    #    conditions_str = ["users.owner_id = ?"]
    #    conditions_var = [owner_id]

    conditions_str << 'recordings.datetime BETWEEN ? AND ?'
    conditions_var += [@date_from, @date_till]

    set_condition(conditions_str, conditions_var)

    if !@user.blank? && @user != 'all'
      conditions_str << 'recordings.user_id = ?'
      conditions_var << @user.to_i
      @devices = Device.select('devices.*').joins('LEFT JOIN users ON (users.id = devices.user_id)').where(["users.owner_id = ? AND device_type != 'FAX' AND user_id = ? AND name not like 'mor_server_%'", owner_id, @user])
      @search = 1
    else
      @devices = []
    end

    if !@device.blank? && @device != 'all' && @device.to_i != 0
      conditions_str << '(recordings.src_device_id  = ? OR recordings.dst_device_id  = ?)'
      conditions_var += [@device, @device]
      @search = 1
    end

    @search = 0 if params[:clear].to_i == 1

    @recordings = Recording.select('recordings.*').
                            joins('LEFT JOIN users ON (users.id = recordings.user_id)').
                            where([conditions_str.join(' AND ')] + conditions_var).
                            limit(session[:items_per_page]).
                            offset((@page-1) * session[:items_per_page]).
                            order('datetime DESC').all

    @size = Recording.count(joins: 'LEFT JOIN users ON (users.id = recordings.user_id)', conditions: [conditions_str.join(' AND ')] + conditions_var)
    @total_pages = @size / session[:items_per_page]

    @server_path = get_server_path(1)
    @remote_server_path = get_server_path(0)
    @show_recordings_with_zero_billsec = (Confline.get_value('Show_recordings_with_zero_billsec').to_i == 1)
  end

=begin  rdoc

=end

  def list_users_update
    params[:search_on] ? @search = params[:search_on].to_i : @search = 0
    params[:fs_page] ? @page = params[:fs_page].to_i : @page = 1
    params[:fs_username] ? @search_username = params[:fs_username] : @search_username = ''
    params[:fs_first_name] ? @search_fname = params[:fs_first_name] : @search_fname = ''
    params[:fs_last_name] ? @search_lname = params[:fs_last_name] : @search_lname = ''
    params[:fs_agr_number] ? @search_agrnumber = params[:fs_agr_number] : @search_agrnumber = ''
    params[:fsub_s] ? @search_sub = params[:fsub_s] : @search_sub = -1
    params[:fuser_type] ? @search_type = params[:fuser_type] : @search_type = -1
    params[:fs_acc_number] ? @search_account_number = params[:fs_acc_number] : @search_account_number = ''
    params[:fs_clientid] ? @search_clientid = params[:fs_clientid] : @search_clientid = ''
    users = {}
    params.each { |key, value|
      if key.scan(/recording_enabled_|recording_forced_enabled_|recording_hdd_quota_|recordings_email_/).size > 0
        num = key.gsub(/recording_enabled_|recording_forced_enabled_|recording_hdd_quota_|recordings_email_/, '')
        unless users[num]
          users[num] = User.where(id: num).first
        end
      end
    }
    users.each { |num, user|
      user.update_recordings_permissions(params, num)
      user.save
    }
    flash[:status] = _('Users_have_been_updated')
    redirect_to action: 'list_users', page: @page, s_username: @search_username, s_first_name: @search_fname, s_last_name: @search_lname, s_agr_number: @search_agrnumber, sub_s: @search_sub, user_type: @search_type, s_acc_number: @search_account_number, s_clientid: @search_clientid and return false
  end

=begin rdoc
 Destroys recording. Action for user.
=end

  def destroy_recording
    @recording = Recording.where(id: params[:id]).first
    unless @recording
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :root and return false
    end
    a = check_user_for_recording(@recording)
    return false unless a
    if @recording.destroy_all
      flash[:notice] = _('Recording_was_destroyed')
    else
      flash[:notice] = _('Recording_was_not_destroyed')
    end
    redirect_to(:back) and return false
  end

=begin rdoc
 Destroys recording.
=end

  def destroy
    rec = Recording.where(id: params[:id]).first
    unless rec
      flash[:notice] = _('Recording_was_not_found')
      redirect_to :root and return false
    end
    a = check_user_for_recording(rec)
    return false unless a

    notice = rec.destroy_rec(session)
    if !notice
      redirect_to :root and return false
    else
      flash[:notice] = notice
    end
    redirect_to action: 'list_recordings'
  end

  def bulk_management
    @page_title = _('Bulk_management')
    @page_icon = 'music.png'
    @find_rec_size = -1
    session[:recordings_delete_cond] = nil

    if params[:recordings_action].to_i != 0
      @devices = Device.where("user_id = #{params[:s_user_id]} AND device_type != 'FAX'")
    else
      @devices = []
    end

    if params[:rec_action].to_i != 0
      cond = 'id = -1'
      @type = params[:rec_action].to_i
      if params[:rec_action].to_i == 1
        @device = Device.where(id: params[:s_device]).first
        unless @device
          flash[:notice] = _('Device_was_not_found')
          redirect_back_or_default('/callc/main')
        end
        cond = "src_device_id = #{q(@device.id)}"
      end
      if params[:rec_action].to_i == 2
        change_date
        cond = "datetime BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'"
      end
      session[:recordings_delete_cond] = cond
      @find_rec_size = Recording.count(:all, conditions: cond)
    end
  end

  def bulk_delete
    recordings = Recording.where(session[:recordings_delete_cond]).all
    for r in recordings
      unless r
        flash[:notice] = _('Recording_was_not_found')
        redirect_to :root and return false
      end
      a = check_user_for_recording(r)
      return false if !a
      if r.destroy_all
        flash[:notice] = _('Recordings_was_destroyed')
      else
        flash[:notice] = _('Recordings_was_not_destroyed')
        redirect_to(action: 'recordings') and return false
      end
    end
    redirect_to(action: 'recordings') and return false
  end

  private

=begin rdoc

=end

  def get_server_path(local = 1)
    if local == 0
      server = Confline.get_value('Recordings_addon_IP')
      # server_port = Confline.get_value("Recordings_addon_Port")
      # server_port.to_s != "" ? server_path = "http://"+ server + ":" + server_port : server_path = "http://"+ server
      server_path = "http://#{server.to_s}/recordings/"
    else
      server_path = Web_URL + Web_Dir + '/recordings/'
    end

    server_path
  end

=begin rdoc

=end

  def check_user_for_recording(recording)
    user_id = recording.user_id
    if ((user_id != session[:user_id] && recording.dst_user_id != session[:user_id])) && (user?)
      dont_be_so_smart
      redirect_to :root and return false
    end
    if session[:usertype] == 'reseller' && ((recording.user.try(:owner_id) != session[:user_id]) && (recording.dst_user.try(:owner_id) != session[:user_id]))
      if user_id != session[:user_id]
        dont_be_so_smart
        redirect_to :root and return false
      end
    end
    true
  end

  def addon_on?
    unless rec_active?
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def res_authorization
    if  reseller?
      device = Device.where(id: params[:show_rec]).first
      user = device.user if device
      if user && (user.owner_id != current_user.id)
        flash[:notice] = _('You_have_no_view_permission')
        redirect_to :root and return false
      end
    end
  end

  def set_variables_by_params
    params[:page] ? @page = params[:page].to_i : @page = 1
    params[:search_on] ? @search = params[:search_on].to_i : @search = 0
    params[:s_source] ? @search_source = params[:s_source] : @search_source = ''
    params[:s_destination] ? @search_destination = params[:s_destination] : @search_destination = ''
    @date_from = params[:date_from_link] ? params[:date_from_link] : limit_search_by_days
    @date_till = params[:date_till_link] ? params[:date_till_link] : session_till_datetime
  end

  def set_condition(conditions_str, conditions_var)
    unless @search_source.blank?
      conditions_str << 'recordings.src LIKE ?'
      conditions_var << @search_source
      @search = 1
    end

    unless @search_destination.blank?
      conditions_str << 'recordings.dst LIKE ?'
      conditions_var << @search_destination
      @search = 1
    end
  end
end
