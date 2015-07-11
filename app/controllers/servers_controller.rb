# -*- encoding : utf-8 -*-
class ServersController < ApplicationController

  layout 'callc'

  before_filter :check_post_method, :only => [:destroy, :create, :update, :server_add, :server_update, :delete, :delete_device, :server_change_status]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_server, :only => [:server_providers, :add_provider_to_server, :show, :edit, :destroy, :server_change_gui, :server_change_db, :server_change_core, :server_change_status, :server_change_gateway_status, :server_test, :server_update, :server_devices_list]
  before_filter :check_server_ip, :only => [:server_update]

  def index
    if !admin?
      dont_be_so_smart
      redirect_to :root and return false
    else
      redirect_to :action => :list and return false
    end
  end

  def list
    @page_title = _('Servers')
    @page_icon = 'server.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Multi_Server_support'
    @servers = Server.order('id').all
    @has_proxy = Server.where(server_type: 'sip_proxy').exists?
  end

  def server_providers
    @page_title = _('Server_providers')
    @page_icon = 'provider.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Multi_Server_support'

    @providers = Provider.where(['hidden=?', 0])
    @new_prv = []
    for prv in @providers
      if not Serverprovider.where(["server_id = ? AND provider_id = ?", @server.id, prv.id]).first
        @new_prv << prv
      end
      @providers = @new_prv
    end
    session[:back] = params
  end

  def add_provider_to_server
    provider_id = params[:provider_add]
    unless @provider = Provider.where(:id => provider_id).first
      flash[:notice] = _('Provider_not_found')
      redirect_to :action => 'list' and return false
    end
    server_id = @server.id
    serv_prov = Serverprovider.where(["server_id = ? AND provider_id = ?", @server.id, @provider.id]).first

    if not serv_prov
      Server.add_provider_to_server_if_not_serv_prov(@server, @provider, provider_id)

      if @provider.register == 1
        @provider.servers.each { |server| server.reload }
      end
      flash[:status] = _('Provider_added')
    else
      flash[:notice] = _('Provider_already_exists')
    end
    redirect_to :action => 'server_providers', :id => server_id and return false
  end


  def show
  end

  def new
    @page_title = _('Server_new')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Multi_Server_support'
    @server = Server.new
  end

  def edit
    @page_title = _('Server_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Multi_Server_support'
    @server_type = @server.server_type
  end

  def server_add
    server, serv = Server.server_add(params)

    if server.valid? and serv.run and server.save
      unless server.server_device
        server.create_server_device
      end
      flash[:status] = _('Server_created')
    else
      server_errors = server.errors
      if server_errors.keys.include?(:device)
        error_messages = server_errors.values.first
        flash[:notice] = _(error_messages.first, "mor_server_#{server.id.to_s}") if error_messages
      else
        flash_errors_for(_('Server_not_created'), server)
      end
    end

    redirect_to :action => 'list'
  end


  def server_update
    dev, @server, errors = Server.server_update(params, @server)

    if errors.zero? and @server.save
      #update device
      if dev
        dev.assign_attributes({
          host: @server.hostname,
          ipaddr: @server.server_ip,
          port: @server.port,
          proxy_port: dev.port
        })
        dev.save
      end
      flash[:status] = _('Server_update')
    else
      flash_errors_for(_('Server_not_updated'), @server)
    end

    redirect_to :action => 'list'
  end


  def delete
    provider = Provider.where(:id => params[:id]).first
    dev = provider.device
    unless provider
      flash[:notice] = _('Provider_not_found')
      redirect_to :action => 'list' and return false
    end
    server = Server.where(:id => params[:sid]).first
    unless server
      flash[:notice] = _('Server_not_found')
      redirect_to :action => 'list' and return false
    end

    server_id = server.id
    serverprovider = Serverprovider.where(["provider_id = ? and server_id = ?", provider.id, server.id])
    server_device  = ServerDevice.where(["device_id = ? and server_id = ?", dev.id, server_id]) if dev.present?

    serverprovider.destroy_all
    server_device.destroy_all
    flash[:status] = _('Providers_deleted')
    redirect_to :action => 'server_providers', :id => server_id

  end

  def delete_device
    device = Device.where(["id = ?", params[:id]]).first
    unless device
      flash[:notice] = _('Device_not_found')
      redirect_to :action => 'server_devices_list' and return false
    end
    server = Server.where(["id = ?", params[:serv_id]]).first
    unless server
      flash[:notice] = _('Server_not_found')
      redirect_to :action => 'server_devices_list' and return false
    end
    server_device = ServerDevice.where("server_id = ? AND device_id = ?", params[:serv_id], params[:id]).first
    server_device.destroy
    flash[:status] = _('device_deleted')
    redirect_to :action => 'server_devices_list', :id => params[:serv_id]
  end

  def destroy
    if @server.server_type == 'sip_proxy'
      flash[:notice] = _('Server_cant_be_deleted')
    elsif @server.destroy
      dev = Device.where("name = 'mor_server_#{@server.id.to_s}'").first
      dev.destroy if dev
      serverprovider = Serverprovider.where(["server_id = ?", @server.id])
      for providers in serverprovider
        providers.destroy
      end
      flash[:status] = _('Server_deleted')
    else
      flash_errors_for(_("Server_Not_Deleted"), @server)
    end
    redirect_to :action => 'list'
  end

  def server_change_gui
    @server.gui = (@server.gui == 1 ? 0 : 1)

    unless @server.save
      flash_errors_for(_('Server_not_updated'), @server)
    end
    redirect_to :action => 'list', :id => params[:id]
  end

  def server_change_db
    @server.db = (@server.db == 1 ? 0 : 1)

    unless @server.save
      flash_errors_for(_('Server_not_updated'), @server)
    end
    redirect_to :action => 'list', :id => params[:id]
  end


  def server_change_core
    @server.core = (@server.core == 1 ? 0 : 1)

    unless @server.save
      flash_errors_for(_('Server_not_updated'), @server)
    end
    redirect_to :action => 'list', :id => params[:id]
  end


  def server_change_status
    if @server.active == 1
      value = 0
      flash[:notice] = _('Server_disabled')
    else
      value = 1
      flash[:status] = _('Server_enabled')
    end
    sql = "UPDATE servers SET active = #{value} WHERE id = #{@server.id}"
    ActiveRecord::Base.connection.update(sql)
    redirect_to :action => 'list', :id => @server.id
  end


  def server_change_gateway_status
    server_id = params[:id]
    if @server.gateway_active == 1
      @server.gateway.destroy
      value = 0
      flash[:notice] = _('Server_marked_as_not_gateway')
    else
      gtw = Gateway.new({:setid => 1, :destination => "sip:#{@server.server_ip}:#{@server.port}", :server_id => server_id})
      gtw.save
      value = 1
      flash[:status] = _('Server_marked_as_gateway')
    end
    sql = "UPDATE servers SET gateway_active = #{value} WHERE id = #{server_id}"
    res = ActiveRecord::Base.connection.update(sql)
    redirect_to :action => 'list', :id => server_id
  end

  def server_test
    @help_link = 'http://wiki.kolmisoft.com/index.php/Multi_Server_support'
    if @server.core.to_i == 0 or @server.server_type.to_s == 'sip_proxy'
      dont_be_so_smart
      redirect_to :root
    else
      session[:flash_not_redirect] = 1
      server_test_ok = 0
      begin
        @server.ami_cmd('core show version') if @server.server_type == 'asterisk'
      rescue
        flash_help_link = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_SystemExit'
        flash[:notice] = _('Cannot_connect_to_asterisk_server')
        flash[:notice] += "<a href='#{flash_help_link}' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' />&nbsp;#{_('Click_here_for_more_info')}</a>" if flash_help_link
        server_test_ok = 0
      else
        server_test_ok = 1
      end
      session[:server_test_ok] = server_test_ok
      render(:layout => 'layouts/mor_min')
    end
  end

  # when ccl_active = 1 shows all devices of a certain server
  def server_devices_list
    if !ccl_active? or (session[:usertype] != 'admin' and ccl_active?)
      dont_be_so_smart
      redirect_to :root and return false
    end
    @page_title = _('Server_devices')
    @page_icon = 'server.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Multi_Server_support'
    # ip_auth + server_devices.server_id is null + server_devices.server_id is not that server + not server device(which were created with server creation)
    @devices = Device.select('devices.*, server_devices.server_id AS serv_id').joins("LEFT JOIN server_devices ON (server_devices.device_id = devices.id AND  server_devices.server_id = #{params[:id].to_i}) LEFT JOIN users ON (users.id = devices.user_id)").where("device_type != 'SIP' AND users.owner_id = #{current_user.id} AND server_devices.server_id is null AND user_id != -1 AND name not like 'mor_server_%'").order('extension ASC').all
  end

  def add_device_to_server
    @device = Device.where(["id=?", params[:device_add].to_i]).first
    unless @device
      flash[:notice] = _('Device_not_found')
      redirect_to :action => 'server_devices_list', :id => params[:id] and return false
    end
    serv_dev = ServerDevice.where("server_id = ? AND device_id = ?", params[:id], @device.id).first

    if not serv_dev
      server_device = ServerDevice.new_relation(params[:id], @device.id)
      server_device.save

      flash[:status] = _('Device_added')
    else
      flash[:notice] = _('Device_already_exists')
    end
    redirect_to :action => 'server_devices_list', :id => params[:id] and return false
  end

  private

  def find_server
    @server = Server.where(["id = ?", params[:id]]).first
    unless @server
      flash[:notice] = _('Server_not_found')
      redirect_to :action => :list and return false
    end
  end

  def check_server_ip
    server_id = params[:server_id]
    # useless
  end

end
