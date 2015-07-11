# -*- encoding : utf-8 -*-
class DevicesController < ApplicationController
  layout 'callc'
  before_filter :access_denied, :only => [:user_device_edit], :if => lambda { session[:user_id] and not user? }
  before_filter :check_post_method, :only => [:create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_email, :only => [:pdffaxemail_edit, :pdffaxemail_update, :pdffaxemail_destroy]
  before_filter :find_fax_device, :only => [:pdffaxemail_add, :pdffaxemail_new]
  before_filter :find_device, :only => [:destroy, :device_edit, :device_update, :device_extlines, :device_dids,
    :try_to_forward_device, :device_all_details, :callflow, :callflow_edit, :user_device_edit, :user_device_update,
    :erase_ipaddr_fullcontact]
  before_filter :find_cli, :only => [:change_email_callback_status, :change_email_callback_status_device, :cli_delete,
    :cli_user_delete, :cli_device_delete, :cli_edit, :cli_update, :cli_device_edit, :cli_user_edit, :cli_device_update,
    :cli_user_update]
  before_filter :verify_params, :only => [:create]
  before_filter :check_callback_addon, :only => [:change_email_callback_status, :change_email_callback_status_device]
  before_filter :find_provider, :only => [:user_device_edit]
  before_filter :check_with_integrity, :only => [:create, :device_update, :device_edit, :show_devices]
  before_filter :check_pbx_addon, :only => [:callflow, :callflow_edit]
  before_filter :load_cli_params, :only => [:cli_new, :cli_add]
  before_filter :erase_ipaddr_fullcontact, :only => [:device_update]

  before_filter(:except => [:device_edit, :device_update]) { |object_instance|
    view = [:device_clis, :clis, :cli_edit]
    edit = [:cli_new, :cli_add, :clis_banned_status, :cli_device_add, :change_email_callback_status,
      :change_email_callback_status_device, :cli_delete, :cli_device_delete, :cli_update]
    allow_read, allow_edit = object_instance.check_read_write_permission(view, edit, {:role => 'accountant',
      :right =>  :acc_user_manage, :ignore => true})
    object_instance.instance_variable_set :@allow_read, allow_read
    object_instance.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter { |object_instance|
    view = [:index, :new, :edit, :device_edit, :show_devices, :device_extlines, :device_dids, :forwards,
      :group_forwards, :cli_edit, :device_clis, :clis, :device_all_details, :default_device, :get_user_devices]
    edit = [:create, :destroy, :device_update, :device_forward, :try_to_forward_device, :cli_new, :cli_add,
      :cli_device_add, :change_email_callback_status, :clis_banned_status, :change_email_callback_status_device,
      :cli_delete, :cli_device_delete, :cli_update, :cli_device_edit, :cli_device_update, :pdffaxemail_add,
      :pdffaxemail_new, :pdffaxemail_edit, :pdffaxemail_update, :pdffaxemail_destroy, :default_device_update,
      :assign_provider]
    allow_read, allow_edit = object_instance.check_read_write_permission(view, edit, {:role => "accountant",
      :right => :acc_device_manage, :ignore => true})
    object_instance.instance_variable_set :@allow_read, allow_read
    object_instance.instance_variable_set :@allow_edit, allow_edit
    true
  }

  def index
    redirect_to action: 'user_devices' and return false
  end

  def new
    @page_title, @page_icon = [_('New_device'), 'add.png']
    @ccl_active = ccl_active?

    check_reseller_conflines(User.where(id: session[:user_id]).first) if reseller?

    @user = User.where(id: params[:user_id]).first
    user = @user

    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to action: 'index' and return false
    end

    if ['admin', 'accountant', 'reseller'].include?(user.usertype)
      flash[:notice] = _('Deprecated_functionality') +
        " <a href='http://wiki.kolmisoft.com/index.php/Deprecated_functionality' target='_blank'><img alt='Help' " +
        "src='#{Web_Dir}/images/icons/help.png'/></a>".html_safe
      redirect_to :root and return false
    end

    check_owner_for_device(user)
    check_for_accountant_create_device

    device_type = Confline.get_value('Default_device_type', correct_owner_id)
    @device = Device.new(device_type: device_type, pin: new_device_pin)
    @devicetypes = Devicetype.load_types('dahdi' => allow_dahdi?, 'Virtual' => allow_virtual?)
    @device_type = device_type ||= 'SIP'
    @audio_codecs, @video_codecs = [audio_codecs, video_codecs]
    @devgroups = user.devicegroups
    @ip_first, @mask_first, @ip_second, @mask_second, @ip_third, @mask_third = @device.perims_split
    @qualify_time = (@device.qualify == 'no') ? 2000 : @device.qualify
    @pdffaxemails = []
    @new_device = true
    @fax_enabled = session[:fax_device_enabled]
  end

  def create
    sanitize_device_params_by_accountant_permissions
    user = User.where(:id => params[:user_id]).includes(:address).first

    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to action: 'index' and return false
    end

    params[:device][:pin] = session[:device][:pin] if session[:device] && session[:device][:pin]
    notice, par = Device.validate_before_create(current_user, user, params, allow_dahdi?, allow_virtual?)

    if !notice.blank?
      flash[:notice] = notice
      redirect_to :root and return false
    end

    fextension = free_extension()
    device = user.create_default_device({:device_ip_authentication_record => par[:ip_authentication].to_i,
      :description => par[:device][:description], :device_type => par[:device][:device_type],
      :dev_group => par[:device][:devicegroup_id], :free_ext => fextension, :secret => random_password(12),
      :username => fextension, :pin => par[:device][:pin]})

    @sip_proxy_server = Server.where("server_type = 'sip_proxy'").first
    device.set_server(device, ccl_active?, @sip_proxy_server, reseller?)
    device.set_ports(params[:port])
    device.adjust_insecurities(ccl_active?, params)
    device.comment = params[:device][:comment] if params[:device]

    if device.save
      device.create_server_relations(device, @sip_proxy_server, ccl_active?)
      flash[:status] = device.check_callshop_user(_('device_created'))
      # no need to create extensions, prune peers, etc when device is created, because user goes to edit window
      # and all these actions are done in device_update
    else
      flash_errors_for(_('device_not_created'), device)
      redirect_to controller: 'devices', action: 'show_devices', id: user.id and return false
    end

    redirect_to controller: 'devices', action: 'device_edit', id: device.id and return false
  end

  def edit
    @user = User.where(:id => params[:id]).first

    unless @user
      flash[:notice]=_('User_was_not_found')
      redirect_to :action => :index and return false
    end

    @ccl_active = ccl_active?
  end

  # in before filter : device (:find_device)
  def destroy
    @return_controller = "devices"
    @return_action = "show_devices"
    set_return_controller
    set_return_action

    user_id = @device.user_id
    return false unless check_owner_for_device(@device.user_id)

    notice = @device.validate_before_destroy(current_user, @allow_edit)
    if !notice.blank?
      flash[:notice] = notice
      redirect_to :controller => @return_controller, :action => @return_action, :id => @device.user_id and return false
    else
      @device.destroy_all
    end

    flash[:status] = _('device_deleted')
    redirect_to :controller => @return_controller, :action => @return_action, :id => user_id
  end

  #--------------

  def show_devices
    devices_title_and_icon
    @help_link = "http://wiki.kolmisoft.com/index.php/Devices"

    @user = User.where(["id = ? AND (owner_id = ? or users.id = ?)", params[:id], correct_owner_id, current_user_id])
                .includes(:devices).first
    user = @user

    unless user.try :is_user?
      flash[:notice] = _("User_not_found")
      redirect_to :root and return false
    end

    dev_owner = check_owner_for_device(user)
    return false unless dev_owner

    @return_controller = "users"
    @return_action = "list"
    set_return_controller
    set_return_action

    items_per_page = session[:items_per_page].to_i
    items_per_page = items_per_page < 1 ? 1 : items_per_page
    #incase items per page wouldn't be set or set to 0? we'd get 1. user can set items per page only to positive integer.
    #but using magic numbers is a bad thing. should minimal/default items per page be defined somewhere?
    total_items = user.devices.length
    total_pages = (total_items.to_d / items_per_page.to_d).ceil
    first_page = 1
    page_no = params[:page].to_i
    page_no = page_no < first_page ? first_page : page_no
    page_no = total_pages < page_no ? total_pages : page_no
    offset = total_pages < 1 ? 0 : items_per_page * (page_no -1)

    @devices = user.devices.limit(items_per_page).offset(offset)
    @page = page_no
    @total_pages = total_pages
    @provdevices = Device.
                   where(["devices.user_id = '-1' AND providers.user_id = ? AND providers.hidden = 0", current_user_id]).
                   joins("JOIN providers ON (providers.device_id = devices.id)").order("providers.name")

    store_location
  end


  # in before filter : device (:find_device)
  def device_edit
    @page_title, @page_icon = [_('device_settings'), 'edit.png']
    set_return_controller
    set_return_action

    if reseller?
      reseller = User.where(id: session[:user_id]).first
      check_reseller_conflines(reseller)
    end

    @user = @device.user
    return false unless check_owner_for_device(@user)

    if @device.name.to_s.match(/\Amor_server_\d+\z/)
      dont_be_so_smart
      redirect_to :root and return false
    end

    @device_type = @device.device_type
    device_type = @device_type
    @device_trunk = @device.trunk

    set_cid_name_and_number

    @server_devices = []
    @device.server_devices.each { |dev| @server_devices[dev.server_id] = 1 }

    @device_dids_numbers = @device.dids_numbers
    @device_cids = @device.cid_number
    @device_caller_id_number = @device.device_caller_id_number

    get_number_pools
    load_devicetypes

    @audio_codecs = @device.codecs_order('audio')
    @video_codecs = @device.codecs_order('video')
    @devgroups = @device.user.devicegroups
    get_locations
    @dids = @device.dids
    @all_dids = Did.forward_dids_for_select

    #-------multi server support------

    @asterisk_servers = Server.where("server_type = 'asterisk'").order('id ASC')
    @sip_proxy_server = [Server.where("server_type = 'sip_proxy'").first]

    set_servers(device_type)

    #------ permits --------
    @ip_first, @mask_first, @ip_second, @mask_second, @ip_third, @mask_third = @device.perims_split

    #------ advanced --------
    set_qualify_time
    @extension = @device.extension
    @fax_enabled = session[:fax_device_enabled]
    @pdffaxemails = @device.pdffaxemails
    @global_tell_balance = Confline.get_value('Tell_Balance').to_i
    @global_tell_time = Confline.get_value('Tell_Time').to_i

    #TP/OP related
    get_tariffs
    @routing_algorithms = [[_('LCR'), 'lcr'], [_('Quality'), 'quality'], [_('Profit'), 'profit'], [_('weight'), 'weight'], [_('Percent'), 'percent']]
    @routing_groups = RoutingGroup.all

    set_voicemail_variables(@device)

    render :device_edit_h323 if device_type == "H323"
  end

  # in before filter : device (:find_device)
  def device_update
    unless @allow_edit
      flash[:notice] = _('You_have_no_editing_permission')
      redirect_to :root and return false
    end

    unless params[:device]
      redirect_to :root and return false
    end

    # if higher than zero -> do not update device
    device_update_errors = 0

    change_pin = !(accountant? && session[:acc_device_pin].to_i != 2)
    change_opt_first = !(accountant? && session[:acc_device_edit_opt_1].to_i != 2)
    change_opt_second = !(accountant? && session[:acc_device_edit_opt_2].to_i != 2)
    change_opt_third = !(accountant? && session[:acc_device_edit_opt_3].to_i != 2)
    change_opt_fourth = !(accountant? && session[:acc_device_edit_opt_4].to_i != 2)

    return false unless check_owner_for_device(@device.user)
    @device_old = @device.dup

    @device.set_old_name

    params[:device][:description]=params[:device][:description].to_s.strip
    device_type = @device.device_type

    if ['SIP', 'IAX2'].include?(device_type)
      if params[:ip_authentication_dynamic].to_i > 0
        params[:dynamic_check]  = (params[:ip_authentication_dynamic].to_i == 2) ? 1 : 0
        params[:ip_authentication] = (params[:ip_authentication_dynamic].to_i == 1) ? 1 : 0
      else
        @device.username.blank? ? params[:ip_authentication] = 1 :  params[:dynamic_check] = 1
      end
    end

    device_type_is_sip = (device_type == 'SIP')
    device_type_is_H323 = (device_type == 'H323')
    devicce_type_is_iax = (device_type == 'IAX2')
    device_type_not_virtual = (device_type != 'Virtual')
    device_type_not_fax = (device_type != 'FAX')
    params[:ip_authentication] = 1 if device_type_is_H323

    load_devicetypes

    @devicetypes = @devicetypes.map { |devtipe| devtipe.name }
    @devicetypes << 'FAX'

    unless @devicetypes.include?(params[:device][:device_type].to_s)
      params[:device][:device_type] = device_type
    end

    if !params[:cid_number].blank? and !is_number? params[:cid_number] and params[:cid_number].to_s.strip != 'unknown'
      @device.errors.add(:cid_number_error, _('callerid_not_a_number'))
      device_update_errors += 1
    end

    if params[:add_to_servers].blank? &&
        params[:device][:server_id].blank? &&
        !reseller? && !([:SIP, :FAX, :IAX2, :Virtual].include?(device_type.try(:to_sym)) && ccl_active?)
      @device.errors.add(:add_to_servers_error, _('Please_select_server'))
      device_update_errors += 1
    end

    #============multi server support===========
    @asterisk_servers = Server.where("server_type = 'asterisk'").order('id ASC')
    @sip_proxy_server = [Server.where("server_type = 'sip_proxy'").first]

    set_servers(device_type)

    #========= Reseller device server ==========

    if reseller?
      if ccl_active? and params[:device][:device_type] == "SIP" # and params[:dynamic_check] == 1
        params[:add_to_servers] = @sip_proxy_server
      else
        first_srv = Server.first.id
        def_asterisk = Confline.get_value('Resellers_server_id').to_i
        if def_asterisk.to_i == 0
          def_asterisk = first_srv
        end
        params[:device][:server_id] = def_asterisk
      end
    end
    #===========================================

    change_pin == true ? params[:device][:pin]=params[:device][:pin].to_s.strip : params[:device][:pin] = @device.pin
    unless (accountant? and session[:acc_user_create_opt_7].to_i != 2) # can accountant change call_limit?
      if params[:call_limit]
        params[:device][:call_limit] = params[:call_limit].to_s.strip
        if params[:call_limit].to_i < 0
          params[:device][:call_limit] = 0
        end
      end
    end
    if !ccl_active?
      @device.server_id = params[:device][:server_id] if params[:device] && params[:device][:server_id]
    end

    #========================== check input ============================================

    #because block_callerid input may be disabled and it will not be sent in
    #params and setter will not be triggered and value from enabled wouldnt be
    #set to disabled, so i we have to set it here. you may call it a little hack
    params[:device][:block_callerid] = 0 if params[:block_callerid_enable].to_s == 'no'

    if device_type_not_virtual
      if params[:device][:extension]
        params[:device][:extension] = change_opt_first ? params[:device][:extension].to_s.strip : @device.extension
      end

      params[:device][:timeout] = params[:device_timeout].to_s.strip
    end

    device_is_dahdi = @device.is_dahdi?

    if !@new_device && device_type_not_virtual
      set_params_device_name(change_opt_second)

      unless device_is_dahdi
        params[:device][:secret] = change_opt_second ? params[:device][:secret].to_s.strip : @device.secret
      end
    end

    if !@new_device && device_type_not_fax
      if change_opt_third
        params[:cid_number] = params[:cid_number].to_s.strip
        params[:device_caller_id_number] = params[:device_caller_id_number].to_i
      else
        params[:device_caller_id_number] = 1
        params[:cid_number]= cid_number(@device.callerid)
      end

      params[:cid_name] = change_opt_fourth ? params[:cid_name].to_s.strip : nice_cid(@device.callerid)

      if device_type_not_virtual
        unless device_is_dahdi
          params[:host] = params[:host].to_s.strip
          params[:port] = params[:port].to_s.strip if @device.host != 'dynamic'

          if ccl_active? and device_type_is_sip #and (@device.host == "dynamic" or @device.host.blank?)
            qualify = 2000
            params[:qualify] = 'no'
            params[:qualify_time] = qualify
          else
            qualify =  params[:qualify_time].to_s.strip.to_i
            qualify = 2000 unless params[:qualify_time]

            if qualify < 500
              @device.errors.add(:qualify, _('qualify_must_be_greater_than_500'))
              device_update_errors += 1
            end

            params[:qualify_time] = qualify
          end
        end

        params[:callgroup]=params[:callgroup].to_s.strip
        params[:pickupgroup]=params[:pickupgroup].to_s.strip

        if @device.voicemail_box
          params[:vm_email]=params[:vm_email].to_s.strip
          params[:vm_psw]=params[:vm_psw].to_s.strip
        end

        unless device_is_dahdi
          [:ip_first, :ip_second, :ip_third, :mask_first, :mask_second, :mask_third].each do |var|
            params[var] = params[var].to_s.strip
          end

          if device_type_is_sip
            params[:fromuser]=params[:fromuser].to_s.strip if params[:fromuser]
            params[:fromdomain]=params[:fromdomain].to_s.strip if params[:fromdomain]
            params[:custom_sip_header] = params[:custom_sip_header].to_s.strip if params[:custom_sip_header]
          end
        end
      end

      params[:device][:tell_rtime_when_left]=params[:device][:tell_rtime_when_left].to_s.strip
      params[:device][:repeat_rtime_every]=params[:device][:repeat_rtime_every].to_s.strip
      params[:device][:qf_tell_time] = params[:device][:qf_tell_time].to_i
      params[:device][:qf_tell_balance] = params[:device][:qf_tell_balance].to_i
    end

    #============================= end  ============================================================
    if params[:device][:recording_to_email].to_i == 1 and params[:device][:recording_email].to_s.length == 0
      @device.errors.add(:recording_to_email_error, _('Recordings_email_should_be_set_when_send_recordings_to_email_is_YES'))
      device_update_errors += 1
    end

    if params[:device][:name] and params[:device][:name].to_s.scan(/[^\w\.\@\$\-]/).compact.size > 0
      @device.errors.add(:device_name_error, _('Device_username_must_consist_only_of_digits_and_letters'))
      device_update_errors += 1
    end

    @device, device_update_errors = Device.validate_ip_address_format(params, @device, device_update_errors, prov = 0)

    #ticket 5055. ip auth or dynamic host must checked
    if params[:dynamic_check].to_i != 1 and params[:ip_authentication].to_i != 1 and ['SIP', 'IAX2'].include?(device_type)
      if params[:host].to_s.strip.blank?
        @device.errors.add(:dynamic_check_error, _('Must_set_either_ip_auth_either_dynamic_host'))
        device_update_errors += 1
      else
        params[:ip_authentication] = '1'
      end
    end

    if params[:device][:extension] and extension_exists?(params[:device][:extension], @device_old.extension)
      @device.errors.add(:extension_error, _('Extension_is_used'))
      device_update_errors += 1
    end
      #pin
      if (Device.where(["id != ? AND pin = ?", @device.id, params[:device][:pin]]).first and params[:device][:pin].to_s != "")
        @device.errors.add(:pin_is_used_error, _('Pin_is_already_used'))
        device_update_errors += 1
      end
      if params[:device][:pin].to_s.strip.scan(/[^0-9]/).compact.size > 0
        @device.errors.add(:not_numeric_pin_error, _('Pin_must_be_numeric'))
        device_update_errors += 1
      end
      @device.device_ip_authentication_record = params[:ip_authentication].to_i
      params[:device] = params[:device].reject { |key, value| ['extension'].include?(key.to_s) } if current_user.usertype == 'reseller' and Confline.get_value('Allow_resellers_to_change_extensions_for_their_user_devices').to_i == 0
      if params[:device][:pin].blank? and current_user.usertype == 'reseller'
        params[:device][:pin] = @device.pin
      end

      @device.attributes = params[:device]
      # if reseller and location id == 1, create default location and set new location id
      if @device.location_id == 1 and reseller?
        @device.location_id = Confline.get_value("Default_device_location_id", current_user_id)
        @device.save
      end

      @device.name = '' if @device.name.include?('ipauth') and params[:ip_authentication].to_i == 0
      #do not leave empty name
      if @device.name.to_s.length == 0
        if @device.host.length > 0
          @device.name = @device.extension
        else
          @device.name = random_password(10)
        end
      end

      if params[:process_sipchaninfo].to_s == '1'
        @device.process_sipchaninfo = 1
      else
        @device.process_sipchaninfo = 0
      end

      if params[:save_call_log].to_s == '1'
        @device.save_call_log = 1
      else
        @device.save_call_log = 0
      end

      if params[:ip_authentication].to_s == '1'

        @device.username = ''
        @device.secret = ''
        if !@device.name.include?('ipauth')
          name = @device.generate_rand_name('ipauth', 8)
          while Device.where(['name= ? and id != ?', name, @device.id]).first
            name = @device.generate_rand_name('ipauth', 8)
          end
          @device.name = name
        end
      else
        @device.username = @device.name if !@device.virtual?
        if !@device_old.virtual? and @device.virtual?
          @device.check_device_username
        end
      end

      if (device_update_errors == 0) && device_type_not_fax
        @device.update_cid(params[:cid_name], params[:cid_number], true)
        @device.assign_attributes({
          cid_from_dids: params[:device_caller_id_number].to_i == 3 ? 1 : 0,
          control_callerid_by_cids: params[:device_caller_id_number].to_i == 4 ? params[:control_callerid_by_cids].to_i : 0,
          callerid_advanced_control: params[:device_caller_id_number].to_i == 5 ? 1 : 0
        })

        if admin?
          @device.callerid_number_pool_id = params[:device_caller_id_number].to_i == 7 ? params[:callerid_number_pool_id].to_i : 0
        end

        if device_type_is_sip
          @device.copy_name_to_number = params[:device_caller_id_number].to_i == 8 ? 1 : 0
        end
      end

      #================ codecs ===================

      @device.update_codecs_with_priority(params[:codec], false) if params[:codec]
      #============= PERMITS ===================
      if params[:mask_first]
        if !Device.validate_permits_ip([params[:ip_first], params[:ip_second], params[:ip_third], params[:mask_first], params[:mask_second], params[:mask_third]])
          @device.errors.add(:allowed_ip_is_not_valid_error, _('Allowed_IP_is_not_valid'))
          device_update_errors += 1
        else
          @device.permit = Device.validate_perims({:ip_first => params[:ip_first], :ip_second => params[:ip_second], :ip_third => params[:ip_third],
            :mask_first => params[:mask_first], :mask_second => params[:mask_second], :mask_third => params[:mask_third]})
        end
      end

      #------ advanced --------

      if params[:qualify] == 'yes'
        @device.qualify = params[:qualify_time]
        @device.qualify == '2000' if @device.qualify.to_i < 500
      else
        @device.qualify = 'no'
      end

      #------- Network related -------
      if !@new_device and device_type_is_H323 and
        params[:host].to_s.strip !~ /^\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b$/
        @device.errors.add(:invalid_ip_address_error, _('Invalid_IP_address'))
        device_update_errors += 1
      end

      @device.host = params[:host]
      @device.host = 'dynamic' if params[:dynamic_check].to_i == 1

      if @device.host != 'dynamic'
        @device.ipaddr = @device.host
      end

      # IAX2 Trunking Mode
      if device_type.downcase == 'iax2'
        @device.trunk = params[:iax2_trunking]
      end

      #ticket #4978, previuosly there was a validation to disallow ports lower than 100
      #we have doubts whether this made any sense. so user now can set port to any positive integer
      @device.port = params[:port] if params[:port]
      @device.port = Device::DefaultPort['IAX2'] if devicce_type_is_iax and not Device.valid_port? params[:port], device_type
      @device.port = Device::DefaultPort['SIP'] if device_type_is_sip and not Device.valid_port? params[:port], device_type
      @device.port = Device::DefaultPort['H323'] if device_type_is_H323 and not Device.valid_port? params[:port], device_type

      if ccl_active?
        if device_type_is_sip and params[:zero_port].to_i == 1
          @device.proxy_port = 0
        else
          @device.proxy_port = @device.port
        end
      else
        @device.proxy_port = @device.port
      end

      if params[:port].blank? and device_type_is_H323 and params[:zero_port].to_i == 1
        @device.port = 0
      end

      #------Trunks-------
      case params[:trunk].to_i
      when 0
        @device.istrunk = 0
        @device.ani = 0
      when 1
        @device.istrunk = 1
        @device.ani = 0
      when 2
        @device.istrunk = 1
        @device.ani = 1
      end


      if admin? or accountant?
        #------- Groups -------
        @device.callgroup = params[:callgroup]
        @device.pickupgroup = params[:pickupgroup]
      end

      #------- Advanced -------
      @device.fromuser = params[:fromuser]
      @device.fromuser = nil if !params[:fromuser] or params[:fromuser].length < 1

      @device.fromdomain = params[:fromdomain]
      @device.fromdomain = nil if !params[:fromdomain] or params[:fromdomain].length < 1
      @device.grace_time = params[:grace_time]

      @device.custom_sip_header = params[:custom_sip_header].blank? ? "" : params[:custom_sip_header]

      @device.forward_did_id = Did.select('id').where(["did = ?", params[:forward_did].to_s]).first.id rescue -1

      @device.adjust_insecurities(ccl_active?, params)

      # check for errors
      @device.host = 'dynamic' unless @device.host
      @device.transfer = 'no' unless @device.transfer
      @device.canreinvite = 'no' unless @device.canreinvite
      @device.port = '0' unless @device.port
      @device.ipaddr = '0.0.0.0' unless @device.ipaddr
      @device.timeout = 10 if @device.timeout.to_i < 10
      @device.tp_tariff_id = params[:device][:tp_tariff_id].to_i

      if params[:vm_email].present?
        if !Email.address_validation(params[:vm_email])
          @device.errors.add(:incorrect_email_error, _('Email_address_not_correct'))
          device_update_errors += 1
        end
      end

      @device.mailbox = @device.enable_mwi.to_i == 0 ? '' : @device.extension.to_s + '@default'
      ((@device.context) and (@device.op == 1)) ? @device.context = 'm2' : @device.context = 'mor_local'
      if device_update_errors == 0 and @device.save

        #----------server_devices table changes---------
        if ccl_active? && devicce_type_is_iax
          server_id = Server.where(id: params[:device][:server_id].to_i).first.try(:id)
          device_id = @device.id

          unless ServerDevice.where(server_id: server_id, device_id: device_id).first
            ServerDevice.where(device_id: device_id).destroy_all
            server_device = ServerDevice.new_relation(server_id, device_id)
            server_device.save
          end
        elsif ccl_active? && !([:FAX, :Virtual].include?(device_type.try(:to_sym)))
          @device.create_server_devices(params[:add_to_servers])
        elsif !ccl_active?
          @device.create_server_devices({params[:device][:server_id].to_s => '1'})
        end

  # ---------------------- VM --------------------
        old_vm = (vm = @device.voicemail_box).dup

        vm.email = params[:vm_email] if params[:vm_email]
        if !(accountant? and session[:acc_voicemail_password].to_i != 2)
          vm.password = params[:vm_psw]
        end

        sql = "UPDATE voicemail_boxes SET mailbox = '#{@device.extension}', email = '#{vm.email}', password = '#{vm.password}' WHERE uniqueid = #{vm.id}"
        ActiveRecord::Base.connection.update(sql)

        # cleaning asterisk cache when device details changes
        if (@device.name != @device.device_old_name) || (@device.server_id != @device.device_old_server)
            @device.sip_prune_realtime_peer(@device.device_old_name, @device.device_old_server)
        end

        conf_extensions = configure_extensions(@device.id, {:current_user => current_user})
        return false unless conf_extensions
        @devices_to_reconf = Callflow.where(:device_id => @device.id, :action => :forward, :data2 => 'local')
        @devices_to_reconf.each { |call_flow|
          if call_flow.data.to_i > 0
            conf_extensions = configure_extensions(call_flow.data.to_i, {:current_user => current_user})
            return false unless conf_extensions
          end
        }
        flash[:status] = _('phones_settings_updated')
        session_user_id = session[:user_id]

        # actions to report who changed what in device settings.
        if @device_old.pin != @device.pin
          Action.add_action_hash(session_user_id, {:target_id => @device.id, :target_type => "device",
            :action => :device_pin_changed, :data => @device_old.pin, :data2 => @device.pin})
        end

        if @device_old.secret != @device.secret
          Action.add_action_hash(session_user_id, {:target_id => @device.id, :target_type => "device",
            :action => :device_secret_changed, :data => @device_old.secret, :data2 => @device.secret})
        end

        if old_vm.password != vm.password
          Action.add_action_hash(session_user_id, {:target_id => @device.id, :target_type => "device",
            :action => :device_voice_mail_password_changed, :data => old_vm.password, :data2 => vm.password})
        end

        redirect_to :action => :show_devices, :id => @device.user_id and return false
      else
        flash_errors_for(_('Device_not_updated'), @device)

        @server_devices = params[:add_to_servers].respond_to?(:keys) ? params[:add_to_servers].keys.map(&:to_i) : []
        @user = @device.user
        @device_type = device_type
        @all_dids = Did.forward_dids_for_select

        @device_dids_numbers = @device.dids_numbers
        @device_cids = params[:cid_number].to_s
        @device_caller_id_number = params[:device_caller_id_number].to_i
        @cid_name = params[:cid_name].to_s.strip
        @cid_number = params[:cid_number].to_s.strip

        @devicetypes  = @device.load_device_types("dahdi" => allow_dahdi?, "Virtual" => allow_virtual?)
        @audio_codecs = audio_codecs
        @video_codecs = video_codecs

        @devgroups = @device.user.devicegroups
        get_locations

        @dids = @device.dids

        #------ permits --------

        @ip_first, @mask_first, @ip_second, @mask_second, @ip_third, @mask_third = @device.perims_split

        #------ advanced --------
        set_qualify_time

        @extension = @device.extension
        @fax_enabled = session[:fax_device_enabled]
        @pdffaxemails = @device.pdffaxemails

        @device_voicemail_box_email = params[:vm_email].to_s.strip
        @device_voicemail_box_password = params[:vm_psw].to_s.strip
        @device_enable_mwi = params[:device][:enable_mwi].to_i
        @device_voicemail_active = @device.voicemail_active
        @device_voicemail_box = @device.voicemail_box
        @fullname = params[:vm_fullname].to_s.strip

        get_number_pools

        #TP/OP related
        get_tariffs
        @routing_algorithms = [[_('LCR'), 'lcr'], [_('Quality'), 'quality'], [_('Profit'), 'profit'], [_('weight'), 'weight'], [_('Percent'), 'percent']]
        @routing_groups = RoutingGroup.all

        if device_type_is_H323
          render :device_edit_h323
        else
          render :device_edit
        end
      end
  end

  # in before filter : device (:find_device)
  def device_extlines
    @page_title = _('Ext_lines')
    @page_icon = 'asterisk.png'

    if !@extlines = @device.extlines
      @extlines = nil
    end

    @user = @device.user

    if params[:context] == :show
      render(:layout => false)
    end
  end

  # in before filter : device (:find_device)
  def device_dids
    @page_title = _('dids')
    @user = @device.user
    check_owner_for_device(@user)

    if !@dids = @device.dids
      @dids = nil
    end

    if params[:context] == :show
      render(:layout => false)
    end
  end

  def device_forward
    @page_title = _('Device_forward')
    @page_icon = 'forward.png'

    if params[:group]
      @group = Group.where(:id => params[:group]).first
      @devices = []
      for user in @group.users
        for device in user.devices
          @devices << device
        end
      end
    else
      @devices = Device.where("name not like 'mor_server_%'").order(:extension)
    end

    @device = Device.where(:id => params[:id]).first
    @user = @device.user
  end

  # in before filter : device (:find_device)
  def try_to_forward_device
    @fwd_to = params[:select_fwd]
    fwd_to = @fwd_to
    fwd_to_not_zero = (fwd_to != '0')
    can_fwd = true

    if fwd_to_not_zero
      #checking can we forward
      device = Device.where(id: fwd_to).first
      device_forward_to = device.forward_to
      device_to_forward = (device_forward_to == @device.id)
      can_fwd = false if device_to_forward

      while !(device_forward_to == 0 or device_to_forward)
        device = Device.where(id: device_forward_to).first
        can_fwd = false if device_to_forward
      end
    end

    device_name = _('device') + ' ' + @device.name.to_s + ' '

    if can_fwd
      if fwd_to_not_zero
        flash[:status] = device_name + _('forwarded_to') + ' ' + Device.where(id: fwd_to).first.name.to_s
      else
        flash[:status] = device_name + _('forward_removed')
      end

      @device.forward_to = fwd_to
      @device.save

      conf_extensions = configure_extensions(@device.id, {:current_user => current_user})
      return false unless conf_extensions
    else
      flash[:notice] = device_name + _('not_forwarded_close_circle')
    end

    redirect_to :action => :device_forward, :id => @device
  end

  def forwards
    @page_title = _('Forwards')
    @page_icon = 'forward.png'
    @devices = Device.where("user_id != 0 AND name not like 'mor_server_%'").order(:name)
  end

  def group_forwards
    @group = Group.where(:id => params[:id]).first
    @page_icon = 'forward.png'
    @page_title = _('Forwards') + ': ' + @group.name
    @devices = []

    for user in @group.users
      for device in user.devices
        @devices << device
      end
    end

    render :forwards
  end

  #============ CallerIDs ===============

  def user_device_clis
    @page_title = _('CallerIDs')
    @page_icon = "cli.png"

    unless user?
      dont_be_so_smart
      redirect_to :root and return false
    end

    @user = User.where(id: session[:user_id]).first
    @devices = @user.devices
    @clis = []

    @clis = Callerid.select("callerids.* , devices.user_id , devices.name, devices.device_type, devices.istrunk, ivrs.name as 'ivr_name'").
                     joins("JOIN devices on (devices.id = callerids.device_id)").
                     joins("LEFT JOIN ivrs on (ivrs.id = callerids.ivr_id)").
                     where("devices.user_id = '#{@user.id}'")

    @all_ivrs = Ivr.all
  end

  # in before filter : device (:find_device)
  def device_clis
    redirect_to :action => :clis, :device_id => params[:id] if params[:id]
  end

  def load_cli_params
    @selected = {
      :cli => '',
      :device_id => 0,
      :user => -1,
      :description => '',
      :ivr => -1,
      :comment => '',
      :banned => 0,
    }

    if params[:s_user].to_s == '' || %w[-2 -1].include?(params[:s_user_id].to_s)
      params[:s_user_id] = -1
      params[:device_id] = 0 unless params[:user].present?
    end

    cli = params[:cli]
    device_id = params[:device_id]
    user = params[:s_user_id]
    description = params[:description]
    ivr = params[:ivr]
    comment = params[:comment]
    banned = params[:banned]

    @selected[:cli] = cli if cli
    @selected[:device_id] = device_id if device_id
    @selected[:user] = user if user
    @selected[:description] = description if description
    @selected[:ivr] = ivr if ivr
    @selected[:comment] = comment if comment
    @selected[:banned] = banned if banned
  end

  def cli_new
    @page_title = 'CLI ' + _('Add')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/CLIs'

    correct_current_user_id

    @ivrs = Ivr.select("DISTINCT(callerids.ivr_id), ivrs.name, ivrs.id").
                joins("LEFT JOIN callerids ON (ivrs.id = callerids.ivr_id)").
                where(["ivrs.user_id = ?", @current_user_id])

    @all_ivrs = @ivrs
  end

  def cli_add
    @page_title = 'CLI ' + _('add')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/CLIs'

    correct_current_user_id

    @all_ivrs = Ivr.select("DISTINCT(callerids.ivr_id), ivrs.name, ivrs.id").
                joins("LEFT JOIN callerids ON (ivrs.id = callerids.ivr_id)").
                where(["ivrs.user_id = ?", @current_user_id])
    create_cli
    if flash[:status]
      redirect_to :action => :clis
    else
      render :cli_new
    end
  end

  def cli_device_add
    create_cli
    redirect_to :action => :clis, :id => params[:device_id] and return false
  end

  def cli_user_add
    create_cli
    redirect_to :action => :user_device_clis and return false
  end

  def change_email_callback_status
    Callerid.use_for_callback(@cli, params[:email_callback])
    redirect_to :action => :clis and return false
  end

  def change_email_callback_status_device
    Callerid.use_for_callback(@cli, params[:email_callback])
    redirect_to :action => :clis, :id => @cli.device_id and return false
  end

  def cli_delete
    cli_cli = @cli.cli
    @cli.destroy ? flash[:status] = _('CLI_deleted') + ": #{cli_cli}" : flash[:notice] = _('CLI_is_not_deleted') + '<br/>' + '* ' + _('CID_is_assigned_to_Device')
    redirect_to :action => :clis and return false
  end

  def cli_user_delete
    cli_cli = @cli.cli
    @cli.destroy
    flash[:status] = _('CLI_deleted') + ": #{cli_cli}"
    redirect_to :action => :user_device_clis and return false
  end

  def cli_device_delete
    cli_cli = @cli.cli
    device_id = @cli.device_id
    if @cli.destroy
      flash[:status] = _('CLI_deleted') + ": #{cli_cli}"
    else
      flash_errors_for(_('CLI_is_not_deleted'), @cli)
    end
    flash[:status] = _('CLI_deleted') + ": #{cli_cli}"
    redirect_to :action => :clis, :id => device_id and return false
  end

  def cli_edit
    @page_title = _('CLI_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/CLIs'
    @all_ivrs = Ivr.all
    @device = @cli.device
    #  check_owner_for_device(@device.user)
    @user = @device.user
    user = @user
    session_user_id = session[:user_id].to_i

    unless user && (user.id == session_user_id) || (user.owner_id == session_user_id) ||
      admin? || accountant? || reseller?
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def cli_update
    @page_title = _('CLI_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/CLIs'

    @device = @cli.device
    @user = @device.user
    @all_ivrs = Ivr.all

    @cli.assign_attributes(cli_attributes_to_assign)

    @cli.ivr_id = params[:ivr] if params[:ivr]

    if @cli.save
      Callerid.use_for_callback(@cli, params[:email_callback])
      flash[:status] = _('CLI_updated')
      redirect_to :action => :clis and return false
    else
      flash_errors_for(_("CLI_not_created"), @cli)
      render :cli_edit
    end

  end

  def cli_device_edit
    @page_title = _('CLI_edit')
    @page_icon = 'edit.png'

    @all_ivrs = Ivr.all
    @device = @cli.device
    @user = @device.user
    user = @user
    session_user_id = session[:user_id].to_i

    unless user && (user.id == session_user_id) || (user.owner_id == session_user_id) ||
      admin? || accountant?
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def cli_user_edit
    @page_title = _('CLI_edit')
    @page_icon = 'edit.png'
    @all_ivrs = Ivr.all
    @device = @cli.device
    @user = @device.user
    user = @user
    session_user_id = session[:user_id].to_i

    unless user && (user.id == session_user_id) || (user.owner_id == session_user_id) ||
      admin? || accountant?
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def cli_device_update
    @cli.assign_attributes(cli_attributes_to_assign)
    @cli.ivr_id = params[:ivr] if params[:ivr] and accountant_can_write?("cli_ivr")
    if @cli.save
      Callerid.use_for_callback(@cli, params[:email_callback])
      flash[:status] = _('CLI_updated')
      redirect_to :action => :clis, :id => @cli.device_id
    else
      flash_errors_for(_("CLI_not_created"), @cli)
      redirect_to :action => :cli_device_edit, :id => @cli.id
    end
  end

  def cli_user_update
    unless cli = Callerid.where(:id => params[:id]).first
      flash[:notice]=_('Callerid_was_not_found')
      redirect_to :action => :index and return false
    end

    cli.assign_attributes(cli_attributes_to_assign)
    cli.ivr_id = params[:ivr] if params[:ivr]

    if cli.save
      Callerid.use_for_callback(cli, params[:email_callback])
      flash[:status] = _('CLI_updated')
      redirect_to :action => :user_device_clis and return false
    else
      flash_errors_for(_("CLI_not_created"), cli)
      redirect_to :action => :cli_user_edit, :id => params[:id]
    end
  end

  def clis
    @page_title = _('CLIs')
    @page_icon = 'cli.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/CLIs'

    # clear form

    if params[:clear] == 'true'
      @searched = false
      session[:search] = nil
    end

    # order
    @options = session[:cli_list_options] ||= { order_by: 'cli', order_desc: 0 }
    @options[:order_by] = params[:order_by].to_s if params[:order_by]
    @options[:order_desc] = params[:order_desc].to_i if params[:order_desc]

    order_by = Device.clis_order_by(@options)

    session[:cli_list_options] = @options

    #search

    @search = session[:search] ||= { cli: '', device: -1, user: -1, banned: -1, email_callback: -1, ivr: -1,
                                     description: '', comment: '' }

    if params[:device_id] and params[:s_user_id].blank?
      dev = Device.where(id: params[:device_id]).first
      params[:s_user_id] = dev.user_id if dev
    end

    if params[:s_user].to_s == ''
      params[:s_user_id] = -1
      params[:device_id] = -1 unless params[:user_id].present?
    elsif %w[-2 -1].include?(params[:s_user_id].to_s)
      params[:s_user_id] = -2
      params[:device_id] = -1 unless params[:user_id].present?
    end

    search_user = @search[:user] = params[:s_user_id].to_s.strip if params[:s_user_id]
    search_user_not_equal_minus_one = (search_user.to_i != -1)
    @search[:cli] = params[:s_cli].to_s.strip if params[:s_cli]
    search_device = @search[:device] = params[:device_id].to_s.strip if params[:device_id]
    search_dev_not_equal_minus_one = (search_device.to_i != -1)
    @search[:banned] = params[:s_banned] if params[:s_banned]
    @search[:ivr] = params[:s_ivr] if params[:s_ivr]
    @search[:description] = params[:s_description].to_s.strip if params[:s_description]
    @search[:comment] = params[:s_comment].to_s.strip if params[:s_comment]
    @search[:email_callback] = params[:s_email_callback] if params[:s_email_callback]

    cond = ''
    session[:search] = @search

    if search_user_not_equal_minus_one
      cond += "  AND devices.user_id = '#{search_user}' "

      if search_dev_not_equal_minus_one
        cond += " AND callerids.device_id = '#{search_device}' "
      end
    end

    cond += " AND callerids.cli LIKE '#{@search[:cli]}' " if @search[:cli].length > 0
    cond += " AND callerids.banned =  '#{@search[:banned]}' " if @search[:banned].to_i != -1
    cond += " AND callerids.ivr_id =  '#{@search[:ivr]}' " if @search[:ivr].to_i != -1
    cond += " AND callerids.description LIKE '#{@search[:description]}%' " if @search[:description].length > 0
    cond += " AND callerids.comment LIKE  '#{@search[:comment]}%' " if @search[:comment].length > 0
    cond += " AND callerids.email_callback =  '#{@search[:email_callback]}' " if @search[:email_callback].to_i != -1

    correct_current_user_id

    @clis = Callerid.select("callerids.* , devices.user_id , devices.name, devices.extension, devices.device_type, devices.istrunk, ivrs.name as 'ivr_name'").
                     joins("JOIN devices on (devices.id = callerids.device_id)").
                     joins("JOIN users on (users.id = devices.user_id)").
                     joins("LEFT JOIN ivrs on (ivrs.id = callerids.ivr_id)").
                     where("callerids.id > 0 " << cond << " AND users.id = devices.user_id AND users.owner_id = #{@current_user_id}").order(order_by)

    @ivrs = Ivr.select("DISTINCT(callerids.ivr_id), ivrs.name, ivrs.id").
                joins("LEFT JOIN callerids ON (ivrs.id = callerids.ivr_id)").
                where(["ivrs.user_id = ?", @current_user_id])

    @all_ivrs = @ivrs

    @searched = 'true' if cond != ''

    @page = 1
    @page = params[:page].to_i if params[:page]

    @total_pages = (@clis.size.to_d / session[:items_per_page].to_d).ceil
    @all_clis = @clis
    @clis = []
    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_clis.size - 1 if iend > (@all_clis.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @clis << @all_clis[i]
    end
  end

  def clis_banned_status
    @cl = Callerid.where(:id => params[:id]).first
    @cl.assign_attributes({ banned: (@cl.banned.to_i == 1 ? 0 : 1)})
    @cl.created_at = Time.now unless @cl.created_at
    @cl.save
    redirect_to :action => :clis
  end

  def cli_user_devices
    @num = request.raw_post.to_s.gsub("=", "")
    @num = params[:id] if params[:id]
    @include_cli = params[:cli] if params[:cli]
    @devices = Device.where(["user_id = ? AND name not like 'mor_server_%' AND name NOT LIKE 'prov%'", @num]) if @num.to_i != -1
    @search_dev = params[:dev_id] if params[:dev_id]

    if params[:add]
      @add =1
    end

    @did = params[:did].to_i
    render :layout => false
  end

  def devices_all
    devices_title_and_icon
    @help_link = "http://wiki.kolmisoft.com/index.php/Devices"

    default_options = {}
    if params[:clean]
      @options = default_options
    else
      if session[:devices_all_options]
        @options = session[:devices_all_options]
      else
        @options = default_options
      end
    end
    #if new param was specified delete it from options,
    #else there might be leaved parameters that were saved in session
    @options.delete(:search_pinless) if params[:s_pinless]
    @options.delete(:search_pin) if params[:s_pin]

    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : @options[:order_desc].to_i
    @options[:order_by], order_by, default = devices_all_order_by(params, @options)

    params[:s_description] ? @options[:search_description] = params[:s_description].to_s : (@options[:search_description] = "" if !@options[:search_description])
    params[:s_extension] ? @options[:search_extension] = params[:s_extension].to_s : (@options[:search_extension] = "" if !@options[:search_extension])
    params[:s_username] ? @options[:search_username] = params[:s_username].to_s : (@options[:search_username] = "" if !@options[:search_username])
    params[:s_host] ? @options[:search_host] = params[:s_host].to_s.strip : (@options[:search_host] = "" if !@options[:search_host])
    @options[:search_cli] = params[:s_cli].to_s if params[:s_cli]

    #if pinless option is selected, than there shouldnt be pin parameter specified.
    #if pin was specified, then there shouldnt be pinless parameter.
    #so just in case we should delete options that shouldnt be there
    if params[:s_pinless]
      @options[:search_pinless] = params[:s_pinless]
      @options.delete(:search_pin)
    else
      pin = params[:s_pin].to_s.strip
      if pin.length > 0
        @options[:search_pin] = pin if pin =~ /^[0-9]+$/
      end
      @options.delete(:search_pinless)
    end

    @options[:search_description].to_s.length + @options[:search_extension].to_s.length+ @options[:search_username].to_s.length + @options[:search_cli].to_s.length > 0 ? @options[:search] = 1 : @options[:search] = 0
    set_options_page
    join = ["LEFT OUTER JOIN users ON users.id = devices.user_id"]
    cond = ["user_id != -1 AND devices.name not like 'mor_server_%'"]
    cond_par = []

    #if at least one valid seach option was entered
    #@search should be true
    @search = false

    if @options[:search_description].to_s.length > 0
      cond << "devices.description LIKE ?"
      cond_par << "%"+ @options[:search_description].to_s+"%"
      @search = true
    end

    if @options[:search_extension].to_s.length > 0
      cond << "devices.extension LIKE ?"
      cond_par << @options[:search_extension].to_s+"%"
      @search = true
    end

    if @options[:search_username].to_s.length > 0
      cond << "devices.username LIKE ?"
      cond_par << @options[:search_username].to_s + "%"
      @search = true
    end

    if @options[:search_host].to_s.length > 0
      cond << "devices.ipaddr LIKE ?"
      cond_par << @options[:search_host].to_s + "%"
      @search = true
    end

    if @options[:search_cli].to_s.length > 0
      join << "LEFT OUTER JOIN callerids ON devices.id = callerids.device_id"
      cond << "callerids.cli LIKE ?"
      cond_par << @options[:search_cli].to_s + "%"
      @search = true
    end

    if @options[:search_pinless]
      cond << "(devices.pin is NULL OR devices.pin = ?)"
      cond_par << ""
      @search = true
    else
      if @options[:search_pin]
        cond << "devices.pin LIKE ?"
        cond_par << @options[:search_pin].to_s + "%"
        @search = true
      end
    end

    cond << "users.hidden = 0"
    cond << "accountcode != 0"
    cond << "users.owner_id = ?"
    cond_par << session[:user_id]


    #grouping by device id is needed only when searching by cli. how to work around it withoud duplicating code?
    @total_pages = (Device.count(:all, :joins => join.join(" "), :conditions => [cond.join(" AND ")] + cond_par, :group => 'devices.id').size.to_d / session[:items_per_page].to_d).ceil
    options_page
    @options[:page] = 1 if @options[:page].to_i < 1

    @devices = Device.select("devices.*, IF(LENGTH(CONCAT(users.first_name, users.last_name)) > 0,CONCAT(users.first_name, users.last_name), users.username) AS 'nice_user'").
                           joins(join.join(" ")).
                           where([cond.join(" AND ")] + cond_par).
                           group('devices.id').
                           order(order_by).
                           offset(session[:items_per_page]*(@options[:page]-1)).
                           limit(session[:items_per_page])

    if default and (session[:devices_all_options] == nil or session[:devices_all_options][:order_by] == nil)
      @options.delete(:order_by)
    end
    session[:devices_all_options] = @options
  end

  # in before filter : device (:find_device)
  def device_all_details
    @page_title = _('Device_details')
    @page_icon = "view.png"

    @user = @device.user
    check_owner_for_device(@user)
  end

  # ------------------------------- C A L L F L O W ---------------------------
  # in before filter : device (:find_device)
  def callflow
    @page_title = _('Call_Flow')
    @page_icon = 'cog_go.png'
    device_user = @device.user
    session_user_id = session[:user_id]

    #security
    if user? or accountant?
      if session[:manager_in_groups].size == 0
        #simple user
        @user = User.where(id: session_user_id).first

        if user_is_not_device_owner
          dont_be_so_smart
          redirect_to :root
        end
      else
        #group manager
        @user = device_user

        can_check = false
        for group in session[:manager_in_groups]
          for user in group.users
            can_check = true if user.id == @user.id
          end
        end

        unless can_check
          dont_be_so_smart
          redirect_to :root
        end
      end
    end

    if reseller?
      @user = device_user

      if @user.owner_id != session_user_id and @user.id != session_user_id
        dont_be_so_smart
        redirect_to :root
      end
    end

    if admin?
      @user = device_user
    end

    device_id = @device.id
    @before_call_cfs = Callflow.where(:cf_type => 'before_call', :device_id => device_id).order(:priority)
    @no_answer_cfs = Callflow.where(:cf_type => 'no_answer', :device_id => device_id).order(:priority)
    @busy_cfs = Callflow.where(:cf_type => 'busy', :device_id => device_id).order(:priority)
    @failed_cfs = Callflow.where(:cf_type => 'failed', :device_id => device_id).order(:priority)

    if @before_call_cfs.empty?
      cf = create_empty_callflow(device_id, 'before_call')
      @before_call_cfs << cf
    end

    if @no_answer_cfs.empty?
      cf = create_empty_callflow(device_id, 'no_answer')
      @no_answer_cfs << cf
    end

    if @busy_cfs.empty?
      cf = create_empty_callflow(device_id, 'busy')
      @busy_cfs << cf
    end

    if @failed_cfs.empty?
      cf = create_empty_callflow(device_id, 'failed')
      @failed_cfs << cf
    end
  end

  # in before filter : device (:find_device)
  def callflow_edit
    @page_title, @page_icon = [_('Call_Flow'), 'edit.png']
    err = 0
    user_id = @device.user_id
    @user = @device.user
    @users, @devices = [[], []]
    session_user_id = session[:user_id]

    if user? or reseller?
      if user_id != session_user_id.to_i and user?
        dont_be_so_smart
        redirect_to :root and return false
      end
      if reseller? and (user_id != current_user_id and @user.owner_id != current_user_id)
        dont_be_so_smart
        redirect_to :root and return false
      end
    else
      return false unless check_owner_for_device(@user)
    end

    device_id = @device.id
    @dids = Did.where(device_id: device_id)
    @cf_type = params[:cft]
    @fax_enabled = session[:fax_device_enabled]

    whattodo = params[:whattodo]
    params_cf = params[:cf]
    params_s_user_id = params[:s_user_id]
    cf = Callflow.where(id: params_cf, device_id: @device).first if params_cf

    if !cf and params_cf
      flash[:notice]=_('Callflow_was_not_found')
      redirect_to :action => :index and return false
    end
    #MorLog.my_debug("CF :#{cf.to_s}" )
    case whattodo
      when "change_action"
        cf.assign_attributes({
          action: params[:cf_action],
          data: "",
          data2: "",
          data3: 1
        })
        cf.save
      when "change_local_device"
        params_cf_data = params[:cf_data].to_i

        if params_cf_data == 5
          if params[:s_device].present? && params[:s_device].to_s.downcase != "all"
            cf.assign_attributes({
              data: params[:s_device].to_i,
              data2: "local",
              data3: "",
            })
            cf.save if cf.data.to_i > 0
          else
            err=1
          end
        end

        if params_cf_data == 6
          params_ext_number = params[:ext_number].to_s

          if params_ext_number.to_i == @device.extension.to_i
            flash[:notice] = _('Devices_callflow_external_number_cant_match_extension')
            redirect_to :action => :callflow_edit, :id => device_id, :cft => @cf_type and return false
          end

          if params_ext_number.blank?
            flash[:notice] = _('Devices_callflow_external_number_cant_be_blank')
            redirect_to :action => :callflow_edit, :id => device_id, :cft => @cf_type and return false
          end

          cf.assign_attributes({
            data: params_ext_number.strip,
            data2: "external",
            data3: "",
          })

          cf.save
        end

        params_cf_data_third_string = params[:cf_data3].to_s
        params_cf_data_third = params_cf_data_third_string.to_i

        if params_cf_data_third < 5
          cf.data3 = params_cf_data_third_string

          if params_cf_data_third == 3
            params_did_id = params[:did_id]
            cf.data4 = params_did_id if params_did_id
          end

          if params_cf_data_third == 4
            params_cf_data_fourth = params[:cf_data4]
            cf.data4 = params_cf_data_fourth if params_cf_data_fourth.length > 0
          end

          if params_cf_data_third < 3
            cf.data4 = ''
          end

          cf.save #if cf
        end
      when "change_fax_device"
        cf.assign_attributes({
          data: params[:device_id].to_i,
          data2: "fax"
        })
        cf.save if cf.data.to_i > 0
      when "change_device_timeout"
        value = params[:device_timeout].to_i
        if value < 10
          value = 10
        end
        @device.timeout = value
        @device.save
    end

    if err.to_i == 0
      flash[:status] = _('Callflow_updated') if params[:whattodo] and params[:whattodo].length > 0

      @cfs = Callflow.where(:cf_type => @cf_type, :device_id => device_id).order(:priority)

      if @cfs.blank?
        flash[:notice]=_('Callflow_was_not_found')
        redirect_to :root and return false
      end

      if !admin? and !accountant?
        if user? and session[:manager_in_groups].size == 0
          #simple user
          @fax_devices = @user.fax_devices
        else
          #group manager or reseller can forward devices to same groups devices
          @fax_devices = Device.includes(:user).where(["(users.owner_id = ? OR users.id = ? ) AND devices.device_type = 'FAX' AND name not like 'mor_server_%'", session_user_id, session_user_id]).references(:user).order(:name)

          set_forward_devices

          for group in session[:manager_in_groups]
            for user in group.users
              for device in user.devices
                @devices << device unless @devices.include?(device)
              end
              for fdevice in user.fax_devices
                @fax_devices << fdevice unless @fax_devices.include?(fdevice)
              end
            end
          end
        end
      else
        #admin
        @fax_devices = Device.where("user_id != -1 AND device_type = 'FAX' AND name not like 'mor_server_%'").order(:name)

        set_forward_devices(set_nice_user_fw = true)
      end

      @devices = Device.where(user_id: params_s_user_id).all if params_s_user_id.present?
      if params[:whattodo] and params[:whattodo].to_s.length > 0
        conf_extensions = configure_extensions(device_id, {:current_user => current_user})
        return false if !conf_extensions
      end
    else
      flash[:notice]= _('Please_select_device')
      redirect_to :action => :callflow_edit, :id => device_id, :cft => @cf_type, s_user: params[:s_user], s_user_id: params_s_user_id and return false
    end
  end

  # ------------------------- User devices --------------

  def user_devices
    devices_title_and_icon

    unless user?
      dont_be_so_smart
      redirect_to :root and return false
    end

    @devices = current_user.devices
  end

  # in before filter : device (:find_device)
  def find_provider
    @provider = Provider.where(:device_id => @device.id).first
  end

  def user_device_edit
    @page_title = @provider ? _('Provider_settings') : _('device_settings')
    @page_icon = 'edit.png'
    @user = User.where(id: session[:user_id]).first
    user = @user
    @owner = User.where(id: user.owner_id).first

    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to :action => :index and return false
    end

    if user_is_not_device_owner
      dont_be_so_smart
      redirect_to :root and return false
    end

    if @device.device_type == "FAX"
      dont_be_so_smart
      redirect_to :root and return false
    end

    @dids = @device.dids
    set_cid_name_and_number
    @curr = current_user.currency
  end

=begin rdoc
 Update device data.

 *Params*

 +:id+ - Device_id
 other params

=end
  # in before filter : device (:find_device)
  def user_device_update
    @user = User.where(id: session[:user_id]).first

    if user_is_not_device_owner
      dont_be_so_smart
      redirect_to :root and return false
    end

    cid_name = params[:cid_name]
    cid_number = params[:cid_number]
    cid_number_from_did = params[:cid_number_from_did]

    if @device.device_type !="FAX" and (cid_name or cid_number or cid_number_from_did.try(:length).to_i > 0)
      cid_num = (cid_number_from_did.try(:length).to_i > 0) ? cid_number_from_did : cid_number
      @device.update_cid(cid_name, cid_num)
    end

    # CID control by DIDs (CID can be only from the set if DIDs)
    if params[:cid_from_dids] == '1'
      @device.update_cid('', '')
    end

    @device.assign_attributes({ cid_from_dids: params[:cid_from_dids].to_i,
                                description: params[:device][:description],
                                record: params[:device][:record].to_i,
                                recording_to_email: params[:device][:recording_to_email].to_i,
                                recording_email: params[:device][:recording_email],
                                recording_keep: params[:device][:recording_keep].to_i
                              })

    if @device.save
      flash[:status] = _('phones_settings_updated')
    else
      flash_errors_for(_("Update_Failed"), @device)
    end

    redirect_to :action => :user_devices and return false
  end

  # ------------------ PDF Fax Emails -----------------

  def pdffaxemail_add
    @page_title = _('Add_new_email')
    @page_icon = "add.png"

    @user = @device.user
  end

  def pdffaxemail_new
    if params[:new_pdffaxemail] and params[:new_pdffaxemail].length > 0 and Email.address_validation(params[:new_pdffaxemail])

      email = Pdffaxemail.new
      email.device = @device
      email.email = params[:new_pdffaxemail]
      email.save

      flash[:status] = _('New_email_added')
    else
      if !Email.address_validation(params[:new_pdffaxemail])
        flash[:notice] = _('Email_is_not_correct')
      else
        flash[:notice] = _('Please_fill_field')
      end
    end

    redirect_to :action => :device_edit, :id => @device
  end

  def pdffaxemail_edit
    @page_title = _('Edit_email')
    @page_icon = "edit.png"

    @device = @email.device
    @user = @device.user
  end

  def pdffaxemail_update
    if params[:email] and params[:email].length > 0 and Email.address_validation(params[:email])
      @email.email = params[:email]
      @email.save
      flash[:status] = _('Email_updated')
    else
      flash[:notice] = _('Email_not_updated')
    end

    redirect_to :action => :device_edit, :id => @email.device.id
  end

  def pdffaxemail_destroy
    email = @email.email
    device_id = @email.device_id
    @email.destroy

    flash[:status] = _('Email_deleted') + ": " + email
    redirect_to :action => :device_edit, :id => device_id
  end

  def default_device
    @page_title = _('Default_device')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Default_device_settings"
    session_user_id = session[:user_id]

    if reseller?
      reseller = User.where(id: session_user_id).first
      check_reseller_conflines(reseller)
      reseller.check_default_user_conflines
    end

    @device = Confline.get_default_object(Device, correct_owner_id)
    @devicetypes = Devicetype.load_types("dahdi" => allow_dahdi?, "Virtual" => allow_virtual?)
    @device_type = Confline.get_value("Default_device_type", session_user_id)
    @global_tell_balance = Confline.get_value('Tell_Balance').to_i
    @global_tell_time = Confline.get_value('Tell_Time').to_i

    if @device_type == 'FAX'
      @audio_codecs = Codec.select('codecs.*,  (conflines.value2 + 0) AS v2').
                            where("conflines.name like 'Default_device_codec%' and codecs.codec_type = 'audio' and codecs.name IN ('alaw', 'ulaw')").
                            joins("LEFT Join conflines ON (codecs.name = REPLACE(conflines.name, 'Default_device_codec_', '') and owner_id = #{session_user_id})").
                            order('v2')
    else
      @audio_codecs = Codec.select('codecs.*,  (conflines.value2 + 0) AS v2').
                            joins('LEFT Join conflines ON (codecs.name = REPLACE(conflines.name, "Default_device_codec_", ""))').
                            where(["conflines.name like 'Default_device_codec%' and codecs.codec_type = 'audio' and owner_id =?", session_user_id]).
                            order('v2')
    end

    @video_codecs = Codec.select('codecs.*, (conflines.value2 + 0) AS v2').
                          joins('LEFT Join conflines ON (codecs.name = REPLACE(conflines.name, "Default_device_codec_", ""))').
                          where(["conflines.name like 'Default_device_codec%' and codecs.codec_type = 'video' and owner_id =?", session_user_id]).
                          order('v2')

    @owner = session_user_id
    #if @device_type == 'IAX2' and !(['no','yes'].include?(Confline.get_value('Default_device_trunk', @owner).to_s))
    #  Confline.set_value('Default_device_trunk', 'no', @owner)
    #end

    @device_trunk = Confline.get_value('Default_device_trunk', @owner)
    get_locations
    @default = 1
    @cid_name = Confline.get_value("Default_device_cid_name", session_user_id)
    @cid_number = Confline.get_value("Default_device_cid_number", session_user_id)
    @qualify_time = Confline.get_value("Default_device_qualify", session_user_id)
    ddd = Confline.get_value("Default_setting_device_caller_id_number", session_user_id).to_i
    @device.cid_from_dids= 1 if ddd == 3
    @device.control_callerid_by_cids= 1 if ddd == 4
    @device.callerid_advanced_control= 1 if ddd == 5

    @device_dids_numbers = @device.dids_numbers
    @device_caller_id_number = @device.device_caller_id_number

    #-------multi server support------
    @sip_proxy_server = Server.where("server_type = 'sip_proxy'").limit(1).all
    @servers = Server.where("server_type = 'asterisk'").order('id ASC').all

    #@asterisk_servers = @servers
    if @sip_proxy_server.length > 0 and @device_type == "SIP"
      @servers = @sip_proxy_server
    end

    #------------ permits ------------

    @ip_first = ''
    @mask_first = ''
    @ip_second = ''
    @mask_second = ''
    @ip_third = ''
    @mask_third = ''

    data = Confline.get_value("Default_device_permits", session_user_id).split(';')

    if data[0]
      permit = data[0].split('/')
      @ip_first = permit[0]
      @mask_first = permit[1]
    end

    if data[1]
      permit = data[1].split('/')
      @ip_second = permit[0]
      @mask_second = permit[1]
    end

    if data[2]
      permit = data[2].split('/')
      @ip_third = permit[0]
      @mask_third = permit[1]
    end
    # @call_limit = confline("Default_device_call_limit")
    @user = User.new(:recording_enabled => 1)

    @fax_enabled = session[:fax_device_enabled]

    @device_voicemail_active = Confline.get_value("Default_device_voicemail_active", session_user_id)
    @device_voicemail_box = Confline.get_value("Default_device_voicemail_box", session_user_id)
    @device_voicemail_box_email = Confline.get_value("Default_device_voicemail_box_email", session_user_id)
    @device_voicemail_box_password = Confline.get_value("Default_device_voicemail_box_password", session_user_id)
    @fullname = ''
    @device_enable_mwi = Confline.get_value("Default_device_enable_mwi", session_user_id)
  end

  def default_device_update
    if params[:call_limit]
      params[:call_limit]= params[:call_limit].to_s.strip.to_i
      if params[:call_limit].to_i < 0
        params[:call_limit] = 0
      end
    end

    if params[:vm_email].to_s != ''
      if !Email.address_validation(params[:vm_email])
        flash[:notice] = _("Email_address_not_correct")
        redirect_to :action => :default_device and return false
      end
    end

    session_user_id = session[:user_id]

    Confline.set_value("Default_device_type", params[:device][:device_type], session_user_id)
    Confline.set_value("Default_device_dtmfmode", params[:device][:dtmfmode], session_user_id)
    Confline.set_value("Default_device_works_not_logged", params[:device][:works_not_logged], session_user_id)
    Confline.set_value("Default_device_location_id", params[:device][:location_id], session_user_id)
    Confline.set_value("Default_device_timeout", params[:device_timeout], session_user_id)

    Confline.set_value('Default_device_call_limit', params[:call_limit].to_i, session_user_id)
    Confline.set_value('Default_device_server_id', (reseller? ? Confline.get_value('Resellers_server_id').to_i : params[:device][:server_id].to_i), session_user_id) if params[:device] and params[:device][:server_id]
    Confline.set_value('Default_device_cid_name', params[:cid_name], session_user_id)
    Confline.set_value("Default_device_cid_number", params[:cid_number], session_user_id)
    Confline.set_value("Default_setting_device_caller_id_number", params[:device_caller_id_number].to_i, session_user_id)

    Confline.set_value("Default_device_nat", params[:device][:nat], session_user_id)

    Confline.set_value("Default_device_qualify_time", params[:qualify_time], session_user_id)


    Confline.set_value("Default_device_voicemail_active", params[:voicemail_active], session_user_id)
    Confline.set_value("Default_device_voicemail_box", 1, session_user_id)
    Confline.set_value("Default_device_voicemail_box_email", params[:vm_email], session_user_id)
    Confline.set_value("Default_device_voicemail_box_password", params[:vm_psw], session_user_id)

    Confline.set_value("Default_device_trustrpid", params[:device][:trustrpid], session_user_id)
    Confline.set_value("Default_device_sendrpid", params[:device][:sendrpid], session_user_id)

    if ["fec", "redundancy","none"].include? params[:device][:t38pt_udptl]
        params[:device][:t38pt_udptl] = "yes, " << params[:device][:t38pt_udptl]
    end

    Confline.set_value("Default_device_t38pt_udptl", params[:device][:t38pt_udptl], session_user_id)
    Confline.set_value("Default_device_promiscredir", params[:device][:promiscredir], session_user_id)
    Confline.set_value("Default_device_progressinband", params[:device][:progressinband], session_user_id)
    Confline.set_value("Default_device_videosupport", params[:device][:videosupport], session_user_id)

    Confline.set_value("Default_device_allow_duplicate_calls", params[:device][:allow_duplicate_calls], session_user_id)
    Confline.set_value("Default_device_tell_balance", params[:device][:tell_balance], session_user_id)
    Confline.set_value("Default_device_tell_time", params[:device][:tell_time], session_user_id)
    Confline.set_value("Default_device_tell_rtime_when_left", params[:device][:tell_rtime_when_left], session_user_id)
    Confline.set_value("Default_device_repeat_rtime_every", params[:device][:repeat_rtime_every], session_user_id)
    Confline.set_value("Default_device_fake_ring", params[:device][:fake_ring], session_user_id)
    lang = params[:device][:language].to_s.blank? ? 'en' : params[:device][:language].to_s
    Confline.set_value("Default_device_language", lang, session_user_id)
    Confline.set_value("Default_device_enable_mwi", params[:device][:enable_mwi].to_i, session_user_id)

    Confline.set_value("Default_device_qf_tell_time", params[:device][:qf_tell_time].to_i, session_user_id)
    Confline.set_value("Default_device_qf_tell_balance", params[:device][:qf_tell_balance].to_i, session_user_id)
    Confline.set_value("Default_device_trunk", params[:iax2_trunking], session_user_id) if params[:device][:device_type] == "IAX2" and !params[:iax2_trunking].blank?

    #============= PERMITS ===================
    if params[:mask_first]
      if !Device.validate_permits_ip([params[:ip_first], params[:ip_second], params[:ip_third], params[:mask_first], params[:mask_second], params[:mask_third]])
        flash[:notice] = _('Allowed_IP_is_not_valid')
        redirect_to :action => :default_device and return false
      else
        Confline.set_value("Default_device_permits", Device.validate_perims({:ip_first => params[:ip_first], :ip_second => params[:ip_second], :ip_third => params[:ip_third], :mask_first => params[:mask_first], :mask_second => params[:mask_second], :mask_third => params[:mask_third]}), session_user_id)
      end
    end

    #------ advanced --------

    if params[:qualify] == "yes"
      if ccl_active? and params[:device][:device_type] == "SIP"
        Confline.set_value("Default_device_qualify", "no", session_user_id)
      else
        Confline.set_value("Default_device_qualify", params[:qualify_time], session_user_id)
        Confline.set_value("Default_device_qualify", "1000", session_user_id) if params[:qualify_time].to_i <= 1000
      end
    else
      Confline.set_value("Default_device_qualify", "no", session_user_id)
    end
    Confline.set_value("Default_device_use_ani_for_cli", params[:device][:use_ani_for_cli], session_user_id)
    Confline.set_value("Default_device_encryption", params[:device][:encryption], session_user_id) if params[:device][:encryption]
    Confline.set_value("Default_device_block_callerid", params[:device][:block_callerid].to_i, session_user_id)
    #------- Network related -------
    Confline.set_value("Default_device_host", params[:host], session_user_id)
    Confline.set_value("Default_device_host", "dynamic", session_user_id) if params[:dynamic_check] == "1"

    if Confline.get_value("Default_device_host", session_user_id) != "dynamic"
      Confline.set_value("Default_device_ipaddr", Confline.get_value("Default_device_host", session_user_id), session_user_id)
    else
      Confline.set_value("Default_device_ipaddr", "", session_user_id)
    end

    Confline.set_value("Default_device_regseconds", params[:device][:canreinvite], session_user_id)
    Confline.set_value("Default_device_canreinvite", params[:device][:canreinvite], session_user_id)

    Confline.set_value("Default_device_cps_call_limit", params[:device][:cps_call_limit].to_i, session_user_id)
    Confline.set_value("Default_device_cps_period", params[:device][:cps_period].to_i, session_user_id)

    default_transport = 'udp'
    valid_transport_options = ['tcp', 'udp', 'tcp,udp', 'udp,tcp', 'tls']
    device_transport = params[:device][:transport].to_s
    transport = (valid_transport_options.include?(device_transport) ? device_transport.to_s : 'udp')
    Confline.set_value("Default_device_transport", transport, session_user_id)

    #time_limit_per_day can be positive integer or 0 by default
    #it should be entered as minutes and saved as minutes(cause
    #later it wil be assigned to device and device will convert to minutes..:/)
    time_limit_per_day = params[:device][:time_limit_per_day].to_i
    time_limit_per_day = (time_limit_per_day < 0 ? 0 : time_limit_per_day)
    Confline.set_value("Default_device_time_limit_per_day", time_limit_per_day, session_user_id)

    #----------- Codecs ------------------
    if params[:device][:device_type] == 'FAX' and (!params[:codec] or !(params[:codec][:alaw].to_i == 1 or params[:codec][:ulaw].to_i == 1))
      flash[:notice]=_("Fax_device_has_to_have_at_least_one_codec_enabled")
      redirect_to :action => :default_device and return false
    end
    if params[:codec]
      for codec in Codec.all
        if params[:codec][codec.name] == "1"
          Confline.set_value("Default_device_codec_#{codec.name}", 1, session_user_id)
        else
          #          my_debug "00000"
          #          my_debug params[:codec][codec.name]

          Confline.set_value("Default_device_codec_#{codec.name}", 0, session_user_id)
        end

      end
    else
      for codec2 in Codec.all
        Confline.set_value("Default_device_codec_#{codec2.name}", 0, session_user_id)

      end
    end
    #------Trunks-------
    if params[:trunk].to_i == 0
      Confline.set_value("Default_device_istrunk", 0, session_user_id)
      Confline.set_value("Default_device_ani", 0, session_user_id)
    end
    if params[:trunk].to_i == 1
      Confline.set_value("Default_device_istrunk", 1, session_user_id)
      Confline.set_value("Default_device_ani", 0, session_user_id)
    end
    if params[:trunk].to_i == 2
      Confline.set_value("Default_device_istrunk", 1, session_user_id)
      Confline.set_value("Default_device_ani", 1, session_user_id)
    end


    #------- Groups -------
    Confline.set_value("Default_device_callgroup", params[:callgroup], session_user_id)
    Confline.set_value("Default_device_callgroup", nil, session_user_id) unless params[:callgroup]

    Confline.set_value("Default_device_pickupgroup", params[:pickupgroup], session_user_id)
    Confline.set_value("Default_device_pickupgroup", nil, session_user_id) unless params[:pickupgroup]

    #------- Advanced -------


    Confline.set_value("Default_device_fromuser", params[:fromuser], session_user_id)
    Confline.set_value("Default_device_fromuser", nil, session_user_id) if !params[:fromuser] or params[:fromuser].length < 1

    Confline.set_value("Default_device_fromdomain", params[:fromdomain], session_user_id)
    Confline.set_value("Default_device_fromdomain", nil, session_user_id) if !params[:fromdomain] or params[:fromdomain].length < 1

    Confline.set_value("Default_device_grace_time", params[:grace_time], session_user_id)

    Confline.set_value("Default_device_custom_sip_header", params[:custom_sip_header], session_user_id) unless params[:custom_sip_header].blank?

    Confline.set_value("Default_device_insecure", nil, session_user_id)
    Confline.set_value("Default_device_insecure", "port", session_user_id) if params[:insecure_port] == "1" and params[:insecure_invite] != "1"
    Confline.set_value("Default_device_insecure", "port,invite", session_user_id) if params[:insecure_port] == "1" and params[:insecure_invite] == "1"
    Confline.set_value("Default_device_insecure", "invite", session_user_id) if params[:insecure_port] != "1" and params[:insecure_invite] == "1"
    Confline.set_value("Default_device_calleridpres", params[:device][:calleridpres].to_s, session_user_id)
    Confline.set_value("Default_device_change_failed_code_to", params[:device][:change_failed_code_to].to_i, session_user_id)
    Confline.set_value("Default_device_anti_resale_auto_answer", params[:device][:anti_resale_auto_answer].to_i, session_user_id)

    #recordings
    Confline.set_value("Default_device_record", params[:device][:record].to_i, session_user_id)
    Confline.set_value("Default_device_recording_to_email", params[:device][:recording_to_email].to_i, session_user_id)
    Confline.set_value("Default_device_recording_keep", params[:device][:recording_keep].to_i, session_user_id)
    Confline.set_value("Default_device_record_forced", params[:device][:record_forced].to_i, session_user_id)
    Confline.set_value("Default_device_recording_email", params[:device][:recording_email].to_s, session_user_id)

    Confline.set_value("Default_device_process_sipchaninfo", params[:process_sipchaninfo].to_i, session_user_id)
    Confline.set_value("Default_device_save_call_log", params[:save_call_log].to_i, session_user_id)
    tim_max = params[:device][:max_timeout].to_i
    Confline.set_value("Default_device_max_timeout", tim_max.to_i < 0 ? 0 : tim_max, session_user_id)
    # http://trac.kolmisoft.com/trac/ticket/4236
    # Confline.set_value("Default_device_allow_grandstreams", params[:device][:allow_grandstreams].to_i, session_user_id)

    Confline.set_value("Default_device_tell_rate", params[:device][:tell_rate].to_s, session_user_id)

    flash[:status]=_("Settings_Saved")
    redirect_to :action => :default_device and return false
  end


  def assign_provider
    device = Device.includes(:provider).where(["devices.id = ? AND providers.user_id = ?", params[:provdevice], current_user_id]).references(:provider).first

    if device
      @prov = device.provider
      device.description = @prov.name if @prov
      params_id = params[:id]
      device.user_id = params_id

      if device.save
        prov_id = @prov.id
        # if provider is assigned to user, that connection is saved in "server_devices" table
        @sp = Serverprovider.where(provider_id: prov_id).all
        sip_proxy_serv_id = Server.where(server_type: 'sip_proxy').first.try(:id)
        servers = Server.where(id: [@sp.collect(&:server_id)]) if @sp.present?

        @sp.each do |sp|
          if ccl_active? && (device.device_type == 'SIP')
            server_id = sip_proxy_serv_id
          else
            server_id = servers.select {|serv| serv.id == sp.server_id }.first.try(:id)
          end

          device_id = device.id
          server_dev = ServerDevice.new_relation(server_id, device_id)
          server_dev.save if ServerDevice.where(server_id: server_dev.server_id, device_id: device_id).first.nil?
        end
        ##------------------##
        flash[:status] = _('Provider_assigned')
        if Provider.joins(:device).where("providers.password = '#{@prov.password}' AND providers.login = '#{@prov.login}' AND providers.server_ip = '#{@prov.server_ip}' AND providers.port = '#{@prov.port}' AND providers.id != #{prov_id} AND providers.user_id = #{current_user_id} AND devices.user_id != #{params_id}").count > 0
          flash[:notice] = _('Avoid_routing_problems')
        end
      else
        flash_errors_for(_('Device_not_updated'), device)
      end
    else
      flash[:notice] = _('Provider_Not_Found')
    end
    redirect_to :action => :show_devices, :id => params_id
  end

  def get_user_devices
    owner_id = correct_owner_id
    @user = request.raw_post.gsub("=", "")

    if @user == 'all'
      @devices = Device.select("devices.*").
                        joins("LEFT JOIN users ON (users.id = devices.user_id)").
                        where(["users.owner_id = ? AND device_type != 'FAX' AND name not like 'mor_server_%'", owner_id])
    else
      @devices = Device.select("devices.*").
                        joins("LEFT JOIN users ON (users.id = devices.user_id)").
                        where(["users.owner_id = ? AND device_type != 'FAX' AND user_id = ? AND name not like 'mor_server_%'", owner_id, @user])
    end
    render :layout => false
  end

  def ajax_get_user_devices
    owner_id = correct_owner_id
    @user = params[:user_id] if params[:user_id] != -1
    @default = params[:default].to_i if params[:default]
    @fax = params[:fax]
    @add_all = params[:all] ||= false
    @none = params[:none] ||= false
    @add_name = params[:name] ||= false

    if (@user != 'all')
      cond = ["users.owner_id = ? AND name not like 'mor_server_%'"]
      var = [owner_id]
      cond, var = [["name not like 'mor_server_%'"], []]
      cond << "user_id = ?" and var << @user
      cond << "device_type != 'FAX'" if @fax == 'false'
      cond << "name not like 'mor_server_%'" if params[:no_server]
      cond << "user_id > -1" if params[:no_provider]
      @devices = Device.select("devices.*").
                        joins("LEFT JOIN users ON (users.id = devices.user_id)").
                        where([cond.join(" AND ")].concat(var))
    else
      @devices = []
    end

    render :layout => false
  end

  # A bit duplicate but this is the correct one (so far) implementation fo AJAX finder.
  def get_devices_for_search
    options ={}
    options[:include_did] = params[:did_search].to_i

    if params[:user_id] == "all"
      @devices = (admin? || accountant?) ? Device.find_all_for_select(nil, options) : Device.find_all_for_select(corrected_user_id, options)
    else
      @user = User.where(:id => params[:user_id]).first

      if @user && (admin? || accountant? || (@user.owner_id = corrected_user_id))
        @devices = params[:did_search].to_i == 0 ? @user.devices("device_type != 'FAX'")  : @user.devices("device_type != 'FAX'").select('devices.*').joins('JOIN dids ON (dids.device_id = devices.id)').group('devices.id').all
      else
        @devices = []
      end
    end

    render :layout => false
  end

  def devicecodecs_sort
    ctype = params[:ctype]
    codec_id = params[:codec_id]
    params_id = params[:id]

    if params_id.to_i > 0
      @device = Device.where(:id => params_id).first

      unless @device
        flash[:notice] = _('Device_was_not_found')
        redirect_back_or_default("/callc/main")
        return false
      end
      if codec_id
        if params[:val] == 'true'
          begin
            @device.devicecodecs.new({codec_id: codec_id}).save
          rescue
            #logger.fatal 'could not save codec, may be unique constraint was violated?'
          end
        else
          pc = Devicecodec.where(:device_id => params_id, :codec_id => codec_id).first
          pc.destroy if pc
        end
      end

      params["#{ctype}_sortable_list".to_sym].each_with_index do |i, index|
        item = Devicecodec.where(:device_id => params_id, :codec_id => i).first
        if item
          item.priority = index
          item.save
        end

      end
    else
      params["#{ctype}_sortable_list".to_sym].each_with_index do |i, index|
        codec = Codec.where(:id => i).first
        if codec
          val = params[:val] == 'true' ? 1 : 0
          codec_name = codec.name
          session_user_id = session[:user_id]
          Confline.set_value("Default_device_codec_#{codec_name}", val, session_user_id) if params[:val] and codec_id.to_i == codec.id
          Confline.set_value2("Default_device_codec_#{codec_name}", index, session_user_id)
        end
      end
    end
    render :layout => false
  end

  def devices_weak_passwords
    @page_title = _('Devices_with_weak_password')
    items_per_page = session[:items_per_page]

    session[:devices_devices_weak_passwords_options] ? @options = session[:devices_devices_weak_passwords_options] : @options = {}
    set_options_page
    @total_pages = (Device.where("LENGTH(secret) < 8 AND LENGTH(username) > 0 AND device_type != 'H323' AND username NOT LIKE 'mor_server_%'").count.to_d/items_per_page.to_d).ceil
    options_page
    @devices = Device.where("LENGTH(secret) < 8 AND LENGTH(username) > 0 AND device_type != 'H323' AND username NOT LIKE 'mor_server_%' AND user_id != -1").
                      limit(items_per_page).
                      offset(items_per_page*(@options[:page]-1))

    session[:devices_devices_weak_passwords_options] = @options
  end

  def insecure_devices
    @page_title = _('Insecure_Devices')
    #@page_icon = "edit.png"
    #@help_link = "http://wiki.kolmisoft.com/index.php/Default_device_settings"
    session[:devices_insecure_devices_options] ? @options = session[:devices_insecure_devices_options] : @options = {}
    set_options_page
    items_per_page = session[:items_per_page].to_d

    if ccl_active?
      @total_pages = (Device.where("host='dynamic' AND (insecure = 'port,invite' OR insecure='port' OR insecure='invite') AND device_type != 'SIP'").count.to_d/items_per_page).ceil
    else
      @total_pages = (Device.where("host='dynamic' AND (insecure = 'port,invite' OR insecure='port' OR insecure='invite')").count.to_d/items_per_page).ceil
    end

    options_page

    if ccl_active?
      @devices = Device.includes(:user).where("host='dynamic' AND (insecure = 'port,invite' OR insecure='port' OR insecure='invite') AND device_type != 'SIP'")
    else
      @devices = Device.includes(:user).where("host='dynamic' AND (insecure = 'port,invite' OR insecure='port' OR insecure='invite')")
    end

    session[:devices_insecure_devices_options] = @options
  end

  private

=begin
  ticket #5014 this logic is more suited to be in controller than in view.
  About exception - it might occur if device(but not provider's) has no voicemail_box.
  this would only mean that someone has corruped data.
=end
  def set_voicemail_variables(device)
    begin
      @device_voicemail_active = device.voicemail_active
      @device_voicemail_box = device.voicemail_box
      @device_voicemail_box_email = @device_voicemail_box.email
      @device_voicemail_box_password = @device_voicemail_box.password
      @fullname = @device_voicemail_box.fullname
      @device_enable_mwi = device.enable_mwi
    rescue NoMethodError
      flash[:notice] = _('Device_voicemail_box_not_found')
      redirect_to :root
    end
  end


  def check_reseller_conflines(reseller)
    if !Confline.where(["name LIKE 'Default_device_%' AND owner_id = ?", reseller.id]).first
      reseller.create_reseller_conflines
    end
  end

  def create_empty_callflow(device_id, cf_type)
    cf = Callflow.new({ device_id: device_id,
                        cf_type: cf_type,
                        priority: 1,
                        action: "empty"
                      })
    cf.save
    cf
  end


=begin rdoc
 Checks if accountant is allowed to create devices.
=end

  def check_for_accountant_create_device
    if accountant? and session[:acc_device_create] != 2
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

=begin rdoc
 Clears values accountant is not allowed to send.
=end
  def sanitize_device_params_by_accountant_permissions
    if accountant?
      params[:device] = params[:device].except(:pin) if session[:acc_device_pin].to_i != 2 if params[:device]
      params[:device] = params[:device].except(:extension) if session[:acc_device_edit_opt_1] != 2 if params[:device]
      if session[:acc_device_edit_opt_2] != 2 and params[:device]
        params[:device] = params[:device].except(:name)
        params[:device] = params[:device].except(:secret)
      end
      params = params.except(:cid_name) if session[:acc_device_edit_opt_3] != 2 if !params.blank?
      params = params.except(:cid_number) if session[:acc_device_edit_opt_4] != 2 if !params.blank?
    end
    params
  end

  def devices_all_order_by(params, options)
    case params[:order_by].to_s
      when "user"
        order_by = "nice_user"
      when "acc"
        order_by = "devices.id"
      when "description"
        order_by = "devices.description"
      when "pin"
        order_by = "devices.pin"
      when "type"
        order_by = "devices.device_type"
      when "extension"
        order_by = "devices.extension"
      when "username"
        order_by = "devices.name"
      when "secret"
        order_by = "devices.secret"
      when "cid"
        order_by = "devices.callerid"
      else
        default = true
        options[:order_by] ? order_by = options[:order_by] : order_by = "nice_user"
    end

    without = order_by
    options[:order_desc].to_i == 1 ? order_by += " DESC" : order_by += " ASC"
    order_by += ', devices.id ASC ' if !order_by.include?('devices.id')
    return without, order_by, default
  end

  def check_pbx_addon
    if !pbx_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :root and return false
    end
  end

  def find_fax_device
    @device = Device.where(:id => params[:id], :device_type => "FAX").first

    unless @device
      flash[:notice] = _('Device_was_not_found')
      redirect_back_or_default("/callc/main")
    end
  end

  def find_device
    unless (Device.where(:id => params[:id]).count == 1)
      flash[:notice] = _('Device_was_not_found')
      redirect_back_or_default("/callc/main")
    else
      @device = Device.where(:id => params[:id]).includes(:user, :dids).first
    end
  end

  def find_email
    @email = Pdffaxemail.where(:id => params[:id]).first

    unless @email
      flash[:notice] = _('Email_was_not_found')
      redirect_back_or_default("/callc/main")
    end
  end

  def find_cli
    @cli = Callerid.includes(:device).where(:id => params[:id]).first
    unless @cli
      flash[:notice]=_('Callerid_was_not_found')
      redirect_to :root and return false
    else
      check_cli_owner(@cli)
    end
  end

  def check_cli_owner(cli)
    device = cli.device
    user = device.user if device
    unless user and (user.owner_id == correct_owner_id or user.id == session[:user_id])
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def verify_params
    unless params[:device]
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def check_callback_addon
    unless callback_active?
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def create_cli
    cli = Callerid.new(:cli => params[:cli], :device_id => params[:device_id], :comment => params[:comment].to_s, :banned => params[:banned].to_i, :added_at => Time.now)
    cli.description = params[:description] if params[:description]
    cli.ivr_id = params[:ivr] if params[:ivr]

    if cli.save
      Callerid.use_for_callback(cli, params[:email_callback])
      flash[:status] = _('CLI_created')
    else
      flash_errors_for(_('CLI_not_created'), cli)
    end
  end


  def check_with_integrity
    session[:integrity_check] = Device.integrity_recheck_devices if current_user and  current_user.usertype.to_s == 'admin'
  end

  def erase_ipaddr_fullcontact
    if params[:device] and (params[:device][:name] != @device.name) and (params[:ip_authentication_dynamic].to_i == 2)
      @device.assign_attributes({ ipaddr: '',
                                  fullcontact: nil,
                                  reg_status: ''
                                })
      @device.save
    end
  end

  def allow_dahdi?
    session_device = session[:device]
    not reseller? or (session_device and session_device[:allow_dahdi] == true)
  end

  def allow_virtual?
    session_device = session[:device]
    not reseller? or (session_device and session_device[:allow_virtual] == true)
  end

  def set_options_page
    options_page = @options[:page]
    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !options_page or options_page <= 0)
  end

  def options_page
    @options[:page] = @total_pages.to_i if (@total_pages.to_i < @options[:page].to_i) && (@total_pages > 0)
  end

  def set_qualify_time
    @qualify_time = (@device.qualify == 'no') ? 2000 : @device.qualify
  end

  def user_is_not_device_owner
    @device.user_id != @user.id
  end

  def set_params_device_name(change_opt_second)
    params[:device][:name] = change_opt_second ? params[:device][:name].to_s.strip : @device.name
  end

  def correct_current_user_id
    @current_user_id = (current_user.usertype == 'accountant') ? 0 : current_user_id
  end

  def cli_attributes_to_assign
    attributes = { cli: params[:cli],
                   description: params[:description],
                   comment: params[:comment],
                   banned: (params[:banned].to_i == 1 ? 1 : 0)
                 }
  end

  def set_return_action
    @return_action = params[:return_to_action] if params[:return_to_action]
  end

  def set_return_controller
    @return_controller = params[:return_to_controller] if params[:return_to_controller]
  end

  def set_cid_name_and_number
    device_callerid = @device.callerid

    if device_callerid
      @cid_name = nice_cid(device_callerid)
      @cid_number = cid_number(device_callerid)
    else
      @cid_name = ''
    end
  end

  def get_number_pools
    if admin?
      @number_pools = NumberPool.order('name ASC').all.collect{|pool| [pool.name, pool.id]}
    end
  end

  def set_servers(device_type)
    @servers = (device_type == 'SIP') && ccl_active? ? @sip_proxy_server : @asterisk_servers
  end

  def load_devicetypes
    @devicetypes = @device.load_device_types("dahdi" => allow_dahdi?, "Virtual" => allow_virtual?)
  end

  def get_tariffs
    @tariffs = Tariff.tariffs_for_device(current_user_id)
  end

  def get_locations
    @locations = Location.locations_for_device_update(reseller?, correct_owner_id)
  end

  def set_forward_devices(set_nice_user_fw = false)
    forward_device = Device.where(id: @cfs.first.data).first
    @user_fw = forward_device ? forward_device.user.try(:id) : 'all'

    if @user_fw != 'all'
      @devices = forward_device.user.devices
      @nice_user_fw = nice_user(forward_device.user)
    end
  end

  def devices_title_and_icon
    @page_title = _('Devices')
    @page_icon = 'device.png'
  end
end
