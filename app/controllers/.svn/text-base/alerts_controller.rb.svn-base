# -*- encoding : utf-8 -*-
# controller to show alerts in GUI
class AlertsController < ApplicationController

  layout 'callc'

  before_filter(:check_post_method,
                only: [:alert_add, :alert_update, :alert_destroy, :contact_add, :contact_update, :contact_destroy,
                       :group_add, :group_update, :group_destroy, :schedule_destroy, :schedule_add, :schedule_update, :group_contact_add]
  )
  before_filter :check_localization
  before_filter :access_denied, if: lambda { !admin? }
  before_filter :find_contact, only: [:contact_toggle, :contact_destroy, :contact_edit, :contact_update]
  before_filter :find_group, only: [:group_contacts, :group_edit, :group_update, :group_destroy, :group_toggle]
  before_filter :find_schedule, only: [:schedule_toggle, :schedule_destroy, :schedule_edit, :schedule_update]
  before_filter :find_alert, only: [:alert_edit, :alert_update, :alert_destroy, :alert_toggle]
  before_filter :set_alert_check_data, only: [:alert_update, :alert_add]
  before_filter :allow_more_alerts?, only: [:alert_new]
  before_filter :set_alert_parameters, only: [:alert_new, :alert_add, :alert_edit, :alert_update]

  after_filter(:update_alerts_service,
               only: [:alert_add, :alert_update, :alert_destroy, :contact_add, :contact_update, :contact_destroy, :group_add, :group_update,
                      :group_destroy, :schedule_destroy, :schedule_add, :schedule_update, :contact_toggle, :group_toggle,
                      :schedule_toggle, :alert_toggle]
  )

  def index
    redirect_to action: 'list'
  end

  def list
    @page_title = _('Alerts')
    @page_icon = 'bell.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Alerts'

    @options = session[:alerts_list_options] || {}
    page_opts = @options[:page]
    # search
    page_attributes = params[:page]
    page_attributes ? page_opts = page_attributes.to_i : (page_opts = 1 unless page_opts)

    # order
    order_desc_attributes = params[:order_desc]
    order_by_attributes = params[:order_by]

    order_desc_attributes ? @options[:order_desc] = order_desc_attributes.to_i : (@options[:order_desc] = 0 unless @options[:order_desc])
    order_by_attributes ? @options[:order_by] = order_by_attributes.to_s : (@options[:order_by] = 'id' unless @options[:order_by])

    order_by = Alert.alerts_order_by(@options)

    total_alerts = Alert.where(owner_id: corrected_user_id).count
    items_per_page = session[:items_per_page].to_i
    # page params
    @total_alerts_size = total_alerts.to_i
    @total_alerts_size = 5 if !monitorings_addon_active? && (total_alerts > 5)
    page_opts = page_opts.to_i < 1 ? 1 : page_opts.to_i
    @total_pages = (@total_alerts_size.to_d / items_per_page).ceil
    page_opts = @total_pages if page_opts.to_i > @total_pages.to_i && @total_pages.to_i > 0
    @page = page_opts
    @fpage = ((page_opts-1) * items_per_page).to_i
    @allow_add_alert = !(Alert.where(owner_id: corrected_user_id).count >= 5 && !monitorings_addon_active?)

    @options[:page] = page_opts

    @search = @options[:s_name].blank? ? 0 : 1
    joins = []
    joins << 'LEFT JOIN lcrs l_a ON (l_a.id = alerts.action_alert_change_lcr_id)'
    joins << 'LEFT JOIN lcrs l_c ON (l_c.id = alerts.action_clear_change_lcr_id)'
    joins << 'LEFT JOIN alert_groups ON (alert_groups.id = alerts.alert_groups_id)'
    sel = []
    sel << 'alerts.*'
    sel << 'l_a.id AS lcr_alert_id, l_a.name AS lcr_alert_name'
    sel << 'l_c.id AS lcr_clear_id, l_c.name AS lcr_clear_name'
    sel << 'alert_groups.id AS alert_group_id, alert_groups.name AS alert_group_name'

    @alerts = Alert.select(sel.join(', ')).joins(joins.join(' ')).
                    where(owner_id: corrected_user_id).order(order_by).
                    limit("#{@fpage}, #{items_per_page}").all

    # max 5cb, so don't show more in the last page
    max_alerts_number = 5
    last_page = (@page >= @total_pages)
    first_page = (@page == 1)
    if !monitorings_addon_active? && (total_alerts > max_alerts_number)
      if items_per_page >= max_alerts_number
        @alerts = @alerts[0...max_alerts_number]
      elsif last_page && !first_page
        last_alert = max_alerts_number % items_per_page
        last_alert = items_per_page if last_alert.zero?
        @alerts = @alerts[0...last_alert]
      else
        @alerts = @alerts[0..items_per_page]
      end
    end

    session[:alerts_list_options] = @options
  end

  def alert_new
    @page_title = _('New_Alert')
    @page_icon  = 'add.png'
    @help_link  = 'http://wiki.kolmisoft.com/index.php/Alerts'
    @action_link = 'alert_add'

    @check_types = ['user', 'provider', 'device', 'destination', 'destination_group']
    @alert_count_type = ['ABS']

    @alert  = Alert.new if @alert.nil?
    @lcrs   = Lcr.all
    @groups = AlertGroup.all
    @providers = current_user.providers.all
    @users = User.where(owner_id: corrected_user_id)
    @alert_check_data_user_id = 'all' if @alert_check_data_user_id.blank?
    @destination_groups = Destinationgroup.select("id, CONCAT(name, ' ', desttype) as gname").order('name ASC, desttype ASC').all
    @alert_dependencies = session[:alert_dependencies] = []
    @alerts_for_select = Alert.all
    session[:current_alert_id] = nil
    (render :alert_edit) && (return false)
  end

  def alert_edit
    @page_title = _('Alert_edit')
    @page_icon  = 'edit.png'
    @help_link  = 'http://wiki.kolmisoft.com/index.php/Alerts'
    @action_link = 'alert_update'

    @lcrs   = Lcr.all
    @groups = AlertGroup.all
    @providers = current_user.providers.all
    @users = User.where(owner_id: corrected_user_id)
    dev = Device.where(id: @alert.check_data).first
    @alert_check_data_user_id = dev ? dev.user_id : ''
    @destination_groups = Destinationgroup.select("id, CONCAT(name, ' ', desttype) as gname").order('name ASC, desttype ASC').all

    if params[:action] == 'alert_update'
      @alert_dependencies = session[:alert_dependencies]
    else
      session[:alert_dependencies] = @alert_dependencies = @alert.alert_dependency.all
    end
    session[:current_alert_id] = @alert.id
    alerts_in_dependencies = (@alert_dependencies.map { |alert| alert.alert_id }  + [@alert.id]).to_s.gsub(/[\]\[]/, '')
    @alerts_for_select = Alert.where("id NOT IN (#{alerts_in_dependencies}) && check_type = '#{@alert.check_type}'")

    (render :alert_edit) && (return false)
  end

  def alert_add
    alert_attributes = params[:alert]
    alert_dependencies = session[:alert_dependencies]
    alert_dependencies_number = alert_dependencies.count

    if alert_attributes[:alert_when_more_than].present? && alert_attributes[:alert_when_more_than].to_i != 0
      if alert_attributes[:alert_when_more_than].to_i >= alert_dependencies_number.to_i
        alert_attributes[:alert_when_more_than] = (alert_dependencies_number-1).to_i
      end
      alert_attributes[:alert_when_more_than] = 0 if alert_dependencies_number == 0
    end

    alert_attributes[:alert_groups_id] = alert_attributes[:alert_groups_id].to_i
    alert_attributes[:disable_provider_in_lcr] = alert_attributes[:disable_provider_in_lcr].to_i
    @alert = Alert.new(alert_attributes)
    @alert.apply_limitations

    clear_on_date_blank = 0
    params_clear_on_date = params[:clear_on_date]
    unless params_clear_on_date.nil?
      params_clear_on_date.each_value do |value|
        clear_on_date_blank += 1 if value.blank?
      end
    end
    if alert_attributes[:disable_clear].to_i == 1
      @alert.clear_on_date = nil
    elsif clear_on_date_blank == 0
      @alert.clear_on_date = user_time_from_params(*params['clear_on_date'].values)
    end

    @alert.notify_to_user = 0 unless @alert.check_type.to_s == 'user' || @alert.check_type.to_s == 'device'
    @alert.hgc = 0 unless ['hgc_absolute', 'hgc_percent'].include?(@alert.alert_type)

    if @alert.validation(current_user_id, clear_on_date_blank, alert_dependencies) && @alert.save
      alert_dependencies.try(:each) do |group|
        group.owner_alert_id = @alert.id
        group.save
      end
      flash[:status] = _('alert_successfully_created')
      (redirect_to action: 'list') && (return false)
    else
      @alert_check_data_user_id = params[:device_user]
      flash_errors_for(_('alert_was_not_created'), @alert)
      alert_new
    end
  end

  def alert_update
    alert_attributes = params[:alert]
    alert_dependencies = session[:alert_dependencies]
    alert_dependencies_number = alert_dependencies.count

    [:alert_if_more, :alert_if_less, :clear_if_more, :clear_if_less].each do |key|
      alert_attributes[key] = alert_attributes[key].to_d
    end
    if alert_attributes[:alert_when_more_than].present? && alert_attributes[:alert_when_more_than].to_i != 0
      if alert_attributes[:alert_when_more_than].to_i >= alert_dependencies_number.to_i
        alert_attributes[:alert_when_more_than] = (alert_dependencies_number-1).to_i
      end
      alert_attributes[:alert_when_more_than] = 0 if alert_dependencies_number == 0
    end
    @alert.attributes = @alert.attributes.merge(alert_attributes)
    @alert.apply_limitations

    clear_on_date_blank = 0
    clear_on_date_attributes = params[:clear_on_date]
    unless clear_on_date_attributes.nil?
      clear_on_date_attributes.each_value do |value|
        clear_on_date_blank += 1 if value.blank?
      end
    end

    if alert_attributes[:disable_clear].to_i == 1
      @alert.clear_on_date = nil
    elsif clear_on_date_blank == 0
      @alert.clear_on_date = user_time_from_params(*params['clear_on_date'].values)
    end

    if @alert.validation(current_user_id, clear_on_date_blank, alert_dependencies) && @alert.save
      @alert.alert_dependency = alert_dependencies
      flash[:status] = _('alert_successfully_updated')
      redirect_to(action: 'list') && (return false)
    else
      flash_errors_for(_('alert_was_not_updated'), @alert)
      alert_edit
    end
  end

  def alert_destroy
    if @alert.destroy
      flash[:status] = _('alert_successfully_deleted')
    else
      flash[:notice] = _('alert_was_not_deleted')
    end
    redirect_to action: 'list'
  end

  def contacts
    @page_title = _('alert_contacts')
    @page_icon	= 'vcard.png'
    @help_link  = 'http://wiki.kolmisoft.com/index.php/Alert_Contacts'

    @cache = session[:alerts_new_contact]
    session.try(:delete, :alerts_new_contact)

    @options = params.reject { |key, _| %w( controller action ).member? key.to_s }

    options_order_by = @options[:order_by]
    if options_order_by
      order_by = "#{options_order_by} " + (@options[:order_desc].to_i == 1 ? 'DESC' : 'ASC')
    else
      order_by = 'id ASC'
    end

    @contacts	 = AlertContact.order(order_by).all
    @new_contact = AlertContact.new

    # blank new contact object as form_for template
    @new_contact.attributes.each { |key, _| @new_contact[key] = nil }

    # filling form template with failed to create contact details (if exists)
    @cache.try(:each) do |key, value|
      @new_contact[key] = value
    end
  end

  def contact_toggle
    if @contact.status == 'enabled'
      new_status = 'disabled'
      flash_success = _('contact_successfully_disabled')
      flash_error = _('contact_was_not_disabled')
    else
      new_status = 'enabled'
      flash_success =  _('contact_successfully_enabled')
      flash_error = _('contact_was_not_enabled')
    end
    @contact.status = new_status
    if @contact.save
      flash[:status] = flash_success
    else
      flash_errors_for(flash_error, @contact)
    end
    redirect_to action: 'contacts', params: params.reject { |key, _| %w( action controller ).member? key.to_s } and return false
  end

  def alert_toggle
    if @alert.status == 'enabled'
      new_status = 'disabled'
      flash_success = _('alert_successfully_disabled')
      flash_error = _('alert_was_not_disabled')
    else
      new_status = 'enabled'
      flash_success =  _('alert_successfully_enabled')
      flash_error = _('alert_was_not_enabled')
    end
    @alert.status = new_status
    if @alert.save
      flash[:status] = flash_success
    else
      flash_errors_for(flash_error, @alert)
    end
    redirect_to(action: 'list') && (return false)
  end

  def contact_add
    where_blank = where_blank_proc
    defaults	= AlertContact.new.attributes.reject(&where_blank) || {}
    form_fields	= params[:new_contact].try(:reject, &where_blank)
    new_contact	= AlertContact.new(defaults.merge(form_fields || {}))

    if new_contact.save
      flash[:status] = _('contact_successfully_created')
    else
      flash_errors_for(_('contact_was_not_created'), new_contact)
      session[:alerts_new_contact] = form_fields
    end
    (redirect_to action: 'contacts') && (return false)
  end

  def schedule_add
    where_blank = where_blank_proc
    defaults	 = AlertSchedule.new.attributes.reject(&where_blank) || {}
    form_fields	 = params[:new_schedule].try(:reject, &where_blank)
    new_schedule = AlertSchedule.new(defaults.merge(form_fields || {}))

    if new_schedule.save
      flash[:status] = _('schedule_successfully_created')
    else
      flash_errors_for(_('schedule_was_not_created'), new_schedule)
      session[:alerts_new_schedule] = form_fields
    end

    clean_params = params.select { |key, _| %w( order_by order_desc ).member?(key) }

    (redirect_to action: 'schedules', params: clean_params) && (return false)
  end

  def schedule_edit
    @page_title = _('alert_schedule_edit') + ': ' + @schedule.name
    @page_icon	= 'edit.png'
    @help_link  = 'http://wiki.kolmisoft.com/index.php/Alert_Schedules'

    @cache = session[:alerts_edit_schedule]
    session.try(:delete, :alerts_edit_schedule)

    @cache.try(:each) do |key, value|
      @schedule[key] = value
    end
  end

  def contact_edit
    @page_title = _('alert_contact_edit')
    @page_icon	= 'edit.png'
    @help_link  = 'http://wiki.kolmisoft.com/index.php/Alert_Contacts'

    @cache = session[:alerts_edit_contact]
    session.try(:delete, :alerts_edit_contact)

    @cache.try(:each) do |key, value|
      @contact[key] = value
    end
  end

  def contact_update
    form_fields = params[:contact]
    form_fields.try(:each) do |key, value|
      @contact[key] = value
    end
    if @contact.save
      flash[:status] = _('contact_successfully_updated')
      (redirect_to action: 'contacts') && (return false)
    else
      flash_errors_for(_('contact_was_not_updated'), @contact)
      session[:alerts_edit_contact] = form_fields
      (redirect_to action: 'contact_edit', id: @contact.id) && (return false)
    end
  end

  def contact_destroy
    if @contact.destroy
      flash[:status] = _('contact_successfully_deleted')
    else
      flash_errors_for(_('contact_was_not_deleted'), @contact)
    end
    redirect_to action: 'contacts'
  end

  def schedule_destroy
    if @schedule.destroy
      flash[:status] = _('schedule_successfully_deleted')
    else
      flash_errors_for(_('schedule_was_not_deleted'), @schedule)
    end
    (redirect_to action: 'schedules') && (return false)
  end

  def schedules
    @page_title	= _('alert_schedules')
    @page_icon	= 'clock.png'
    @help_link	= 'http://wiki.kolmisoft.com/index.php/Alert_Schedules'

    @options = params.reject { |key, _| %w( controller action ).member? key.to_s }

    order_by_opts = @options[:order_by]
    order_desc_opts = @options[:order_desc].to_i

    if order_by_opts
      order_by = "#{order_by_opts} " + (order_desc_opts == 1 ? 'DESC' : 'ASC')
    else
      order_by = 'id ASC'
    end

    @schedules	  = AlertSchedule.order(order_by).all
    @new_schedule = AlertSchedule.new

    @cache = session[:alerts_new_schedule]
    session.try(:delete, :alerts_new_schedule)
  end

  def schedule_update
    form_fields = params[:schedule]
    periods	= params[:periods]
    form_fields.try(:each) do |key, value|
      @schedule[key] = value
    end

    err = Alert.schedule_update(@schedule, periods)

    if err.blank? && @schedule.save
      flash[:status] = _('schedule_successfully_updated')
      (redirect_to action: 'schedules') && (return false)
    else
      first_error = err.first
      @schedule.errors.add(:time, first_error) unless first_error.blank?
      flash_errors_for(_('schedule_was_not_updated'), @schedule)
      session[:alerts_edit_schedule] = form_fields
      (redirect_to action: 'schedule_edit', id: @schedule.id) && (return false)
    end
  end

  def groups
    @page_title = _('alert_groups')
    @page_icon = 'groups.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Alert_Groups'

    @cache = session[:alerts_new_group]
    session.try(:delete, :alerts_new_group)

    @options = session[:groups_list_order] ? session[:groups_list_order] : { order_by: 'id', order_desc: 0 }
    order_by_attributes = params[:order_by]
    order_desc_attributes = params[:order_desc]
    @options[:order_by] = order_by_attributes.to_s.strip if order_by_attributes
    @options[:order_desc] = order_desc_attributes.to_s.strip.to_i if order_desc_attributes

    session[:groups_list_order] = @options

    order_by = order_groups(@options)

    @schedules = AlertSchedule.all

    @groups = AlertGroup.select('alert_groups.*, sms_schedules.name AS sms_schedule_name, email_schedules.name AS email_schedule_name').
        joins('LEFT JOIN alert_schedules AS sms_schedules ON sms_schedules.id = alert_groups.sms_schedule_id').
        joins('LEFT JOIN alert_schedules AS email_schedules ON email_schedules.id = alert_groups.email_schedule_id').
        order(order_by).all

    @new_group = AlertGroup.new

    # blank new contact object as form_for template
    @new_group.attributes.each { |key, _| @new_group[key] = nil }

    # filling form template with failed to create contact details (if exists)
    @cache.try(:each) do |key, value|
      @new_group[key] = value
    end

    @new_group.status = 'enabled' if @cache.blank?
  end

  def group_add
    where_blank = where_blank_proc
    defaults    = AlertGroup.new.attributes.reject(&where_blank)
    form_fields = params[:new_group].try(:reject, &where_blank)
    new_group = AlertGroup.new(defaults.merge(form_fields || {}))

    new_group = Alert.group_add(new_group)

    if new_group.save
      flash[:status] = _('alert_group_successfully_created')
    else
      flash_errors_for(_('alert_group_was_not_created'), new_group)
      session[:alerts_new_group] = form_fields
    end
    (redirect_to action: 'groups') && (return false)
  end

  def group_contacts
    @page_title = _('Add_New_Contact')
    @page_icon = 'vcard.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Alert_Contacts'
    id_attributes = params[:id]
    @group_contacts = AlertContactGroup.select('alert_contact_groups.*, alert_contacts.name, alert_contacts.email').
        where(['alert_contact_groups.alert_group_id = ?', id_attributes]).
        joins('JOIN alert_contacts ON alert_contacts.id = alert_contact_groups.alert_contact_id')

    @selectable_contacts = AlertContact.select('alert_contacts.id, alert_contacts.name').
        where("alert_contacts.id NOT IN (SELECT alert_contact_groups.alert_contact_id AS id FROM alert_contact_groups WHERE alert_contact_groups.alert_group_id = #{id_attributes})")

    @group_name = @group.name
  end

  def group_contact_add
    alert_contact_group = AlertContactGroup.new(params[:new_group_contact])

    if alert_contact_group.save
      flash[:status] = _('contact_successfully_assigned')
    else
      flash_errors_for(_('contact_was_not_added'), alert_contact_group)
    end
    (redirect_to action: 'group_contacts', id: alert_contact_group.alert_group_id) && (return false)
  end

  def group_contact_destroy
    if AlertContactGroup.where(id: params[:id]).first.destroy
      flash[:status] = _('contact_successfully_deleted')
    end
    (redirect_to action: 'group_contacts', id: params[:group_id]) && (return false)
  end

  def group_toggle
    if @group.status == 'enabled'
      new_status = 'disabled'
      flash_success = _('alert_group_successfully_disabled')
      flash_error = _('alert_group_was_not_disabled')
    else
      new_status = 'enabled'
      flash_success =  _('alert_group_successfully_enabled')
      flash_error = _('alert_group_was_not_enabled')
    end

    @group.status = new_status
    if @group.save
      flash[:status] = flash_success
    else
      flash_errors_for(flash_error, @group)
    end
    (redirect_to action: 'groups') && (return false)
  end

  def group_edit
    @page_title = _('alert_group_edit') + ': ' + @group.name
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Alert_Groups'

    @schedules = AlertSchedule.all

    @cache = session[:alert_group_edit]

    @group_name = @group.name

    session.try(:delete, :alert_group_edit)
    @cache.try(:each) do |key, value|
      @group[key] = value
    end
  end

  def group_update
    @page_title = _('alert_groups')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Alert_Groups'

    form_fields = params[:group]
    form_fields.try(:each) do |key, value|
      @group[key] = value
    end

    @group = Alert.group_update(@group)

    if @group.save
      flash[:status] = _('alert_group_successfully_updated')
      (redirect_to action: 'groups') && (return false)
    else
      flash_errors_for(_('alert_group_was_not_updated'), @group)
      session[:alert_group_edit] = form_fields
      (redirect_to action: 'group_edit', id: @group.id) && (return false)
    end
  end

  def group_destroy
    if @group.destroy
      flash[:status] = _('alert_group_successfully_deleted')
    else
      flash_errors_for(_('alert_group_was_not_deleted'), @group)
    end
    redirect_to action: 'groups'
  end

  def schedule_toggle
    if @schedule.status == 'enabled'
      new_status = 'disabled'
      flash_success = _('schedule_successfully_disabled')
      flash_error = _('schedule_was_not_disabled')
    else
      new_status = 'enabled'
      flash_success =  _('schedule_successfully_enabled')
      flash_error = _('schedule_was_not_enabled')
    end
    @schedule.status = new_status
    if @schedule.save
      flash[:status] = flash_success
    else
      flash_errors_for(flash_error, @schedule)
    end
    (redirect_to action: 'schedules', params: params) && (return false)
  end

  def new_schedule
    begin
      js_new = Alert.new_schedule(params)

      render partial: 'schedule_periods', locals: { day: params[:day_type], js_new: js_new }
    rescue
      render text: ''
    end
  end

  def drop_period
    period = AlertSchedulePeriod.where(id: params[:id]).first
    if period.try(:destroy)
      render text: 'OK'
    else
      render text: 'BLANK'
    end
  end

  def ajax_get_lcrs
    @alert = Alert.where(id: params[:id].to_i).first
    @alert = Alert.new if @alert.blank?
    @alert.disable_provider_in_lcr = params[:dis].to_i
    @lcr_providers = Lcrprovider.select(:lcr_id).where(provider_id: params[:prov_id]).group(:lcr_id).all
    @prov_lcrs = Lcr.where("id IN (#{@lcr_providers.collect(&:lcr_id).join(',')})").all if @lcr_providers.present?
    render layout: false
  end


  def add_alert_to_group
    alert_dependencies = session[:alert_dependencies] <<
      AlertDependency.new(alert_id: params[:alert_id].to_i)
    alert_ids = alert_dependencies.map(&:alert_id).join(', ')
    alerts_for_select = Alert.where(check_type: params[:check_type]).where("id NOT IN (#{alert_ids})")
    render partial: 'alert_group_selector', :layout => false,
           locals: { alerts: alerts_for_select, alert_dependencies: alert_dependencies }
  end

  def remove_alert_from_group
    alert_dependencies = session[:alert_dependencies].reject do |element|
      element.alert_id == params[:alert_id].to_i
    end
    session[:alert_dependencies] = alert_dependencies

    alert_ids = alert_dependencies.map(&:alert_id).join(', ')

    if alert_ids.length > 0
      alerts_for_select = Alert.where(check_type: params[:check_type]).where("id NOT IN (#{alert_ids})")
    else
      alerts_for_select = Alert.where(check_type: params[:check_type])
    end

    render partial: 'alert_group_selector', layout: false,
           locals: { alerts: alerts_for_select, alert_dependencies: alert_dependencies }
  end

  def update_dependency_selector
    session[:alert_dependencies] = []
    alerts_for_select = Alert.where(check_type: params[:check_type])
    render partial: 'alert_group_selector', layout: false,
           locals: { alerts: alerts_for_select, alert_dependencies: [] }
  end


  private

  def order_groups(options)
    order_by = ''


    case options[:order_by].to_s
    when 'id'
      order_by += 'alert_groups.id'
    when 'name'
      order_by += 'alert_groups.name'
    when 'status'
      order_by += 'alert_groups.status'
    when 'email_schedule'
      order_by += 'email_schedule_name'
    when 'sms_schedule'
      order_by += 'sms_schedule_name'
    when 'max_emails_month'
      order_by += 'alert_groups.max_emails_per_month'
    when 'max_sms_month'
      order_by += 'alert_groups.max_sms_per_month'
    when 'emails_this_month'
      order_by += 'alert_groups.emails_this_month'
    when 'sms_this_month'
      order_by += 'alert_groups.sms_this_month'
    when 'comment'
      order_by += 'alert_groups.comment'
    end

    if order_by != ''
      case options[:order_desc].to_i
      when 0
        order_by += ' ASC'
      when 1
        order_by += ' DESC'
      end
    end

    order_by
  end

  def set_alert_check_data
    params[:users_device] = 'all' if params[:device_user] == 'all'
    alert_attributes = params[:alert]
    unless alert_attributes.blank?
      param_keys = [:users_device, :alert_check_data1, :alert_check_data2, :alert_check_data3, :alert_check_data4]
      check_data = nil
      param_keys.each do |key|
        param_value = params[key]
        check_data = param_value if param_value
      end
      alert_attributes[:check_data] = check_data if check_data
    end
  end

  def set_alert_parameters
    @alert_type_parameters = {}

    parameters_base = ['asr', 'acd', 'pdd', 'ttc', 'billsec_sum', 'calls_total', 'calls_answered', 'calls_not_answered',
                       'hgc_absolute', 'hgc_percent', 'group']
    @alert_type_parameters[:base] = parameters_base
    @alert_type_parameters[:user] = parameters_base + ['sim_calls', 'price_sum']
    @alert_type_parameters[:provider] = parameters_base + ['sim_calls', 'price_sum']
  end

  def update_alerts_service
    Confline.set_value('alerts_need_update', 1)
  end

  def find_alert
    @alert = Alert.where(id: params[:id], owner_id: corrected_user_id).first
    unless @alert
      flash[:notice] = _('alert_was_not_found')
      (redirect_to action: 'list') && (return false)
    end
  end

  def find_contact
    @contact = AlertContact.where(id: params[:id]).first
    unless @contact
      flash[:notice] = _('contact_was_not_found')
      (redirect_to action: 'contacts') && (return false)
    end
  end

  def find_schedule
    @schedule = AlertSchedule.where(id: params[:id]).first
    unless @schedule
      flash[:notice] = _('schedule_was_not_found')
      (redirect_to action: 'schedules') && (return false)
    end
  end

  def find_group
    @group = AlertGroup.where(id: params[:id]).first
    unless @group
      flash[:notice] = _('alert_group_was_not_found')
      (redirect_to action: 'groups') && (return false)
    end
  end

  def allow_more_alerts?
    if Alert.where(owner_id: corrected_user_id).count >= 5 && !monitorings_addon_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      Action.dont_be_so_smart(corrected_user_id, request.env, params)
      (redirect_to :root) && (return false)
    end
  end

  def where_blank_proc
    Proc.new { |_, value| value.blank? }
  end
end