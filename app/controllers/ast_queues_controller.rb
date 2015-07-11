# -*- encoding : utf-8 -*-
class AstQueuesController < ApplicationController

  layout "callc"

  before_filter :check_post_method, :only => [:create, :update, :destroy]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_queue, :only => [:edit, :update, :destroy]
  before_filter :check_pbx_addon, :only => [:edit, :list, :new]
  before_filter { |c|
    view = [:index, :list]
    edit = [:create, :destroy, :update, :edit, :new]
    allow_read, allow_edit = c.check_read_write_permission(view, edit, {:role => "accountant", :right => :acc_manage_queues, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  def index
    redirect_to :action => :list and return false
  end

  #Shows the list of queues. Accountant needs "Manage Queues" permissions
  def list
    @page_title = _('Queues')

    session[:queues_list_options] ? @options = session[:queues_list_options] : @options = {}

    # search
    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])

    # order
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (@options[:order_by] = "name" if !@options[:order_by])

    order_by = queues_order_by(params, @options)

    total_queues = AstQueue.count
    # page params
    @total_queues_size = total_queues.to_i
    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @total_pages = (@total_queues_size.to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    @page = @options[:page]
    @fpage = ((@options[:page] -1) * session[:items_per_page]).to_i

    @search = @options[:s_name].blank? ? 0 : 1

    @queues = AstQueue.order(order_by).limit("#{@fpage}, #{session[:items_per_page].to_i}").all

    session[:queues_list_options] = @options
  end

  def new
    @page_title = _('New_queue')
  end

  def edit
    @page_title = _('Queue_edit')
    @page_icon = "group.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Call_Queues"

    @dialplan = Dialplan.where(:data1 => @queue.id).first
    @assigned_dids = Did.where(:dialplan_id => @dialplan.id)
    @servers = Server.where("server_type = 'asterisk'").order('id ASC').all
    @queue_strategies = ['ringall','roundrobin','leastrecent','fewestcalls','random','rrmemory','wrandom','linear','rrordered']
    if @queue.failover_action.to_s == "device"
      @device = Device.where(:id => @queue.failover_data.to_i).first
      @user = @device.user
      @devices = Device.where(:user_id => @user.id).all
    else
      @user = nil
      @devices = []
      @device = nil
    end
    if @queue.failover_action.to_s == "did"
      @did = Did.where(:id => @queue.failover_data).first
    end

    @announcements = IvrSoundFile.select('id, path').all
    @static_agents = QueueAgent.where(:queue_id => @queue.id).order("priority").all
    @mohs = Moh.all
    @ivrs = Ivr.all
    @join_leave_empty = ['paused','penalty','inuse','ringing','unavailable','invalid','unknown','wrapup']
    @periodic_announcements = QueuePeriodicAnnouncement.select("queue_periodic_announcements.id AS id,ivr_sound_files.path AS path").joins("LEFT JOIN ivr_sound_files ON (ivr_sound_files.id = queue_periodic_announcements.ivr_sound_files_id)").where(:queue_id => @queue.id).order("priority").all

    # ===== Visualization =====

    if @queue.join_announcement.to_i == 0
      @vis_join_ann = 'none'
    else
      @vis_join_ann = IvrSoundFile.where(:id => @queue.join_announcement.to_i).first
      @vis_join_ann = @vis_join_ann.blank? ? '' : @vis_join_ann.path.to_s
    end
    a = Moh.select('ivr_sound_files.path AS path').joins("LEFT JOIN ivr_sound_files ON (ivr_sound_files.id = mohs.ivr_voice_id)").where(:id => @queue.moh_id).first
    @vis_moh = a.blank? ? "default" : a.path.to_s

    fail_over_action = @queue.failover_action.to_s
    if fail_over_action == 'hangup'
      @vis_fail_over = _('Hangup')
    elsif fail_over_action == 'extension'
      @vis_fail_over = _('Transfer_to_extension') + ": " + @queue.failover_data.to_s
    elsif fail_over_action == 'did'
      @vis_fail_over = _('Transfer_to_DID') + ": " + Did.where(:id => @queue.failover_data.to_i).first.did
    elsif fail_over_action == 'device'
      dev = Device.where(:id => @queue.failover_data.to_i).first
      d = dev.device_type + "/"
      d += dev.name if dev.device_type != "FAX"
      d += dev.extension if dev.device_type == "FAX" or dev.name.length == 0
      @vis_fail_over = _('Transfer_to_device') + ": " + d
    end
    a = Ivr.where(:id => @queue.context.to_i).first
    @vis_ivr = a.blank? ? "none" : a.name.to_s
  end

  # updating queue, and dialplan of that queue
  def update
    @page_title = _('Queue_edit')
    @page_icon = "group.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Call_Queues"

    if params[:queue].blank?
      dont_be_so_smart
      redirect_to :root and return false
    end

    errors = 0
    params[:queue][:join_announcement] = 0 if params[:queue][:join_announcement].to_i == -1
    params[:queue][:moh_id] = 0 if params[:queue][:moh_id].to_i == -1
    params[:queue][:context] = 0 if params[:queue][:context].to_i == -1
    params[:queue][:maxlen] = 0 if params[:queue][:maxlen].to_i == 0
    params[:queue][:failover_data] = params[:s_device].to_i if params[:queue][:failover_action].to_s == "device"
    did = Did.where(:did => params[:s_did_pattern].to_i).first
    if params[:queue][:failover_action].to_s == "did"
      if did
        params[:queue][:failover_data] = did.id
      else
        params[:queue][:failover_data] = params[:s_did_pattern]
        errors += 1
      end
    end

    params[:queue][:joinempty] = params[:join_empty] ? params[:join_empty].join(",") : ""
    params[:queue][:leavewhenempty] = params[:leave_empty] ? params[:leave_empty].join(",") : ""

    @queue_old = @queue.dup
    @queue.attributes = params[:queue]
    @queue.valid?

    #checking for extension validation
    if extension_exists?(params[:queue][:extension], @queue_old.extension)
      @queue.errors.add(:extension_error, _('Extension_is_used'))
    end

    if !@queue.errors.any? and errors == 0 and @queue.update_attributes(params[:queue])

      dial_plan = Dialplan.where(:name => @queue_old.name, :dptype => 'queue', :data1 => @queue.id, :data2 => @queue_old.extension).first
      dial_plan.data2 = params[:queue][:extension].to_s if params[:queue][:extension]
      dial_plan.name = params[:queue][:name].to_s if params[:queue][:name]
      dial_plan.save if params[:queue][:extension] or params[:queue][:name]

      server = Server.where(:id => @queue.server_id, :server_type => 'asterisk').first

      begin
        server.ami_cmd('queue reload all')
        server.ami_cmd('dialplan reload')
      rescue => e
        MorLog.my_debug e.to_yaml
      end

      flash[:status] = _('Queue_Updated')
      redirect_to :action => "list" and return false
    else
      if params[:queue][:failover_action].to_s == "did"
        if did.blank?
          @queue.errors.add(:did, _('Fail_Over_did_not_found'))
        end
      end

      @queue.attributes = params[:queue]
      @dialplan = Dialplan.where(:data1 => @queue.id).first
      @assigned_dids = Did.where(:dialplan_id => @dialplan.id)
      @servers = Server.where("server_type = 'asterisk'").order('id ASC').all
      @queue_strategies = ['ringall','roundrobin','leastrecent','fewestcalls','random','rrmemory','wrandom','linear','rrordered']
      @users = User.select("id, username, first_name, last_name, usertype, #{SqlExport.nice_user_sql}").where("users.usertype = 'user' AND users.owner_id = #{corrected_user_id}").order("nice_user")
      if @queue.failover_action.to_s == "device"
        @device = Device.where(:id => @queue.failover_data.to_i).first
        @user = @device.user
        @devices = Device.where(:user_id => @user.id).all
      else
        @user = @users.first
        @devices = @user.devices
      end
      if @queue.failover_action.to_s == 'did'
        @did = Did.where(:id => @queue.failover_data).first
      end
      @announcements = IvrSoundFile.select('id, path').all
      @static_agents = QueueAgent.where(:queue_id => @queue.id).order('priority').all
      static_agents_exists = @static_agents.blank?

      agent_devices = static_agents_exists ? [] : Device.where("id in (#{@static_agents.map(&:device_id).join(',')})")
      @static_agent_users = @users.reject {|user| ((user.devices.blank? ? [] : user.devices.map(&:id)) - agent_devices.map(&:id)).blank?}
      @static_agent_user_devices = @static_agent_users.first ? @static_agent_users.first.devices : []
      @static_agent_devices = static_agents_exists ? (@static_agent_user_devices ? @static_agent_user_devices : []) : (@static_agent_user_devices.reject { |dev| @static_agents.map(&:device_id).member?(dev.id) })
      @mohs = Moh.all
      @ivrs = Ivr.all
      @join_leave_empty = ['paused','penalty','inuse','ringing','unavailable','invalid','unknown','wrapup']
      @periodic_announcements = QueuePeriodicAnnouncement.select("queue_periodic_announcements.id AS id,ivr_sound_files.path AS path").joins("LEFT JOIN ivr_sound_files ON (ivr_sound_files.id = queue_periodic_announcements.ivr_sound_files_id)").where(:queue_id => @queue.id).order("priority").all

      # ===== Visualization =====

      if @queue.join_announcement.to_i == 0
        @vis_join_ann = 'none'
      else
        @vis_join_ann = IvrSoundFile.where(:id => @queue.join_announcement.to_i).first.try(:path) || ""
      end
      moh = Moh.select("ivr_sound_files.path AS path").joins("LEFT JOIN ivr_sound_files ON (ivr_sound_files.id = mohs.ivr_voice_id)").where(:id => @queue.moh_id).first
      @vis_moh = moh.blank? ? "default" : moh.path.to_s
      fail_over_action = @queue.failover_action.to_s

      if fail_over_action == 'hangup'
        @vis_fail_over = _('Hangup')
      elsif fail_over_action == 'extension'
        @vis_fail_over = _('Transfer_to_extension') + ": " + @queue.failover_data.to_s
      elsif fail_over_action == 'did'
        d = Did.where(:id => @queue.failover_data.to_i).first
        @vis_fail_over = _('Transfer_to_DID') + ": " + (d ? d.did : "")
      elsif fail_over_action == 'device'
        dev = Device.where(:id => @queue.failover_data.to_i).first
        d = dev.device_type + "/"
        d += dev.name if dev.device_type != "FAX"
        d += dev.extension if dev.device_type == "FAX" or dev.name.length == 0
        @vis_fail_over = _('Transfer_to_device') + ": " + d
      end

      ivr = Ivr.where(:id => @queue.context.to_i).first
      @vis_ivr = ivr.blank? ? 'none' : ivr.name.to_s
      flash_errors_for(_('Queue_was_not_updated'), @queue)
      render :action => 'edit', :id => @queue.id
    end
  end

  # creating queue, after_create - create
  def create

    @queue = AstQueue.new(params[:queue])

    #checking for extension validation
    if extension_exists?(params[:queue][:extension])
      @queue.errors.add(:extension_error, _('Extension_is_used'))
    end

    if !@queue.errors.any? and @queue.save
      server = Server.where(:id => @queue.server_id, :server_type => 'asterisk').first

      begin
        server.ami_cmd('queue reload all')
        server.ami_cmd('dialplan reload')
      rescue => e
        MorLog.my_debug e.to_yaml
      end

      flash[:status] = _('Queue_created')
      redirect_to :action => :edit, :id => @queue.id
    else
      flash_errors_for(_('Queue_was_not_created'), @queue)
      redirect_to :action => :new
    end
  end

  def destroy
    @queue.destroy_all
    flash[:status] = _('Queue_deleted')
    redirect_to :action => :list
  end

  def get_user_devices
    @devices = Device.where(:user_id => params[:user_id]).all
    render :layout => false
  end

  def agent_get_user_devices
    @agents = QueueAgent.where(:queue_id => params[:queue_id])
    @static_agent_user_devices = Device.where(:user_id => params[:user_id])
    @static_agent_devices = @agents.blank? ? (@static_agent_user_devices ? @static_agent_user_devices : []) : (@static_agent_user_devices.reject { |dev| @agents.map(&:device_id).member?(dev.id) })
    render :layout => false
  end

  def agent_get_users
    @users = User.select("id, username, first_name, last_name, usertype, #{SqlExport.nice_user_sql}").where("users.usertype = 'user' AND users.owner_id = #{corrected_user_id}").order("nice_user")
    @agents = QueueAgent.where(:queue_id => params[:queue_id])
    agent_devices = @agents.blank? ? [] : Device.where("id in (#{@agents.map(&:device_id).join(',')})")
    @static_agent_users = @users.reject {|user| ((user.devices.blank? ? [] : user.devices.map(&:id)) - agent_devices.map(&:id)).blank?}
    render :layout => false
  end

  def create_queue_agent

    last_agent = QueueAgent.where(:queue_id => params[:queue_id].to_i).order('priority DESC').first

    @agent = QueueAgent.new({
        agent_name: params[:agent_name].to_s,
        queue_id: params[:queue_id].to_i,
        device_id: params[:device_id].to_i,
        penalty: params[:penalty].to_i,
        priority: (last_agent.present? ? last_agent.priority.to_i + 1 : 1) ,
        paused: 0
    })
    if @agent.save
      @queue = AstQueue.where(:id => params[:queue_id]).first
      @static_agents = QueueAgent.where(:queue_id => @queue.id).order('priority').all
    end

    render :partial => 'queue_agents', :locals => {static_agents: @static_agents, queue: @queue}, :layout => false and return false
  end

  def change_position
    @queue_agent = QueueAgent.where(:id => params[:agent_id]).first
    @queue_agent.move_queue_agent(params[:direction])
    @queue = AstQueue.where(:id => params[:queue_id]).first
    @static_agents = QueueAgent.where(:queue_id => @queue_agent.queue_id).order('priority').all
    render :partial => 'queue_agents', locals: {static_agents: @static_agents, queue: @queue}, :layout => false
  end

  def edit_queue_agent
    sql = "UPDATE queue_agents SET penalty = #{params[:penalty].to_i} WHERE id = #{params[:agent_id]};"
    ActiveRecord::Base.connection.update(sql)
    render :text => ''
  end

  def delete_queue_agent
    @queue_agent = QueueAgent.where(:id => params[:agent_id]).first
    QueueAgent.destroy(params[:agent_id].to_i)
    @queue = AstQueue.where(:id => params[:queue_id]).first
    @static_agents = QueueAgent.where(:queue_id => @queue_agent.queue_id).order('priority').all
    render :partial => 'queue_agents', locals: {static_agents: @static_agents, queue: @queue}, :layout => false
  end

  def change_announcement_position
    @queue_announcement = QueuePeriodicAnnouncement.where(:id => params[:id]).first
    @queue_announcement.move_announcement(params[:direction])
    @queue = AstQueue.where(:id => params[:queue_id]).first
    @periodic_announcements = QueuePeriodicAnnouncement.select('queue_periodic_announcements.id AS id,ivr_sound_files.path AS path').joins('LEFT JOIN ivr_sound_files ON (ivr_sound_files.id = queue_periodic_announcements.ivr_sound_files_id)').where(:queue_id => @queue.id).order('priority').all
    render :partial => 'queue_announcements', locals: { queue: @queue, periodic_announcements: @periodic_announcements }, :layout => false
  end

  def create_new_announcement
    last_announcement = QueuePeriodicAnnouncement.where(:queue_id => params[:queue_id].to_i).order('priority DESC').first

    @announcement = QueuePeriodicAnnouncement.new({
        queue_id: params[:queue_id].to_i,
        ivr_sound_files_id: params[:ivr_sound_file_id].to_i,
        priority: (last_announcement.present? ? last_announcement.priority.to_i + 1 : 1)
    })
    if @announcement.save
      @queue = AstQueue.where(:id => params[:queue_id]).first
      @periodic_announcements = QueuePeriodicAnnouncement.select("queue_periodic_announcements.id AS id,ivr_sound_files.path AS path").joins("LEFT JOIN ivr_sound_files ON (ivr_sound_files.id = queue_periodic_announcements.ivr_sound_files_id)").where(:queue_id => @queue.id).order("priority").all
    end
    render :partial => "queue_announcements", locals: { queue: @queue, periodic_announcements: @periodic_announcements }, :layout => false
  end

  def delete_queue_announcement
    @queue_announcement = QueuePeriodicAnnouncement.where(:id => params[:id].to_i).first
    QueuePeriodicAnnouncement.delete(params[:id].to_i)
    @queue = AstQueue.where(:id => params[:queue_id]).first
    @periodic_announcements = QueuePeriodicAnnouncement.select("queue_periodic_announcements.id AS id,ivr_sound_files.path AS path").joins("LEFT JOIN ivr_sound_files ON (ivr_sound_files.id = queue_periodic_announcements.ivr_sound_files_id)").where(:queue_id => @queue.id).order("priority").all
    render :partial => 'queue_announcements', locals: { queue: @queue, periodic_announcements: @periodic_announcements }, :layout => false
  end

  def get_static_agents_map

    user_str = params[:livesearch].to_s

    static_agent_users = User.select("users.id, users.username, users.first_name, users.last_name, users.usertype, #{SqlExport.nice_user_sql}").
                              joins("INNER JOIN devices ON devices.user_id = users.id LEFT JOIN queue_agents ON queue_agents.device_id = devices.id AND queue_id = #{params[:options][:queue_id].to_i}").
                              where("queue_agents.device_id IS NULL AND users.usertype = 'user' AND users.owner_id = #{corrected_user_id} #{Application.find_like_user_sql(user_str)} ")

    static_agent_count = static_agent_users.count('DISTINCT users.id')

    static_agent_users = static_agent_users.order('nice_user').group('users.id')

    output = Application.seek_by_filter_sql(static_agent_users, static_agent_count, params[:empty_click].to_s, user_str)

    render(text: output)
  end

  private

  def queues_order_by(params, options)

    case options[:order_by].to_s.strip
    when 'name'
      order_by = 'queues.name'
    when 'extension'
      order_by = 'queues.extension'
    when 'strategy'
      order_by = 'queues.strategy'
    else
      order_by = options[:order_by]
    end

    if order_by != ''
      order_by << (options[:order_desc].to_i == 0 ? ' ASC' : ' DESC')
    end
    return order_by
  end

  def find_queue
    @queue = AstQueue.where(:id => params[:id].to_i).first

    if @queue.blank?
      flash[:notice]=_('Queue_was_not_found')
      redirect_to :root and return false
    end
  end

  def check_pbx_addon
    if !pbx_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :root and return false
    end
  end

end
