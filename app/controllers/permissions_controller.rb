# -*- encoding : utf-8 -*-
class PermissionsController < ApplicationController
  layout 'callc'
  before_filter :check_localization
  before_filter :authorize_admin
  before_filter :check_group_type, except: [:acc_permissions_save, :accountant]
  before_filter :find_permissions_group, only: [:destory, :edit, :update, :accountant, :acc_permissions_save]
  before_filter :help_link, only: [:edit, :accountant, :list]

  def index
    redirect_to :root
  end

  def accountant
    @page_title = _('group_edit') + ': ' + @group.name
    @page_icon = 'edit.png'

    @rights = @group.acc_permissions.select([:name, :nice_name, :value])
    @template = Permissions.accountant

    unless @rights.blank?
      @template.each do |master, branches|
        branches.each do |name, _|
          permission = @rights.where(name: master + '_' + name).first
          if permission.present?
            branches.update(permission.nice_name => permission.value)
          end
        end
      end
    end
  end

  def acc_permissions_save
    group_id = @group.id
    values_to_update = {}
    values_to_update[:description] = params[:group][:description] || nil
    values_to_update[:only_view] = params[:only_view] || nil
    values_to_update[:name] = params[:name] || nil

    @group.assign_attributes(values_to_update)

    permission_save = Proc.new do |name, nice_name, val|
      init = {acc_group_id: group_id, name: name, nice_name: nice_name}
      permission = AccPermission.where(init).first
      if permission
        permission.update_attributes(value: val)
      else
        new_permission = AccPermission.new(init.update(value: val))
        new_permission.save
      end
    end

    Permissions.accountant.each do |master,branch|
      branch.each do |level_two_name, _|
        name = master + '_' + level_two_name
        permission_save[name, level_two_name, params[name]] unless params[name].blank?
      end
    end

    if @group.save
      flash[:status] = _('Group_was_updated')
    else
      flash_errors_for(_('Group_was_not_updated'), @group)
    end

    redirect_to(action: 'list', group_type: 'accountant') && (return false)
  end

  def list
    if params[:group_type].to_s == 'accountant'
      @page_title = _('Accountant_Groups')
    else
      @page_title = _('Reseller_Groups')
    end
    @page_icon = 'group.png'
    @groups = AccGroup.where(['group_type = ?', params[:group_type]])
  end

=begin rdoc
 Creates a accountant group.

 *Params*:

 * +name+ - goup name

 *Flash*

 * +Group_was_created+ - if group was successfully created.
 * +Group_was_not_created+ - if group was not successfully created.

 *Redirect*

 * +groups_list+
=end

  def create
    group = AccGroup.create_by(params)
    if group.save
      group.create_empty_permissions
      flash[:status] = _('Group_was_created')
    else
      flash_errors_for(_('Group_was_not_created'), group)
    end
    redirect_to(action: 'list', group_type: params[:group_type]) && (return false)
  end

=begin rdoc
 Destroys group

 *Params*:

 * +id+ - group id

 *Flash*:

 * Group_was_destroyed - if group was successfully destroyed
 * Group_was_not_destroyed - if group was not successfully destroyed

 *Redirect*

 * +groups_list+
=end
  def destory
    if @group.destroy
      User.update_all('acc_group_id = NULL', ['acc_group_id = ?', @group.id])
      flash[:status] = _('Group_was_destroyed')
    else
      flash_errors_for(_('Group_was_not_destroyed'), @group)
    end
    redirect_to(action: 'list', group_type: params[:group_type]) && (return false)
  end

=begin rdoc
 Opens edit form for accountant group.

 *Params*:

 * +id+ - group id

=end

  def edit
    @page_title = _('group_edit') + ': ' + @group.name
    @page_icon = 'edit.png'
    @rights = @group.rights_by_condition(payment_gateway_active?, sms_active?, pbx_active?, calling_cards_active?)
  end


  def update
    @group.assign_attributes(name: params[:name].to_s,
                             only_view: params[:only_view].to_i,
                             description: params[:group][:description].to_s)
    if @group.save
      @group.update_rights(params)
      flash[:status] = _('Group_was_updated')
    else
      flash_errors_for(_('Group_was_not_updated'), @group)
    end
    redirect_to(action: 'edit', id: params[:id], group_type: params[:group_type]) && (return false)
  end

  private

  def find_permissions_group
    params[:group_type] = 'accountant' if ['accountant', 'acc_permissions_save'].member? params[:action]
    @group = AccGroup.where(['id = ? AND group_type = ?', params[:id], params[:group_type]]).first
    unless @group
      flash[:notice] = _('Group_was_not_found')
      redirect_to(action: 'groups_list') && (return false)
    end
  end

  def check_group_type
    unless ['reseller', 'accountant'].include?(params[:group_type])
      flash[:notice] = _('Group_was_not_found')
      redirect_to(:root) && (return false)
    end
  end

  def help_link
    @help_link = 'http://wiki.kolmisoft.com/index.php/'
    if params[:group_type].to_s == 'reseller'
      @help_link << 'Reseller_permissions'
    else
      @help_link << 'Accountant_permissions'
    end
  end
end
