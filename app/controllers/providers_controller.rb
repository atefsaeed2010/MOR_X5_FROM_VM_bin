# -*- encoding : utf-8 -*-
class ProvidersController < ApplicationController

  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update, :delete]

  before_filter :check_localization
  before_filter :authorize
  before_filter :providers_enabled_for_reseller?
  before_filter :find_provider, :only => [:hide, :provider_servers, :add_server_to_provider, :show, :edit, :update, :destroy, :provider_rules, :providercodecs_sort, :provider_test,
                                          :provider_rule_change_status, :provider_rule_add, :provider_rule_destroy, :provider_rule_edit, :provider_rule_update, :unassign, :provider_change_status]
  before_filter :find_providerrule, :only => [:provider_rule_change_status, :provider_rule_destroy, :provider_rule_edit, :provider_rule_update]
  before_filter :check_with_integrity, only: [:destroy, :create, :update, :delete, :list]
  before_filter :strip_params, :only => [:list]

  def index
    redirect_to :action => :list and return false
  end

  def list
    @page_title = _('Providers')
    @page_icon = "provider.png"
    params[:s_hidden] = params[:s_hidden].to_i

    @options, @total_pages, @providers, @provider_used_by_resellers, @servers, @search, @provtypes, @admin_providers, @n_class = Provider.list(params, session, current_user)

    session[:providers_list_options] = @options
    session[:back] = params

    @unhide_providers_test_icon = (Confline.get_value("unhide_providers_test_icon").to_i == 1)

    store_location
  end

  # in before filter : provider (find_provider)
  def hide
    if @provider.hide == 1
      flash[:status] = _('Provider_hidden')
    else
      flash[:status] = _('Provider_unhidden')
    end
    @provider.save
    redirect_to :action => 'list', :s_hidden => @provider.hidden.to_i
  end

  # in before filter : provider (find_provider)
  def provider_servers
    @page_title = _('Provider_servers')
    @page_icon = "server.png"
    @servers = Server.all
  end

  # in before filter : provider (find_provider)
  def delete
    server = Server.find(params[:id])
    serverprovider = Serverprovider.where(["provider_id = ? and server_id = ?", @provider.id, server.id])
    for providers in serverprovider
      providers.destroy
    end
    flash[:status] = _('Server_deleted')
    redirect_to :action => 'provider_servers', :id => @provider.id
  end

  # in before filter : provider (find_provider)
  def add_server_to_provider
    @server=Server.find(params[:server_add])
    serv_prov = Serverprovider.where(["server_id = ? AND provider_id = ?", @server.id, @provider.id]).first

    if not serv_prov
      Provider.add_server_to_provider(@server, @provider)

      flash[:status] = _('Server_added')
      redirect_to :action => 'provider_servers', :id => @provider.id

    else
      flash[:notice] = _('Server_already_exists')
      redirect_to :action => 'provider_servers', :id => @provider.id
    end
  end

  def new
    @page_title = _('New_provider')
    @page_icon = "add.png"

    if current_user.usertype == 'reseller' and Confline.get_value('Disallow_to_create_own_providers', current_user.id).to_i == 1
      dont_be_so_smart
      redirect_to :action => :list and return false
    end

    @provider = Provider.new
    @provider.tech = "SIP"
    @providertypes = Providertype.all
    @tariffs = Tariff.where(["purpose = 'provider' AND owner_id = ?", session[:user_id]])
    @locations = current_user.locations
    @servers = Server.where("server_type = 'asterisk'").order('id').all
    @serverproviders = []
    @provider.serverproviders.each { |p| @serverproviders[p.server_id] = 1 }

    unless @servers.size > 0
      flash[:notice] = _('No_servers_available')
      redirect_to :action => :list and return false
    end

    @action = "new"

    if @tariffs.size == 0
      flash[:notice] = _('No_tariffs_available')
      redirect_to :action => 'list'
    end

    @new_provider = true
  end


  def create
    params[:provider][:name]=params[:provider][:name].strip

    if current_user.usertype == 'reseller' and Confline.get_value('Disallow_to_create_own_providers', current_user.id).to_i == 1
      dont_be_so_smart
      redirect_to :action => :list and return false
    end

    @provider = Provider.create_by_params(params,current_user.id)

    params[:add_to_servers] = {Confline.get_value('Resellers_server_id').to_s => '1'} if session[:usertype] == "reseller"

    if !params[:add_to_servers] or params[:add_to_servers].size.to_i == 0
      flash[:notice] = _('Please_select_server')
      redirect_to :action => 'new' and return false
    end

    if @provider.save

      # ======= creating device for IAX2 and SIP provaiders ==========
      dev = Provider.create_device_for_providers_assigns(params, @provider)

      if not dev.save
        @provider.destroy
        flash_errors_for(_('Provider_was_not_created'), dev)
        redirect_to :action => 'new' and return false
      end

      Provider.create_device_for_providers_creation(params, dev, @provider)
      # end
      # ==============================================================
      flash[:status] = _('Provider_was_successfully_created')
      redirect_to :action => 'edit', :id => @provider.id
    else
      flash_errors_for(_('Provider_was_not_created'), @provider)
      redirect_to :action => 'new' and return false
    end
  end

  # in before filter : provider (find_provider)
  def edit
    @page_title = _('Provider_edit') + ": " + @provider.name
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Providers#General"

    @device, @is_common_use_used, @serverproviders, @locations,
        @tariffs, @video_codecs, @audio_codecs, @curr,
        @providertypes, @prules, @servers = Provider.edit_assigns(session, @provider)

    if @device
      @device, @cid_name, @cid_number, @number_pools,
          @device_caller_id_number, @qualify_time = Provider.edit_if_device_good(@device)
    else
      flash[:notice] = _('Providers_device_not_found')
      redirect_to :action => 'list' and return false #, :id => @provider.id and return false
    end

    #------ permits --------

    @ip_first = ""
    @mask_first = ""
    @ip_second = ""
    @mask_second = ""
    @ip_third = ""
    @mask_third = ""

    if @provider.device
      data = @provider.device.permit.split(';')
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
    end

    render :edit_h323 if @provider.tech == "H323"
  end

  def update
    params[:provider][:name] = params[:provider][:name].to_s.strip
    params[:provider][:timeout] = params[:provider][:timeout].to_s.strip
    params[:provider][:max_timeout] = params[:provider][:max_timeout].to_s.strip
    params[:provider][:balance_limit] = params[:provider][:balance_limit].to_s.strip.gsub("\,",".").gsub(";",".")

    #5618#comment:13 if timeout value is invalid(its not positive integer) we discard that value
    params[:provider].delete(:timeout) if params[:provider][:timeout] !~ /^[0-9]+$/
    params[:provider].delete(:max_timeout) if params[:provider][:max_timeout] !~ /^[0-9]+$/

    params[:provider][:reg_extension] ||= ""
    params[:provider][:reg_line] ||= ""

    params[:provider][:call_limit] = 0 if (params[:provider][:call_limit] and params[:provider][:call_limit].to_i < 0) or params[:provider][:call_limit].blank?

    @provider.set_old

    # if higher than zero -> do not update provider
    provider_update_errors = 0

    unless @provider.is_dahdi?
      params[:provider][:login]= params[:provider][:login].to_s.strip if params[:provider][:login]
      params[:provider][:password]= params[:provider][:password].to_s.strip if params[:provider][:password]
      params[:provider][:server_ip]= params[:provider][:server_ip].to_s.strip if params[:provider][:server_ip]
      params[:provider][:port]= params[:provider][:port].to_s.strip if params[:provider][:port]
      params[:cid_number]= params[:cid_number].to_s.strip if params[:cid_number]
      params[:cid_name]=params[:cid_name].to_s.strip if params[:cid_name]
      params[:fromdomain]=params[:fromdomain].to_s.strip if params[:fromdomain]
      params[:fromuser]=params[:fromuser].to_s.strip if params[:fromuser]
      params[:custom_sip_header] = params[:custom_sip_header].to_s.strip if params[:custom_sip_header]
    else
      params[:provider][:channel]= params[:provider][:channel].strip if params[:provider][:channel]
    end
    if !params[:provider][:port] and @provider.tech == "H323" and params[:provider][:zero_port].to_i == 1
      params[:provider][:port] = 0
    end
    params[:provider][:hidden] = (params[:provider][:hidden] == '1' ? 1 : 0)
    @provider.attributes = params[:provider]
    @provider.network(params[:hostname_ip].to_s, params[:provider][:server_ip].to_s.strip, params[:device][:ipaddr].to_s.strip, params[:provider][:port].to_i)
    unless @provider.valid?
      provider_update_errors += 1
    end

    if (params[:hostname_ip] == 'hostname' and params[:provider][:server_ip].blank?) or (params[:hostname_ip] == 'ip' and (params[:provider][:server_ip].blank?))
      @hostname_ip = "ip"
      @provider.errors.add(:hostname_ip_error, _('Hostname/IP_is_blank'))
      provider_update_errors += 1
    end

    if params[:hostname_ip] == 'ip'
      params[:host] = params[:device][:ipaddr]
      option_ip_authentication = params[:ip_authentication]
      params[:ip_authentication] = 1
      @provider, provider_update_errors = Device.validate_ip_address_format(params, @provider, provider_update_errors, prov = 1)
      params[:ip_authentication] = option_ip_authentication
    end

    params[:add_to_servers] = {Confline.get_value('Resellers_server_id').to_s => '1'} if session[:usertype] == "reseller"
    if !params[:add_to_servers] or params[:add_to_servers].size.to_i == 0
      @provider.errors.add(:add_to_servers_error, _('Please_select_server'))
      provider_update_errors += 1
    end

    if provider_billing_active? and (!is_numeric?(params[:provider][:balance_limit].to_s.gsub(";",".").gsub("\,","."))) and (!["H323", "Skype", "dahdi"].include?(@provider.tech.to_s))
      flash[:notice] = _('Balance_limit_must_be_numeric')
      redirect_to :action => 'edit', :id => @provider.id and return false
    end

    #========= codecs =======

    @provider.update_codecs_with_priority(params[:codec]) if params[:codec]

    @device = @provider.device
    @device.set_old_name
    @device.device_ip_authentication_record = params[:ip_authentication].to_i

    @device.trunk = params[:iax2_trunking] if params[:iax2_trunking]

    @device.update_cid(params[:cid_name], params[:cid_number])
    if admin?
      @device.callerid_number_pool_id = params[:device_caller_id_number].to_i == 2 ? params[:callerid_number_pool_id].to_i : 0
    end
    @device.attributes = params[:device]
    @device.server_id = Confline.get_value('Resellers_server_id').to_i if reseller?

    if params[:mask_first]
      if !Device.validate_permits_ip([params[:ip_first], params[:ip_second], params[:ip_third], params[:mask_first], params[:mask_second], params[:mask_third]])
        @provider.errors.add(:mask_first_error, _('Allowed_IP_is_not_valid'))
        provider_update_errors += 1
      else
        @device.permit = Device.validate_perims({:ip_first => params[:ip_first], :ip_second => params[:ip_second], :ip_third => params[:ip_third], :mask_first => params[:mask_first], :mask_second => params[:mask_second], :mask_third => params[:mask_third]})
      end
    end

    #my_debug permits
    #------ advanced --------
    if params[:qualify] == "yes"
      @device.qualify = params[:qualify_time].strip
      @device.qualify = "1000" if @device.qualify.to_i <= 1000
    else
      @device.qualify = "no"
    end

    @device.canreinvite = @device.canreinvite.strip
    @device.transfer = @device.canreinvite.strip

    @device.fromuser = params[:fromuser]
    @device.fromuser = nil if not params[:fromuser] or params[:fromuser].length < 1

    @device.fromdomain = params[:fromdomain]
    @device.fromdomain = nil if not params[:fromdomain] or params[:fromdomain].length < 1

    @device.authuser = params[:authuser].blank? ? "" : params[:authuser]
    @device.custom_sip_header = params[:custom_sip_header].blank? ? "" : params[:custom_sip_header]
    @device.grace_time = params[:grace_time]

    @device.adjust_insecurities(ccl_active?, params)

    if ccl_active?
      if @device.device_type.to_s == 'SIP' and params[:zero_port].to_i == 1
        @device.proxy_port = 0
      else
        @device.proxy_port = @device.port
      end
    else
      @device.proxy_port = @device.port
    end

    if !params[:provider][:port] and @device.device_type.to_s == "H323"
      @device.port = 0
    end

    @device.fullcontact = ''

    @provider.register = params[:register] && (params[:hostname_ip].to_s != 'dynamic') ? 1 : 0

    if params[:ip_authentication].to_i == 1
      @provider.assign_attributes({
        login: '',
        password: ''
      })
      @device.assign_attributes({
        username: '',
        secret: ''
      })

      if !@device.name.include?('ipauth')
        name = @device.generate_rand_name('ipauth', 8)
        while Device.where(['name= ? and id != ?', name, @device.id]).first
          name = @device.generate_rand_name('ipauth', 8)
        end
        @device.name = name
      end
    else
