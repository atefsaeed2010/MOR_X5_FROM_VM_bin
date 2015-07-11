# -*- encoding : utf-8 -*-
class LocationsController < ApplicationController
  require 'yaml'
  layout 'callc'

  before_filter :check_post_method, only: [:location_destroy, :location_rule_update, :location_rule_change_status, :location_rule_destroy, :location_change]
  before_filter :check_localization
  before_filter :authorize
  # before_filter :check_permsission
  before_filter :find_location, only: [:location_rules, :location_devices, :location_destroy]
  before_filter :find_location_rule, only: [:location_rule_edit, :location_rule_update, :location_rule_change_status, :location_rule_destroy]
  before_filter :find_tariffs, only: [:location_rule_edit, :location_rules]
  before_filter :set_help_link, only: [:localization, :location_rules, :location_rule_edit]

  def index
    flash[:notice] = _('Dont_be_so_smart')
    redirect_to(:root) && (return false)
  end

  def localization
    @page_title = _('Localization')
    @locations = current_user.locations
  end

  def edit_localization
    params_id = params[:id]
    @location = Location.where(id: params_id.to_i).first
    current_user_id = current_user.id.to_i

    if !@location || params_id.blank? || user? || accountant?
      dont_be_so_smart
      redirect_to :root
    elsif @location.user_id != current_user_id
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :root
    else

      @page_title = _('Location_edit') + ': ' + @location.name
      @page_icon  = 'edit.png'

      if params['commit']
        @location.name = params[:location][:name].to_s.strip
        if @location.save
          flash[:status] = _('Localization_updated')
          redirect_to action: 'localization'
        else
          flash_errors_for(_('Location_not_updated'), @location)
        end
      end
    end
  end

  def location_rules
    @page_title = _('Location_rules')
    @page_icon = 'page_white_gear.png'
    location_id = @location.id

    @rules = @location.locationrules(include: [:device])
    # find current users lcr with check what type reseller
    @lcrs = current_user.load_lcrs({order: 'name ASC'})

    @grules_dst = Locationrule.where(['location_id =? and lr_type =?', 1, 'dst']).order('name ASC')
    @grules_src = Locationrule.where(['location_id =? and lr_type =?', 1, 'src']).order('name ASC')
    @rules_dst = Locationrule.where(['location_id =? and lr_type =?', location_id, 'dst']).order('name ASC')
    @rules_src = Locationrule.where(['location_id =? and lr_type =?', location_id, 'src']).order('name ASC')
    cond = ['dids.id > 0']
    var = []
    cond << 'dids.reseller_id = ?' and var << current_user.id if current_user.is_reseller?
    @dids = Did.where([cond.join(' AND ')].concat(var)).limit(1).all
    fields_from_parameters
  end

=begin
Called from views location_rules and location_rule_edit, to update DID list from DB on every input change.
=end
  def get_did_map
    output = []
    style = "width='177px' style='margin-left:20px;padding-left:6px;font-size:10px;font-weight: normal;'"
    params_did_livesearch = params[:did_livesearch]
    params[:callback].to_s == 'true' ? (@did_str = params_did_livesearch.split('-')[0].to_s.strip rescue '') : @did_str = params_did_livesearch.to_s
    unless @did_str.blank?
      filter = params[:filter].to_s
      output, @total_dids = Did.seek_by_filter(filter, current_user, @did_str, style)
    end
    if params[:empty_click].to_s == 'true'
      output = ["<tr><td id='-2' #{style}>" << _('Enter_value_here') << '</td></tr>']
    end
    render(text: output.join)
  end

