# -*- encoding : utf-8 -*-
class ServicesController < ApplicationController

  layout "callc"

  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization

  before_filter :authorize
  @@susbscription_view = [:subscriptions, :subscriptions_list]
  @@susbscription_edit = [:subscription_new, :subscription_create, :subscription_destroy, :subscription_confirm_destroy, :subscription_edit, :subscription_update]
  @@service_view = [:list]
  @@service_edit = [:new, :create, :update, :edit, :destroy]

  before_filter { |c|
    c.instance_variable_set :@allow_read, true
    c.instance_variable_set :@allow_edit, true
  }

  before_filter(:only => @@susbscription_view+@@susbscription_edit) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@susbscription_view, @@susbscription_edit, {:role => "accountant", :right => :acc_manage_subscriptions_opt_1})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter(:only => @@service_view+@@service_edit) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@service_view, @@service_edit, {:role => "accountant", :right => :acc_services_manage})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter :find_service, :only => [:show, :edit, :update, :destroy, :destination_prefix_find, :destinations, :destination_add, :destination_destroy, :destination_prefix_find, :destination_prefixes]
  before_filter :find_services, :only => [:index, :list, :subscriptions, :subscription_new]
  before_filter :find_user, :only => [:subscriptions_list, :subscription_create, :subscription_new]
  before_filter :find_subscription, :only => [:subscription_edit, :subscription_update, :subscription_confirm_destroy]
  before_filter :set_instances_from_params, :only =>[:subscriptions_list, :subscription_edit, :subscription_update, :subscription_confirm_destroy, :subscription_confirm_destroy]

  # @services in before filter
  def index
    redirect_to action: 'list' and return false
  end

  # @services in before filter
  def list
    @page_title = _('Services')
    @help_link  = 'http://wiki.kolmisoft.com/index.php/Services'
  end

  # @service in before filter
  def show
    @page_title = _('Service')
  end

  def new
    @page_title = _('New_service')
    @page_icon  = 'add.png'
    @service    = Service.new
  end

  def create
    @page_title = _('New_service')
    @page_icon  = 'add.png'
    @service = Service.new(params[:service])
    @service.assign_attributes(owner_id: correct_owner_id)
    if @service.save
      flash[:status] = _('Service_was_successfully_created')
      redirect_to action: 'list'
    else
      flash_errors_for(_('Service_was_not_created'), @service)
      render :new
    end
  end

  # @service in before filter
  def edit
    @page_title = _('Edit')
    @page_icon = 'edit.png'
  end

  # @service in before filter
  def update
    @page_title = _('Edit')
    @page_icon = 'edit.png'
    if accountant? && !accountant_can_write?('see_financial_data')
      params[:service].delete(:price)
      params[:service].delete(:selfcost_price)
    end
    if @service.update_attributes(params[:service])
      flash[:status] = _('Service_was_successfully_updated')
      redirect_to action: 'list'
    else
      flash_errors_for(_('Service_was_not_updated'), @service)
      render :edit
    end
  end

  # @service in before filter
  def destroy
    if @service.destroy
      flash[:status] = _('Service_deleted')
    else
      flash_errors_for(_('Service_was_not_deleted'), @service)
    end
    redirect_to action: 'list'
  end

  # @service in before filter
  def destinations
    @page_title = _('Flat_rate_destinations')
    @page_icon = 'actions.png'
    @enabled_labels = [[_('Include'), 1], [_('Exclude'), 0]]

    @flatrate_destinations = FlatrateDestination.get_by_service_id(params[:id])

    @directions = Direction.all
    @diff_directions = @flatrate_destinations.map { |dest| dest.destination.direction_code if (dest and dest.destination) }.uniq
    @prefixes = @flatrate_destinations.map { |fl| fl.destination.prefix }
    @destinations = Destination.where(['direction_code = ?', @directions[0].code])
    @destinations = @destinations.map { |d| d if !@prefixes.include?(d.prefix) }.compact
  end

  # @service in before filter
  def destination_add
    if params[:submit_icon] == 'prefix_find'
      @destination = Destination.where(['prefix = ?', params[:search_1]]).first
      @enabled = params[:enabled_1].to_i
    end

    if params[:submit_icon] == 'country_find'
      @destination = Destination.where(['prefix = ?', params[:pre]]).first
      @enabled = params[:enabled].to_i
    end

    service_id =  @service.id
    if @destination
      if FlatrateDestination.where(['destination_id = ? AND service_id = ?', @destination.id, service_id]).first
        flash[:notice] = _('Destination_already_in_flatrate')
        redirect_to(action: 'destinations', id: service_id) and return false
      end
    else
      flash[:notice] = _('Destination_not_found')
      redirect_to(action: 'destinations', id: service_id) and return false
    end

    flatrate_destination = FlatrateDestination.new(service: @service, destination: @destination, active: @enabled.to_i)

    if flatrate_destination && flatrate_destination.save
      flash[:status] = _('Flatrate_destination_created')
    else
      flash[:notice] = _('Flatrate_destination_not_created')
    end

    redirect_to(action: 'destinations', id: service_id)
  end

  # @service in before filter
  def destination_destroy
    @flatrate_destination = @service.flatrate_destinations.where(['flatrate_destinations.id = ?', params[:destination_id]]).first
    unless @flatrate_destination
      flash[:notice] = _('Flatrate_destination_not_found')
      redirect_to action: :list and return false
    end

    if @flatrate_destination.destroy
      flash[:status] = _('Flatrate_destination_destroyed')
    else
      flash[:notice] = _('Flatrate_destination_not_destroyed')
    end
    redirect_to action: 'destinations', id: @flatrate_destination.service_id
  end

  # @service in before filter
  def destination_prefix_find
    @flatrate_destinations = FlatrateDestination.includes(:destination).where(['service_id = ?', @service.id]).all
    @prefixes = @flatrate_destinations.map { |fl| fl.destination.prefix }
    if params[:find_by] == 'direction'
      @destinations = Destination.where(['direction_code = ?', params[:direction]])
      @destinations = @destinations.map { |d| d if !@prefixes.include?(d.prefix) }.compact
      render(layout: false) and return false
    end

    if params[:find_by] == 'prefix'
      @dest = Destination.where(["prefix = SUBSTRING(?, 1, LENGTH(destinations.prefix))", params[:direction]]).
                          order("LENGTH(destinations.prefix) DESC").first if @phrase != ''
      @results = ''

      if @dest
        @direction, @results, @message = @dest.get_direction(@service.id)
      end
      render(layout: false)
    end
  end

  # @service in before filter
  def destination_prefixes
    params[:page].to_i > 0 ? @page = params[:page].to_i : @page = 1
    @per_page = Confline.get_value('Items_Per_Page').to_i
    @pos = []
    @neg = []
    @direction = Direction.where(['code = ?', params[:direction]]).first
    unless @direction
      @message = _('Direction_not_found')
    end
    @flatrate_destinations = FlatrateDestination.includes(:destination).joins("LEFT JOIN destinations ON (flatrate_destinations.destination_id = destinations.id)").where(["destinations.direction_code = ? and service_id = ?", params[:direction], params[:id]]).order("length(destinations.prefix)").all
    @destinations = []

    @flatrate_destinations.each { |dest|
      @dest = Destination.where(['prefix LIKE ?', dest.destination.prefix.to_s + '%'])
      dest.active.to_i == 1 ? @destinations += @dest : @destinations -= @dest
    }

    @total_pages = (@destinations.size.to_d / session[:items_per_page].to_d).ceil
    @destinations = @destinations[(@page - 1) * session[:items_per_page], session[:items_per_page]].to_a

    render(layout: 'layouts/mor_min')
  end

  # =============== Subscriptions groups =================

  def subscriptions
    @page_title = _('Subscriptions')
    @page_icon = 'layers.png'

    change_date

    @search_device = -1
    @search_user = ''
    @search_user_id = params[:s_user_id] if params[:s_user_id]
    @search_service = -1
    @search_date_from = -1
    @search_date_till = -1
    @search_memo = params[:s_memo] || ''
    @search_user = params[:s_user] if params[:s_user]
    @search_service = params[:s_service] if params[:s_service]
    @search_device = params[:device_id] if params[:device_id]
    @until_canceled = params['until_canceled'].to_i
    if params[:clear].to_s == 'true'
      session[:year_from] = Date.today.year
      session[:month_from] = Date.today.month
      session[:day_from] = Date.today.day
      session[:year_till] = Date.today.year
      session[:month_till] = Date.today.month
      session[:day_till] = Date.today.day
    end

    session[:hour_from] = '00'
    session[:minute_from] = '00'
    session[:hour_till] = '23'
    session[:minute_till] = '59'

    cond = ''

    if (@search_user_id.to_i != -2 && @search_user_id.present?) || (@search_user_id.to_i == -2 && @search_user.present?)
      cond = "  AND subscriptions.user_id = '#{@search_user_id}' "
      if @search_device.to_i != -1
        cond += " AND subscriptions.device_id = '#{@search_device}' "
      end
    end

    if @search_service.to_i != -1
      cond += " AND subscriptions.service_id = '#{@search_service}' "
    end
    period_start = "'#{session_from_datetime}'"
    period_end = "'#{session_till_datetime}'"
    until_canceled = 'subscriptions.activation_end IS NULL OR ' if @until_canceled == 1
    cond << " AND (subscriptions.activation_start >= #{period_start} AND (#{until_canceled}subscriptions.activation_end <= #{period_end})) "

    cond += " AND subscriptions.memo = '#{@search_memo}' " if @search_memo.length > 0

    sql = "SELECT services.name as serv_name , users.first_name, users.last_name, users.username, subscriptions.*, devices.device_type,  devices.name, devices.extension, devices.istrunk, devices.ani, providers.device_id AS provider
            FROM subscriptions
            LEFT JOIN users ON(users.id = subscriptions.user_id)
            LEFT JOIN devices ON(devices.id = subscriptions.device_id)
            LEFT JOIN providers ON(providers.device_id = devices.id)
            LEFT JOIN services ON(services.id = subscriptions.service_id)
            WHERE subscriptions.id > '0' AND users.owner_id = #{correct_owner_id} #{cond}"
    # MorLog.my_debug sql
    @search = 0
    @search = 1 if cond.length > 93
    @subs = Subscription.find_by_sql(sql)

    @page = 1
    @page = params[:page].to_i if params[:page]
    items_per_page = session[:items_per_page]
    @total_pages = (@subs.size.to_d / items_per_page.to_d).ceil
    @all_subs = @subs
    @subs = []
    items_per_page = session[:items_per_page]
    iend = ((items_per_page * @page) - 1)
    iend = @all_subs.size - 1 if iend > (@all_subs.size - 1)
    for index in ((@page - 1) * items_per_page)..iend
      @subs << @all_subs[index]
    end

    @min_end, @min_start, @max_end, @max_start = Subscription.get_activation_year
  end

  # @user in before filter
  def subscriptions_list
    @page_title = _('Subscriptions')
    @page_icon = 'layers.png'

    if params[:id].to_i == 0
      redirect_to action: 'subscriptions' and return false
    end

    if @user.try :is_accountant?
      flash[:notice] = _('Subscriptions_were_not_found')
      redirect_to :root and return false
    end

    @subs = @user.subscriptions(include: [:service])
  end

  # @services in before filter
  def subscription_new
    @page_title = _('New_subscription')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Subscriptions'

    if @user.try :is_accountant?
      flash[:notice] = _('User_was_not_found')
      redirect_to :root and return false
    end

    @sub = Subscription.new

    @sub.activation_start = @sub.activation_end = Time.now

    # form cache
    session[:subscription_create].try(:each) do |key, val|
      @sub[key.to_sym] = val if @sub.respond_to? key.to_sym
    end
    session.try(:delete, :subscription_create)

    if @services.empty?
      flash[:notice] = _('No_services_to_subscribe')
      redirect_to action: 'subscriptions_list', id: @user.id
    end
  end

  def subscription_create
    @sub = Subscription.new(params[:subscription])
    @until_canceled = params['until_canceled'].to_i

    activation_start = user_time_from_params(*params['activation_start'].try(:values))
    if @until_canceled == 0
      activation_end = user_time_from_params(*params['activation_end'].try(:values))
    else
      activation_end = nil
    end

    user_id = @user.id
    @sub.assign_attributes(activation_end: activation_end, activation_start: activation_start)
    @sub.update_by(user_id, params)
    if @sub.save
      Action.add_action_hash(current_user.id, action: 'Subscription_added', target_id: @sub.id, target_type: 'Subscription', data: @sub.user_id, data2: @sub.service_id)

      if @user.user_type == 'prepaid'
        if @sub.service.periodtype == 'month'
          period_end = Time.now.end_of_month.change(hour: 23, min: 59, sec: 59)
        else
          period_end = Time.now.change(hour: 23, min: 59, sec: 59)
        end

        subscription_price = @sub.price_for_period(Time.now.beginning_of_day, period_end)
        if subscription_price.to_d != 0
          if (@user.balance - subscription_price) < 0
            @sub.destroy
            flash[:notice] = _('insufficient_balance')
            redirect_to action: 'subscriptions_list', id: user_id and return false
          else
            # Future subscriptions Shouldn't be charged Right away
            if @sub.activation_start.strftime("%Y%m") == Time.now.strftime("%Y%m")
              MorLog.my_debug("Prepaid user:#{user_id} Subscription:#{@sub.id} Price:#{subscription_price} Period:#{Time.now.beginning_of_day}-#{period_end}")
              @user.balance -= subscription_price
              @user.save
              Payment.subscription_payment(@user, subscription_price)
              Action.new(user_id: user_id, target_id: @sub.id, target_type: 'subscription', date: Time.now, action: 'subscription_paid', data: "#{Time.now.year}-#{Time.now.month}#{('-' + Time.now.day.to_s) if @sub.service.periodtype == 'day'}", data2: subscription_price).save
            end
          end
        end
      end

      flash[:status] = _('Subscription_added')
      redirect_to action: 'subscriptions_list', id: params[:id] and return false
    else
      flash_errors_for(_('subscription_not_created'), @sub)
      session[:subscription_create] = {
        activation_start: @sub.activation_start,
        activation_end:   @sub.activation_end,
        memo:             @sub.memo
      }
      redirect_to action: 'subscription_new', id: params[:id] and return false
    end
  end

  # @sub in before filter
  def subscription_edit
    @page_title = _('Edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Subscriptions'

    # form cache
    session[:subscription_edit].try(:each) do |key, val|
      @sub[key.to_sym] = val if @sub.respond_to? key.to_sym
    end
    session.try(:delete, :subscription_edit)

    @user = @sub.user
    @services = Service.order('name ASC')
  end

  # @sub in before filter
  def subscription_update
    @until_canceled = params[:until_canceled].to_i

    @service = @sub.service
    @sub.memo = params[:memo]
    @sub.no_expire = params[:no_expire].to_i
    ld1 = last_day_of_month(params[:activation_start][:year], params[:activation_start][:month]).to_i
    params[:activation_start][:day] = ld1 if params[:activation_start][:day].to_i > ld1.to_i

    activation_end = nil
    if (@until_canceled == 0) && (@sub.service.servicetype != 'one_time_fee')
      if params[:activation_end].nil?
        redirect_to action: 'subscription_edit', id: @sub.id and return false
      else
        ld2 = last_day_of_month(params[:activation_end][:year], params[:activation_end][:month]).to_i
        params[:activation_end][:day] = ld2 if params[:activation_end][:day].to_i > ld2.to_i
        activation_end   = user_time_from_params(*params['activation_end'].values)
      end
    end

    activation_start = user_time_from_params(*params['activation_start'].values)

    if @service.servicetype == 'flat_rate'
      activation_start = activation_start.beginning_of_month.change(hour: 0, min: 0, sec: 0)
      activation_end = activation_end.end_of_month.change(hour: 23, min: 59, sec: 59) unless @until_canceled == 1
    end

    @sub.assign_attributes(activation_start: activation_start, activation_end: activation_end)

    if @sub.save
      flash[:status] = _('Subscription_updated')
      if @back.to_s == 'subscriptions'
        redirect_to action: 'subscriptions', s_memo: @search_memo, s_service: @search_service, s_user: @search_user, s_device: @search_device, s_date_from: @search_date_from, s_date_till: @search_date_till, page: @page
      else
        redirect_to action: 'subscriptions_list', id: @sub.user.id
      end
    else
      flash_errors_for(_('subscription_not_updated'), @sub)
      if @back.to_s == 'subscriptions'
        redirect_to action: 'subscriptions', s_memo: @search_memo, s_service: @search_service, s_user: @search_user, s_device: @search_device, s_date_from: @search_date_from, s_date_till: @search_date_till, page: @page
      else
        redirect_to action: 'subscription_edit', id: @sub.id
        session[:subscription_edit] = {
          activation_start: @sub.activation_start,
          activation_end:   @sub.activation_end,
          memo:             @sub.memo
        }
      end
    end
  end

  def subscription_confirm_destroy
    @page_title = _('Subscriptions')
    @page_icon = 'delete.png'
    @user = @sub.user
    unless @user
      flash[:notice] = _('User_not_found')
      redirect_to action: 'subscriptions' and return false
    end
  end

  def subscription_destroy
    @sub, notice = Subscription.get_subscription(params[:id])
    unless notice.blank?
      flash[:notice] = notice
      if notice == _('Subscription_not_found')
        redirect_to action: 'subscriptions' and return false
      else
        redirect_to :root and return false
      end
    end

    status = @sub.delete_by_option(params[:delete], current_user_id)
    unless status.blank?
      flash[:status] = status
      @sub.destroy unless status == _('Subscription_disabled')
    end

    if @back.to_s == 'subscriptions'
      redirect_to action: 'subscriptions', s_memo: @search_memo, s_service: @search_service, s_user: @search_user, s_device: @search_device, s_date_from: @search_date_from, s_date_till: @search_date_till, page: @page
    else
      redirect_to action: 'subscriptions_list', id: @sub.user.id
    end
  end

  def user_subscriptions
    @page_title = _('Subscriptions')
    @page_icon = 'layers.png'

    unless user? or reseller?
      dont_be_so_smart
      redirect_to :root and return false
    end

    @user = User.find(session[:user_id])
    @subs = @user.subscriptions(:include => [:service])
  end

  private

  def find_service
    @service = Service.where(['id = ? AND owner_id = ? ', params[:id], correct_owner_id]).first
    unless @service
      flash[:notice] = _('Service_was_not_found')
      redirect_to :root and return false
    end
  end

  def find_services
    @services = Service.where(['services.owner_id = ?', correct_owner_id]).order('name ASC')
  end

  def find_user
    @user = User.includes([:subscriptions]).where(['users.id = ? AND users.owner_id = ?', params[:id], correct_owner_id]).first
    unless @user
      flash[:notice] = _('User_Was_Not_Found')
      redirect_to :root and return false
    end
  end

  def find_subscription
    @sub = Subscription.includes(:user, :service).where(['subscriptions.id = ? ', params[:id]]).first
    unless @sub
      flash[:notice] = _('Subscription_not_found')
      redirect_to :root and return false
    end

    service = @sub.service
    unless service && service.owner_id == correct_owner_id
      flash[:notice] = _('Subscription_not_found')
      redirect_to :root and return false
    end
  end

  def set_instances_from_params
    page = params[:page]
    back = params[:back]
    s_user = params[:s_user]
    s_service = params[:s_service]
    device_id = params[:device_id]
    s_memo = params[:s_memo]
    s_date_from = params[:s_date_from]
    s_date_till = params[:s_date_till]

    @page = page if page
    @back = back if back
    @search_user = s_user if s_user
    @search_service = s_service if s_service
    @search_device = device_id if device_id
    @search_memo = s_memo if s_memo
    @search_date_from = s_date_from if s_date_from
    @search_date_till = s_date_till if s_date_till
  end
end
