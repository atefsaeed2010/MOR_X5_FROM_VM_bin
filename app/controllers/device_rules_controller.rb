class DeviceRulesController < ApplicationController
  layout 'callc'

  before_filter :allow_to_use
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_device, :only => [:list, :create]
  before_filter :find_device_rule, :only => [:change_status, :destroy, :edit, :update]

  def list
    @page_title = _('Device_rules')
    @page_icon = 'page_white_gear.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Device_Rules'
    @rules = @device.devicerules
    device_id = @device.id
    @rules_dst = Devicerule.where(['device_id = ? and pr_type = ?', device_id, 'dst'])
    @rules_src = Devicerule.where(['device_id = ? and pr_type = ?', device_id, 'src'])
  end

  def change_status
    if @devicerule.change_status
      flash[:status] = _('Rule_enabled')
    else
      flash[:status] = _('Rule_disabled')
    end
    @devicerule.save
    redirect_to action: 'list', id: @devicerule.device_id
  end

  def create
    if params[:name].blank? || (params[:cut].blank? && params[:add].blank?)
      flash[:notice] = _('Please_fill_all_fields')
      redirect_to action: 'list', id: params[:id] and return false
    end
    device_id = @device.id
    rule = Devicerule.new(device_id: device_id,
                          enabled:  1,
                          pr_type: params[:pr_type].to_s.strip)
    rule.update_by(params)
    if rule.save
      flash[:status] = _('Rule_added')
    else
      notice = _('Add_Failed')
      if rule.cut == rule.add
        flash[:notice] = notice + ' : ' + _('Cut_Equals_Add')
      else
        flash[:notice] = notice
      end
    end
    redirect_to action: 'list', id: device_id
  end

  def destroy
    dev_id = @devicerule.device_id
    @devicerule.destroy
    flash[:status] = _('Rule_deleted')
    redirect_to action: 'list', id: dev_id
  end

  def edit
    @page_title = _('Device_rule_edit')
    @page_icon = 'edit.png'
  end

  def update
    device_id = @devicerule.device_id
    if params[:name].length == 0 || (params[:cut].length == 0 && params[:add].length == 0)
      flash[:notice] = _('Please_fill_all_fields')
      redirect_to action: 'list', id: device_id and return false
    end

    @devicerule.update_by(params)
    if @devicerule.save
      flash[:status] = _('Rule_updated')
    else
      flash[:notice] = _('Update_Failed')
    end
    redirect_to action: 'list', id: device_id
  end

  private

  def find_device
    @device = Device.where('devices.id=?', params[:id]).includes([:user, :dids]).first

    unless @device
      flash[:notice] = _('Device_was_not_found')
      redirect_to :root and return false
    end

    if @device.user.owner_id.to_i != current_user_id
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def find_device_rule
    @devicerule = Devicerule.where('devicerules.id=?', params[:id]).includes([:device]).first

    unless @devicerule
      flash[:notice] = _('Devicerule_was_not_found')
      redirect_to :root and return false
    end

    unless Device.where(id: @devicerule.device_id).first
      flash[:notice] = _('Database_corruption_device_rule_does_not_have_device')
      redirect_to :root and return false
    end

    if @devicerule.device.user.owner_id.to_i != current_user_id
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def allow_to_use
    if current_user.blank?
      dont_be_so_smart
      redirect_to :root and return false
    elsif ['user', 'accountant'].include?(current_user.usertype)
      dont_be_so_smart
      redirect_to :root and return false
    end
  end
end