# in before filter : rule (:find_location_rule)
  def location_rule_edit
    @page_title = _('Location_rule_edit')
    @page_icon = 'edit.png'
    fields_from_parameters

    # find current users lcr with check what type reseller
    @lcrs = current_user.load_lcrs({order: 'name ASC'})
    rule_device = @rule.device
    cond = ['dids.id > 0']
    var = []
    cond << 'dids.reseller_id = ?' and var << current_user.id if current_user.is_reseller?
    @dids = Did.where([cond.join(' AND ')].concat(var)).order('dids.did ASC').limit(1).all
    @did_of_rule = Did.where('id = ?', @rule.did_id).first
    if rule_device.present?
      @s_user = nice_user(@rule.device.user)
      @s_user_id = @rule.device.user.id
      @devices = @rule.device.user.devices
    end
  end

  # in before filter : rule (:find_location_rule)
  def location_rule_update
    params_name = params[:name]
    params_did = params[:did]
    if params_name.blank? # or (params[:cut].length == 0 and params[:add].length ==0)
      flash[:notice] = _('Please_enter_name')
      redirect_to(action: 'location_rule_edit', id: @rule.id, s_user: params[:s_user], s_user_id: params[:s_user_id]) && (return false)
    end
    @did = Did.where('did LIKE ?', params_did.to_s).first if params_did
    @rule.update_by(params, @did)

    @rule.save ? flash[:status] = _('Rule_updated') : flash_errors_for(_('Rule_not_updated'), @rule)
    redirect_to(action: 'location_rules', id: @rule.location_id)
  end

  # in before filter : rule (:find_location_rule)
  def location_rule_change_status
    st = @rule.change_status
    @rule.save ? flash[:status] = st : flash[:notice] = _('Update_Failed')
    redirect_to(action: 'location_rules', id: @rule.location_id)
  end

  # in before filter : rule (:find_location_rule)
  def location_rule_destroy
    location_id = @rule.location_id
    @rule.destroy ? flash[:status] = _('Rule_deleted') : flash[:notice] = _('Rule_not_deleted')
    redirect_to(action: 'location_rules', id: location_id)
  end

  def location_rule_add
    params_did = params[:did]
    params_location_id = params[:location_id]

    @did = Did.where('did LIKE ?', params_did.to_s).first if params_did
    rule = Locationrule.create_by(params, @did)
    if rule.save
      flash[:status] = _('Rule_added')
    else
      flash_errors_for(_('Rule_not_created'), rule)
    end
    redirect_to(action: 'location_rules', id: params_location_id, s_user: params[:s_user], s_user_id: params[:s_user_id])
  end

  def location_devices
    @page_title = _('Location_devices')
    @page_icon = 'device.png'

    @devices = @location.devices
    @locations = current_user.locations
  end

  def location_change
    device = Device.where(id: params[:id]).first
    unless  device
      flash[:notice] = _('Device_was_not_found')
      redirect_to(action: 'localization') && (return false)
    end
    old_loc = device.location_id
    device.location = Location.where(id: params[:location]).first
    if device.save
      flash[:notice] = _('Device_location_changed_and_moved_to_another_group')
    else
      flash_errors_for(_('Device_location_dont_changed'), device)
    end
    redirect_to(action: 'location_devices', id: old_loc) && (return false)
  end

  def location_add
    loc = Location.new(name: params[:name])
    loc.save ? flash[:status] = _('Location_added') : flash_errors_for(_('Please_enter_name'), loc)
    redirect_to(action: 'localization') && (return false)
  end

  def location_destroy
    devices = @location.devices.count
    cardgroups = Cardgroup.where("location_id = #{@location.id}").size

    if devices == 0 && cardgroups == 0 && @location.destroy_all
      flash[:status] = _('Location_deleted')
    elsif devices > 0 || cardgroups > 0
      flash[:notice] = _('Location_is_assigned_to_device_or_cardgroup')
    else
      flash_errors_for(_('Location_not_deleted'), @location)
    end
    redirect_to(action: 'localization')
  end

  # Ticket 3495 ------------
  def import_admins_locations
    @page_title = _('Import_admins_locations_with_rules')
    if reseller?  && (Confline.get_value('disallow_coppy_localization').to_i != 1)
      @locations = Location.where(user_id: 0).order('name ASC')
    else
      dont_be_so_smart
      redirect_to :root
    end
  end

  def admins_location_rules
    if reseller?
      @page_title = _('Admins_location_rules')
      @location = Location.where(id: params[:id]).first
      @rules = @location.locationrules
      location_id = @location.id
      @grules_dst = Locationrule.where(['location_id =? and lr_type =?', 1, 'dst']).order('name ASC')
      @grules_src = Locationrule.where(['location_id =? and lr_type =?', 1, 'src']).order('name ASC')
      @rules_dst = Locationrule.where(['location_id =? and lr_type =?', location_id, 'dst']).order('name ASC')
      @rules_src = Locationrule.where(['location_id =? and lr_type =?', location_id, 'src']).order('name ASC')
      render :location_rules
    else
      dont_be_so_smart
      redirect_to :root
    end
  end

  def delete_and_import_admins_location
    if reseller?
      # find all resellers locations and delete them
      @locations = Location.where(user_id: correct_owner_id).order('name ASC')
      @locations.each { |location| location.destroy_all }

      # create new default location
      current_user.create_reseller_localization
      current_user_id = current_user.id
      location_id = Confline.get_value('Default_device_location_id', current_user_id).to_i
      # change all devices and cardgroups locations (providers location id is in his device location_id)
      Device.update_all "location_id = #{location_id}", "user_id IN (SELECT id from users where owner_id = #{current_user_id}) OR id IN (SELECT device_id FROM providers WHERE user_id = #{current_user_id})"
      Cardgroup.update_all "location_id = #{location_id}", "owner_id = #{current_user_id}"
      # get all admins locations with rules
      admins_locations = Location.where('locations.user_id=? and locations.name != ?', 0, 'Global').includes([:locationrules]).all

      admins_locations.each do |a_location|
        a_location_user_id = a_location.user_id
        loc = Location.new(name: a_location.name, user_id: a_location_user_id)
        loc.save
        logger.fatal('Location created')

        a_location.locationrules.each do |a_rules|
          rule = Locationrule.create_by_rule(a_rules, loc)

          rule.save
          logger.fatal('rule created')
        end
      end
      redirect_to(action: 'localization')
      flash[:status] = _('Old_Locations_deleted_and_new_Locations_added')
    end
  end

  #-----------

  private

  def find_location_rule
    @rule = Locationrule.where(id: params[:id]).first
    unless @rule
      flash[:notice] = _('Location_rule_was_not_found')
      redirect_to(action: 'localization') && (return false)
    end
    check_location_rule_owner
  end

  def find_location
    @location = Location.where(id: params[:id]).first
    unless @location
      flash[:notice] =_('Location_was_not_found')
      redirect_to(action: 'localization') && (return false)
    end
    check_location_owner
  end

  def check_location_owner
    unless @location.user_id == correct_owner_id
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def check_location_rule_owner
    rule_location = @rule.location
    unless rule_location && rule_location.user_id == correct_owner_id
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def check_permsission
    unless allow_manage_providers?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def find_tariffs
    if Confline.get_value('User_Wholesale_Enabled').to_i == 0
      cond = " AND purpose = 'user' "
    else
      cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    end
    @tariffs = Tariff.where("owner_id = '#{session[:user_id]}' #{cond} ").order('purpose ASC, name ASC')
  end

  def set_help_link
    @help_link = 'http://wiki.kolmisoft.com/index.php/Number_Manipulation'
  end

  def fields_from_parameters
    @s_user = params[:s_user] || ''
    @s_user_id = params[:s_user_id] || -2
  end
end