#      #ticket 5055. ip auth or dynamic host must checked
#      if params[:hostname_ip].to_i != 'dynamic' and ['SIP', 'IAX2'].include?(@device.device_type)
#        flash[:notice] = _("Must_set_either_ip_auth_either_dynamic_host")
#        redirect_to :action => :edit, :id => @provider.id and return false
#      end
      @device.name = "prov_" + @provider.id.to_s
      @device.username = @provider.login.strip
      @device.secret = (@provider.password).strip
    end
    #------- Network related -------
    @provider.network(params[:hostname_ip].to_s, params[:provider][:server_ip].to_s.strip, params[:device][:ipaddr].to_s.strip, params[:provider][:port].to_s.strip)

    if params[:save_call_log].to_s == "1"
      @device.save_call_log = 1
    else
      @device.save_call_log = 0
    end



    if not @provider.device.save
      provider_update_errors += 1
    end

    if provider_update_errors == 0 and @provider.save

      @provider.create_serverproviders(params[:add_to_servers])
      device_servers = []

      if ccl_active? and @device.device_type.to_s == 'SIP' and @device.user_id != -1
        sip_proxy_server = Server.where("server_type = 'sip_proxy'").first.try(:id)
        device_servers << sip_proxy_server.to_i
      elsif @device.user_id != -1
        params[:add_to_servers].each {|s| device_servers << s[0]}
        device_servers = Server.where("id IN (#{device_servers.join(',')})").collect(&:id)
      end
      @provider.create_server_devices(device_servers, @device.id)

      session[:flash_not_redirect] = 0

      # update asterisk configuration
      if @provider.tech == "SIP"
        exceptions = @device.prune_device_in_all_servers(nil, 1, 1, 0)
        raise exceptions[0] if exceptions and exceptions.size > 0

        # reloading sip and keeping realtime peers intact
        exceptions = @provider.sip_reload_keeprt
        raise exceptions[0] if exceptions and exceptions.size > 0

      end

      if @provider.tech == "IAX2"
        exceptions = @device.prune_device_in_all_servers(nil, 1, 0, 1)
        raise exceptions[0] if exceptions and exceptions.size > 0
      end

      if @provider.tech == "H323"
        exceptions = @provider.h323_reload
        raise exceptions[0] if exceptions and exceptions.size > 0
      end

      flash[:status] = _('Provider_was_successfully_updated')
      redirect_to :action => 'list', :id => @provider, :s_hidden => @provider.hidden.to_i and return false
    else
      if @provider.device.errors.blank?
        flash_errors_for(_('Providers_settings_bad'), @provider)
      else
        flash_errors_for(_('Providers_settings_bad'), @provider.device)
      end

      @servers= Server.where(:server_type => 'asterisk').order(:id).all
      @prules = @provider.providerrules

      @providertypes = Providertype.all
      @curr = current_user.currency

      @audio_codecs = @provider.codecs_order('audio')
      @video_codecs = @provider.codecs_order('video')

      @tariffs = Tariff.where(:purpose => 'provider', :owner_id => session[:user_id])

      @locations = current_user.locations

      @serverproviders = []
      @provider.serverproviders.each { |p| @serverproviders[p.server_id] = 1 }

      @is_common_use_used = false
      provider_used_by_resellers_terminator = Provider.where("id = ? AND common_use = 1 and terminator_id IN (select id from terminators where user_id != 0)", @provider.id).all
      provider_used_by_resellers_lcr = Lcrprovider.where("(provider_id = ? and lcr_id IN (select id from lcrs where user_id != 0))", @provider.id).all
      if provider_used_by_resellers_terminator.size > 0 or provider_used_by_resellers_lcr.size > 0
        @is_common_use_used = true
      end

      if admin?
        @number_pools = NumberPool.order("name ASC").all.collect{|i| [i.name, i.id]}
      end
      @device = @provider.device
      if @device
        @cid_name = ""
        if @device.callerid
          @cid_name = nice_cid(@device.callerid)
          @cid_number = cid_number(@device.callerid)
        end

        if @device.qualify == "yes" or @device.qualify == "no"
          @qualify_time = 2000
        else
          @qualify_time = @device.qualify
        end
      end

      #------ permits --------

      @ip_first = ""
      @mask_first = ""
      @ip_second = ""
      @mask_second = ""
      @ip_third = ""
      @mask_third = ""

      if @provider.device
        data = @provider.device.permit.split(';')
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
      end

      render :edit
    end
  end

  # in before filter : provider (find_provider)
  def unassign
    #unassigns provider from user based on what provider id was passed as id
    #-
    #if everything went well
    #1) if no return action and return contoller was passed
    #1.1) return back to where session[:return_to] points
    #1.2) go to callc main if session[:return_to] is not defined
    #2) else go to controller and action
    @return_controller = params[:return_to_controller] if params[:return_to_controller]
    @return_action = params[:return_to_action] if params[:return_to_action]

    device = @provider.device
    if device

      device = Provider.device_unassign_user_id(device)
      if device.save
        # if provider is not assigned to user, should not have any connections in "server_devices" table
        ServerDevice.delete_all(device_id: device.id)
        flash[:status] = _('Provider_unassigned')
      else
        flash[:notice] = _('Provider_not_updated')
      end

      if defined? @return_action and defined? @return_controller
        redirect_to :controller => @return_controller, :action => @return_action and return false
      else
        redirect_back_or_default
      end

    else
      dont_be_so_smart
      redirect_to :root and return false
    end

  end

  # in before filter : provider (find_provider)
  def destroy
    device = @provider.device
    if device
      Provider.destroy_exceptions(@provider, device)
    end

    if @provider.destroy
      flash[:status] = _('Provider_deleted')
    else
      flash_errors_for(_('Provider_not_deleted'), @provider)
    end
    redirect_to :action => 'list'
  end


  #------------ Provider rules --------------
  # in before filter : provider (find_provider)
  def provider_rules
    @page_title = _('Provider_rules')
    @page_icon = 'page_white_gear.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Provider_Rules"
    @rules = @provider.providerrules
    @rules_dst = Providerrule.where(:provider_id => @provider.id, :pr_type => "dst").all
    @rules_src = Providerrule.where(:provider_id => @provider.id, :pr_type => "src").all
  end

  # in before filter @provider (find_provider), @providerrule  (find_providerrule)
  def provider_rule_change_status

    if @providerrule.enabled == 0
      @providerrule.enabled = 1
      flash[:status] = _('Rule_enabled')
    else
      @providerrule.enabled = 0
      flash[:status] = _('Rule_disabled')
    end
    @providerrule.save
    redirect_to :action => 'provider_rules', :id => @provider.id
  end

  # provider active status
  def provider_change_status
    if @provider.active.to_i == 1
      value = 0
      flash[:status] = _('Provider_disabled')
    else
      value = 1
      flash[:status] = _('Provider_enabled')
    end

    sql = "UPDATE providers SET active = #{value} WHERE id = #{@provider.id}"
    res = ActiveRecord::Base.connection.update(sql)

    redirect_to :action => 'list', :id => @provider.id
  end

  # in before filter : provider (find_provider)
  def provider_rule_add
    if params[:name].blank? or (params[:cut].blank? and params[:add].blank?)
      flash[:notice] = _('Please_fill_all_fields')
      redirect_to :action => 'provider_rules', :id => params[:id] and return false
    end

    rule = Providerrule.create_by(params,@provider)
    if rule.save
      flash[:status] = _('Rule_added')
    else
      if rule.cut == rule.add
        flash[:notice] = _('Add_Failed')+" : "+_('Cut_Equals_Add')
      else
        flash[:notice] = _('Add_Failed')
      end
    end
    redirect_to :action => 'provider_rules', :id => @provider.id
  end

  # in before filter : provider (find_provider), @providerrule  (find_providerrule)
  def provider_rule_destroy
    @providerrule.destroy
    flash[:status] = _('Rule_deleted')
    redirect_to :action => 'provider_rules', :id => @provider.id
  end

  # in before filter : provider (find_provider), @providerrule  (find_providerrule)
  def provider_rule_edit
    @page_title = _('Provider_rule_edit')
    @page_icon = 'edit.png'
  end

  # in before filter : provider (find_provider), @providerrule  (find_providerrule)
  def provider_rule_update
    if params[:name].length == 0 or (params[:cut].length == 0 and params[:add].length ==0)
      flash[:notice] = _('Please_fill_all_fields')
      redirect_to :action => 'provider_rule_edit', :id => params[:id], :providerrule_id => params[:providerrule_id] and return false
    end
   @providerrule.update_by(params)
    if @providerrule.save
      flash[:status] = _('Rule_updated')
    else
      flash[:notice] = _('Update_Failed')
    end
    redirect_to :action => 'provider_rules', :id => @provider.id

  end

  #---------------------- new provider logic -----------------

  # this action is not used, because Provider is "created" by marking user as Provider
  def provider_new
    @page_title = _('New_provider')
    @page_icon = "add.png"
    @provider, @tariffs, @servers = Provider.provider_new(session)

    if not @tariffs
      flash[:notice] = _('No_tariffs_available')
      redirect_to :action => 'list'
    end
  end

  def provider_create
    if params[:provider][:name].to_s == ""
      flash[:notice] = _('Please_enter_name')
      redirect_to :action => 'list' and return false
    end

    Provider.provider_create(current_user, params, server)

    flash[:status] = _('Provider_created')
    redirect_to :action => 'list'
  end

  # in before filter : provider (find_provider)
  def providercodecs_sort
    if params[:codec_id]
      if params[:val] == 'true'
        pc = Providercodec.new({:codec_id => params[:codec_id], :provider_id => @provider.id})
        pc.save if pc
      else
        pc = Providercodec.where(['provider_id=? AND codec_id=?', params[:id], params[:codec_id]]).first
        pc.destroy if pc
      end
    end

    params["#{params[:ctype]}_sortable_list".to_sym].each_with_index do |i, index|
      item = Providercodec.where(['provider_id=? AND codec_id=?', params[:id], i]).first
      if item
        item.priority = index.to_i
        item.save
      end

    end
    @provider.update_device_codecs
    render :layout => false
  end

  def billing
    unless provider_billing_active?
      dont_be_so_smart
      redirect_to :root and return false
    end

    @page_title, @page_icon = [_('Providers'), 'provider.png']
    @show_currency_selector = 1
    params[:s_hidden] = params[:s_hidden].to_i

    @curr, @options, @total_pages, @providers, @n_class = Provider.billing(current_user, params, session)

    session[:providers_list_options] = @options
    session[:back] = params

    store_location
  end

  # in before filter : provider (find_provider)
  def provider_test
    @success = 0
    if @provider
      if @provider.server_ip != "dynamic"
        if @provider.tech == "SIP"
          if test_sip_conectivity(@provider.server_ip.to_s, @provider.port.to_s)
            message = _('Connection_successful')
            @success = 1
          else
            message = _('Connection_failed')
          end
        else
          message = _("Can_only_test_SIP_providers")
        end
        @message = message
      else
        message = _("Cannot_test_dynamic_IP")
        @message = message
      end
    else
      @message = _("Provider_not_found")
    end
    render(:layout => "layouts/mor_min")
  end

  def quick_changes
    @page_title = _('Quick_Changes')
    @page_icon	= "provider.png"
    flash.clear

    @options		= Hash.new
    @options[:page]	= (params[:page] ? params[:page] : 1)
    @options[:order_by] = (params[:order_by] ? params[:order_by] : 'id')
    @options[:order_desc]  = params[:order_desc]
    @options[:s_server_ip] = params[:s_server_ip].to_s.strip
    @options[:s_name]	   = params[:s_name].to_s.strip
    @options[:s_tech]	   = params[:s_tech].to_s.strip
    @options[:s_hidden]	   = params[:s_hidden]
    page_limit	= Confline.get_value("Items_Per_Page", 0).to_i
    page_offset	= page_limit * (@options[:page].to_i - 1)

    @err = Hash.new(nil)

    request = params[:providers]
    if request

      request.each do |key, val|
        provider	= Provider.where(id: key.to_i).first
        device		= provider.device
        device.time_limit_per_day = val["time_limit_per_day"] if val["time_limit_per_day"]
        provider.update_by(val)
        unless (device.save and provider.save and val["time_limit_per_day"] =~ /^\d+$/)
          @err["#{key}"] = 1
        end
      end
      error_size = @err.size
      if error_size == 1
        flash[:notice] = "#{@err.size}  " + _("quick_provider_not_updated")
      elsif error_size > 1
        flash[:notice] = "#{@err.size}  " + _("quick_providers_not_updated")
      else
        flash[:status] = _('Providers_were_successfully_updated')
      end
    end

    order = ['DESC','ASC'][@options[:order_desc].to_i]
    query = "providers.user_id = '#{current_user.id}' AND hidden = 0"
    query << " AND providers.server_ip like '#{@options[:s_server_ip]}'"  unless @options[:s_server_ip].blank?
    query << " AND providers.name like '#{@options[:s_name]}'"	    unless @options[:s_name].blank?
    query << " AND providers.tech = '#{@options[:s_tech]}'"	   	    unless @options[:s_tech].blank?
    @providers_all ||= Provider.joins(:device).where(query).order("#{@options[:order_by]} #{order}")
    @tariffs	   ||= Tariff.where(owner_id: current_user.id, purpose: 'provider')
    @providers	     = @providers_all[page_offset,page_limit]
    @total_pages     = (@providers_all.size.to_d / page_limit).ceil

    @search	= @providers_all.size
    @search	= 0 if @options[:s_hidden].blank?
    @provtypes	= @providers_all.collect(&:tech).uniq

  end

  def check_with_integrity
    session[:integrity_check] = Device.integrity_recheck_devices if admin?
  end

  private

  def test_sip_conectivity(ip, port)
    begin
      `rm -f /tmp/.mor_provider_check`
      return false if ip.to_s.length == 0

      if port.to_s == ''
        `sipsak -s sip:101@#{ip} -v > /tmp/.mor_provider_check`
      else
        `sipsak -s sip:101@#{ip}:#{port} -v > /tmp/.mor_provider_check`
      end

      @server = `grep 'Server\\|User-Agent\\|User-agent' /tmp/.mor_provider_check`.to_s.gsub("User-Agent:", "").to_s.gsub("User-agent:", "").to_s.gsub("Server:", "").to_s.strip
      @sip_response = `cat /tmp/.mor_provider_check`
      return @sip_response.to_s.scan(/SIP.*200/).size > 0 ? true : false
    rescue
      return false
    end
  end

  def find_providerrule
    unless @provider
      flash[:notice] = _('Provider_not_found')
      redirect_to :controller => "providers", :action => 'list' and return false
    end

    @providerrule = @provider.providerrules.where(:id => params[:providerrule_id]).first

    unless @providerrule
      flash[:notice] = _('Provider_rule_was_not_found')
      redirect_to :controller => "providers", :action => 'list' and return false
    end
  end
end
