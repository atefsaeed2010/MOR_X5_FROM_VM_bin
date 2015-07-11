# -*- encoding : utf-8 -*-
class GroupsController < ApplicationController
  layout "callc"

  before_filter :check_post_method, only: [:destroy, :create, :update, :add_member, :remove_member]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_user, only: [:change_member_type, :remove_member]
  before_filter :check_user_type, only: [:members, :change_member_type, :add_member, :remove_member, :change_position]
  before_filter :find_group, only: [:show, :edit, :update, :destroy, :members, :add_member, :remove_member, :manager_members, :callshop_management, :member_stats, :member_stats_update, :change_member_type, :change_position]
  before_filter :allow_add_callshop?, only: [:new]
  before_filter :allow_add_callbooth?, only: [:add_member]

  @@callshop_view = []
  @@callshop_edit = [:index, :list, :show, :new, :create, :edit, :update, :destroy, :members, :change_member_type, :change_position, :add_member, :remove_member, :manager_list, :manager_members, :callshop_management, :member_stats, :member_stats_update, :group_member_devices]
  before_filter(:only => @@callshop_view+@@callshop_edit) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@callshop_view, @@callshop_edit, {:role => "reseller", :right => :res_call_shop, :ignore => true})
    c.instance_variable_set :@callshop, allow_read
    c.instance_variable_set :@callshop, allow_edit
  }

  def index
    redirect_to(action: :list) && (return false)
  end

  def list
    @page_title = _('Callshops')

    @groups = Group.where(owner_id: current_user.id).includes(:translation)
    @groups = @groups.limit(1) unless call_shop_active?

    @allow_add_cs = ((Group.where(owner_id: current_user.id).count < 1) || call_shop_active?)
  end

  def show
    @page_title = _('Group_details')
  end

  def new
    @page_title = _('New_callshop')
    @page_icon = 'add.png'
    @group = Group.new
  end

  def create
    group_params = params[:group]
    group_params[:balance].to_s.gsub!(/[\,\;]/, '.')

    @group = Group.new(group_params)
    @group.assign_attributes(user: current_user, grouptype: 'callshop')

    if @group.update_simple_session(group_params)
      flash[:status] = _('Call_shop_was_successfully_created')
      redirect_to action: 'list'
    else
      flash_errors_for(_('Call_shop_was_not_created'), @group)
      render :new, params: group_params
    end
  end

  def edit
    @page_title = _('Edit_group')
    @page_icon = 'edit.png'
  end

  def update
    params[:group][:balance].to_s.gsub!(/[\,\;]/, '.')

    @group.update_attributes(params[:group])

    if @group.update_simple_session(params[:group])
      flash[:status] = _('Call_shop_was_successfully_updated')
      redirect_to action: 'list' # , :id => @group
    else
      flash_errors_for(_('Call_shop_was_not_updated'), @group)
      render :edit, group: params[:group]
    end
  end

  def destroy
    callshop = Callshop.includes(:users => [:cs_invoices]).
        where("groups.id = ? AND usergroups.gusertype = 'user'", params[:id]).first
    active_calls = callshop.present? ? callshop.users.select { |user| user.booth_status == 'occupied' }.size.to_i : 0

    @group.errors.add(:callshop_has_active_calls, _('Call_Shop_has_Active_Calls')) if active_calls > 0

    if @group.errors.blank? && @group.valid?
      @group.destroy
      CsInvoice.where(callshop_id: params[:id]).delete_all
      flash[:status] = _('Call_shop_was_successfully_deleted')
    else
      flash_errors_for(_('Call_Shop_was_not_deleted'), @group)
    end
    session[:manager_in_groups] = User.find(session[:user_id]).manager_in_groups
    redirect_to action: 'list'
  end

  def members
    @page_title = _('Callshops') + " '" + @group.name + "' " + _('Phone_booths')
    @users = User.includes(:usergroups).
                  where(["(hidden = 0) AND (owner_id = #{current_user.id}) AND (usertype = 'user') AND (id <> #{current_user.id})"]).all
    @free_users = []

    # User can't see more than 2 call booths in free mode
    @manager_users, @simple_users = @group.get_members(call_shop_active?)

    group_users = @group.users
    @users.each { |user| @free_users << user if !group_users.include?(user) && user.usergroups.empty? }
    store_location

    @allow_add_member = ((Usergroup.where(group_id: @group.id).count < 2) || call_shop_active?)
  end

  def change_member_type
    @user.group_member_type(@group)

    session[:manager_in_groups] = @user.manager_in_groups

    flash[:status] = _('Call_booths_type_was_successfully_changed')
    redirect_to action: 'members', id: @group
  end

  def change_position
    find_user(params[:member_id])

    if @group.move_member(@user, params[:direction])
      flash[:status] = _('Booth_order_was_updated')
    end

    redirect_back_or_default('/groups/list')
  end

  def add_member
    find_user(params[:new_member])

    if @user.is_user? && @user.owner_id == correct_owner_id
      usergroup, success = @group.add_group(@user, params)
    end
    if success
      flash[:status] = _('Call_booth_was_successfully_added')
    else
      flash_errors_for(_('Call_booth_was_not_added'), usergroup)
    end
    redirect_to action: 'members', id: params[:group]
   end

  def remove_member
    member = Usergroup.where(['user_id = ? AND group_id = ?', @user.id, @group.id]).first
    if member
      member.destroy
      session[:manager_in_groups] = @user.manager_in_groups

      flash[:status] = _('Call_booth_was_successfully_removed')
    end
    redirect_to action: 'members', id: @group
  end

  def manager_list
    find_user(session[:user_id])
    @page_title = _('Groups')
    # @group_pages, @groups = paginate :groups, :per_page => 10
    @groups = @user.groups
  end

  def manager_members
    find_user(session[:user_id])
    authorize_group_manager(@group.id)

    change_date

    @page_title = _('Groups') + " '" + @group.name + "' " + _('members')
    # @users = User.find(:all)
    @calls = []
    @durations = []

    @group.users.each_with_index do |member, index|
      @calls[i] = member.total_calls('answered', session_from_datetime, session_till_datetime) + member.total_calls('answered_inc', session_from_datetime, session_till_datetime)
      @durations[index] = member.total_duration('answered', session_from_datetime, session_till_datetime) + member.total_duration('answered_inc', session_from_datetime, session_till_datetime)
    end

    # changing the state user logged status
    if params[:member]
      user, action = User.member_toggler_login
      add_action(user.id, action, '')  unless action.blank?

    end

    @search = 0
    @search = 1 if params[:search_on]
  end

  def callshop_management
    change_date

    authorize_group_manager(@group.id)

    @page_title = _('Callshop') + ': ' + @group.name
    @calls = []
    @durations = []

    @date_from = session_from_datetime
    @date_till = session_till_datetime

    @group.simple_users.each_with_index do |member, index|
      @calls[index] = member.total_calls('answered', @date_from, @date_till)
      @durations[index] = member.total_billsec('answered', @date_from, @date_till)
    end

    # changing the state user logged status
    if params[:member]
      user, action = User.member_toggler_login
      add_action(user.id, action, '') unless action.blank?
    end
  end

  def member_stats
    @page_title = _('Member_stats')

    authorize_group_manager(@group.id)

    # changing stats
    #    if params[:member]
    #      member = User.find(params[:member])
    #      member.sales_this_month = params[:sales_this_month]
    #      member.sales_this_month_planned = params[:sales_this_month_planned]
    #      member.save
    #   end
  end

  def member_stats_update
    @group.update_members(params)
    flash[:notice] = _('Member_stats_updated')
    redirect_to action: 'member_stats', id: @group.id
  end

  # manager can only view his groups
  def authorize_group_manager(group_id)
    can_proceed = false
    session[:manager_in_groups].each do |group|
      can_proceed = true if group.id.to_i == group_id.to_i
    end
    unless can_proceed
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :root
    end
  end

  def group_member_devices
    @page_title = _('Member_devices')
    @page_icon = 'device.png'
    find_user(params[:id])

    @devices = @user.devices
  end

  private

  def check_user_type
    if session[:usertype] == 'user'
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def find_group
    @group = Group.where(id: params[:group]).first unless params[:group].is_a?(Hash)
    @group = Group.where(id: params[:id]).first if @group.nil?

    unless @group
      flash[:notice] = _('Call_shop_was_not_found')
      redirect_to(:root) && (return false)
    end

    current_user_id = current_user.id.to_i
    unless @group.owner_id == current_user_id
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def allow_add_callshop?
    unless call_shop_active?
      if Group.where(owner_id: current_user.id).count >= 1
        flash[:notice] = _('You_have_no_view_permission')
        redirect_to :root
      end
    end
  end

  def allow_add_callbooth?
    unless call_shop_active?
      if Usergroup.where(group_id: @group.id).count >= 2
        flash[:notice] = _('You_have_no_view_permission')
        redirect_to :root
      end
    end
  end

  def find_user(id = nil)
    search_id = id || params[:user]
    unless @user = User.where(id: search_id.to_i).first
      flash[:notice] = _('User_was_not_found')
      redirect_to(:root) && (return false)
    end
  end
end
