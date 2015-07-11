# -*- encoding : utf-8 -*-
class UsersController < ApplicationController
  layout 'callc'

  include SqlExport

  before_filter :check_post_method, only: [:destroy, :create, :update, :update_personal_details,
                                           :user_custom_rate_add_new]
  before_filter :authorize, except: [:daily_actions]
  before_filter :check_localization, except: [:daily_actions]

  before_filter do |controller|
    view = [:list, :index, :reseller_users, :show, :edit, :device_groups, :custom_rates, :user_acustrates,
            :default_user]
    edit = [:new, :create, :update, :destroy, :hide, :device_group_edit, :user_acustrates_full, :device_group_update,
            :device_group_new, :device_group_create, :device_group_delete, :update_personal_details,
            :user_custom_rate_add_new, :user_delete_custom_rate, :artg_destroy, :ard_manage, :user_ard_time_edit,
            :user_custom_rate_update, :user_custom_rate_update, :user_custom_rate_delete, :default_user_update]
    allow_read, allow_edit = controller.check_read_write_permission(view, edit, {role: 'accountant',
      right: :acc_user_manage, ignore: true})
    controller.instance_variable_set :@allow_read, allow_read
    controller.instance_variable_set :@allow_edit, allow_edit
    true
  end

  before_filter do |controller|
    view = [:user_custom_rate_add, :custom_rates, :user_acustrates_full, :user_acustrates, :ard_manage,
            :user_ard_time_edit, :user_delete_custom_rate, :artg_destroy, :user_custom_rate_delete,
            :user_custom_rate_update]
    edit = [:user_custom_rate_add, :user_acustrates_full, :user_acustrates, :ard_manage, :user_ard_time_edit,
            :user_delete_custom_rate, :artg_destroy, :user_custom_rate_delete, :user_custom_rate_update]
    allow_read, allow_edit = controller.check_read_write_permission(view, edit,
                                                    {role: 'accountant', right: :acc_user_create_opt_4, ignore: true})
    controller.instance_variable_set :@allow_read_custrate, allow_read
    controller.instance_variable_set :@allow_edit_custrate, allow_edit
  end

  before_filter :authorize_admin, only: [:users_postpaid_and_allowed_loss_calls, :default_user_errors_list]
  before_filter :find_user, only: [:update, :device_group_create, :device_groups, :device_group_new, :custom_rates,
    :user_custom_rate_add_new, :user_acustrates_full]
  before_filter :find_user_from_session, only: [:update_personal_details, :personal_details]
  before_filter :find_devicegroup, only: [:device_group_delete, :device_group_update, :device_group_edit]
  before_filter :find_customrate, only: [:user_delete_custom_rate, :artg_destroy, :ard_manage, :user_ard_time_edit,
    :user_acustrates, :user_custom_rate_add]
  before_filter :find_ard, only: [:user_custom_rate_delete, :user_custom_rate_update]
  before_filter :find_ard_all, only: [:artg_destroy, :user_ard_time_edit, :user_acustrates]
  before_filter :check_params, only: [:create, :update, :default_user_update]
  before_filter :check_with_integrity, only: [:edit, :list, :new, :default_user,
    :users_postpaid_and_allowed_loss_calls, :default_user_errors_list]
  before_filter :find_responsible_accountants, only: [:edit, :default_user, :new, :create, :update]
  before_filter :check_rs_user_count, only: [:new, :create], if: ->{ reseller_users_restriction }
  before_filter :check_selected_rs_user_count, only: [:update], if: ->{ not reseller_pro_active? }
  before_filter :user_wholesale_disabled, only: [:new, :edit, :update, :default_user, :create]
  before_filter :number_separator, only: [:edit, :update]
  before_filter :default_blacklist_thresholds_and_lcrs, only: [:new, :edit, :create, :update, :default_user,
    :default_user_update]

  def list
    @page_title = _('Users')
    @page_icon = 'vcard.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Users'
    @default_currency = Currency.first.name
    @roles = Role.where(["name !='guest' AND name !='admin'"])

    @options = default_user_options(session[:user_list_stats], true)
    owner = correct_owner_id
    cond = ['users.hidden = 0 AND users.id != 0 AND users.owner_id = ?']
    joins, group_by, var = [], nil, [owner]
    select = ["users.*", "tariffs.purpose", "#{SqlExport.nice_user_sql}"]

    add_contition_and_param(@options[:user_type], @options[:user_type], 'users.usertype = ?', cond, var) if @options[:user_type].to_i != -1
    add_contition_and_param(@options[:s_id], @options[:s_id], 'users.id = ?', cond, var) if @options[:s_id].to_i != -1
    add_contition_and_param(@options[:s_agr_number], @options[:s_agr_number].to_s + '%', 'users.agreement_number LIKE ?', cond, var) if @options[:s_agr_number].present?
    add_contition_and_param(@options[:s_acc_number], @options[:s_acc_number].to_s + '%', 'users.accounting_number LIKE ?', cond, var) if @options[:s_acc_number].present?
    add_contition_and_param(@options[:s_email], @options[:s_email].to_s, 'email = ?', cond, var) if !@options[:s_email].blank?
    add_contition_and_param(@options[:responsible_accountant_id], @options[:responsible_accountant_id].to_s + '%', 'users.responsible_accountant_id = ?', cond, var) if @options[:responsible_accountant_id] != '-1'

    ['first_name', 'username', 'last_name', 'clientid'].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], '%' + @options["s_#{col}".intern].to_s + '%', "users.#{col} LIKE ?", cond, var) }

    joins << 'LEFT JOIN addresses ON (users.address_id = addresses.id)' if @options[:s_email].present?

    if @options[:sub_s].to_i > -1
      group_by = "users.id HAVING subscriptions_count#{@options[:sub_s].to_i == 0 ? " = 0" : " > 0"}"
      select << "count(subscriptions.id) as 'subscriptions_count'"
      joins << 'LEFT JOIN subscriptions ON (users.id = subscriptions.user_id)'
    end

    joins << 'LEFT JOIN tariffs ON users.tariff_id = tariffs.id'

    @search = ((cond.size > 1 || @options[:sub_s].to_i > -1) ? 1 : 0)

    if admin? && (( !reseller_active?) || ( !reseller_pro_active?))
      first_reseller_id, first_reseller_pro_id = User.first_resellers_ids
      condition = ["users.usertype != 'reseller'"] if !reseller_active?
      condition << ["users.id = #{first_reseller_id}"] if first_reseller_id && !reseller_active?
      condition = ['users.own_providers = 0'] if !reseller_pro_active? && reseller_active?
      condition << ["users.id = #{first_reseller_pro_id}"] if first_reseller_pro_id
      cond << '(' + condition.join(' OR ') + ')'
    end

    # we need to left join acc_groups, addreses and lcrs. When COUNTING users this data is irelevant,
    # so no need for extra joins there
    # Select addresses.county(that's right), addresses.city, lcrs.name, tariffs.name, acc_groups_name
    # so that rails wouldnt generate extra queries.
    if @options[:s_email].blank?
      joins << 'LEFT JOIN addresses ON users.address_id = addresses.id'
    end

    joins << 'LEFT JOIN lcrs ON users.lcr_id = lcrs.id'
    joins << 'LEFT JOIN acc_groups ON users.acc_group_id = acc_groups.id'
    select << 'addresses.city, addresses.county'
    select << 'lcrs.name AS lcr_name'
    select << 'tariffs.name AS tariff_name'
    select << 'acc_groups.name AS acc_group_name'

    # limits users count for reseller if addon is not active
    # @options[:order] += ' LIMIT 2' if reseller_users_restriction

    users = User.select(select.join(",")).joins(joins.join(" ")).where([cond.join(" AND "), *var]).group(group_by)

    users_count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM (#{users.to_sql}) AS subquery").first.first
    if reseller_users_restriction
      users_count = users_count > 2 ? 2 : users_count
    end

    # page params
    @total_pages = (users_count.to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    fpage = ((@options[:page] - 1) * session[:items_per_page]).to_i

    @users = users.order(@options[:order])

    if reseller_users_restriction
      @users = @users.limit(2)
      @users = @users[fpage...(session[:items_per_page].to_i + fpage)].to_a
    else
      @users = @users.limit("#{fpage}, #{session[:items_per_page].to_i}").all
    end


    # Mapping accountants with appointed users
    @responsible_accountants = User.responsible_acc_for_list

    session[:user_list_stats] = @options
  end

  def reseller_users
    @page_title = _('Reseller_users')
    @page_icon = 'vcard.png'

    @reseller = User.where(id: params[:id]).first if params[:id].to_i > 0
    unless @reseller
      flash[:notice] = _('Not_found')
      redirect_to(controller: 'stats', action: 'resellers') && (return false)
    end

    @users = @reseller.reseller_users(reseller_active?, reseller_pro_active?)
  end

  def hidden
    @page_title = _('Hidden_users')
    @page_icon = 'vcard.png'
    @default_currency = Currency.first.name
    @roles = Role.where(["name !='guest'"])

    @options = default_user_options(session[:user_hiden_stats], false)
    owner = correct_owner_id
    cond = ['users.hidden = 1 AND users.owner_id = ?']
    joins, var = [], [owner]
    select = ['users.*', 'tariffs.purpose', "#{SqlExport.nice_user_sql}"]
    add_contition_and_param(@options[:user_type], @options[:user_type], 'users.usertype = ?', cond, var) if @options[:user_type].to_i != -1
    add_contition_and_param(@options[:s_id], @options[:s_id], 'users.id = ?', cond, var) if @options[:s_id].to_i != -1
    add_contition_and_param(@options[:s_agr_number], @options[:s_agr_number].to_s + '%', 'users.agreement_number LIKE ?', cond, var) if @options[:s_agr_number].present?
    add_contition_and_param(@options[:s_acc_number], @options[:s_acc_number].to_s + '%', 'users.accounting_number LIKE ?', cond, var) if @options[:s_acc_number].present?
    add_contition_and_param(@options[:s_email], @options[:s_email].to_s, 'email = ?', cond, var) if @options[:s_email].present?

    ['first_name', 'username', 'last_name', 'clientid'].each do |col|
      add_contition_and_param(@options["s_#{col}".to_sym], '%' + @options["s_#{col}".intern].to_s + '%', "users.#{col} LIKE ?", cond, var)
    end

    joins << 'LEFT JOIN addresses ON (users.address_id = addresses.id)' unless @options[:s_email].blank?

    if @options[:sub_s].to_i > -1
      group_by = "users.id HAVING subscriptions_count#{@options[:sub_s].to_i == 0 ? ' = 0' : ' > 0'}"
      select << "count(subscriptions.id) as 'subscriptions_count'"
      joins << 'LEFT JOIN subscriptions ON (users.id = subscriptions.user_id)'
    end

    joins << 'LEFT JOIN tariffs ON users.tariff_id = tariffs.id'
    joins = joins.try(:size).to_i > 0 ? joins.join(' ') : nil

    # page params
    @user_size = User.select(select.join(',')).joins(joins).where([cond.join(' AND '), *var]).group(group_by)
    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @total_pages = (@user_size.size.to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i && @total_pages.to_i > 0
    fpage = ((@options[:page] - 1) * session[:items_per_page]).to_i

    @users = User.select(select.join(',')).joins(joins).where([cond.join(' AND '), *var]).order(@options[:order]).group(group_by).limit("#{fpage}, #{session[:items_per_page].to_i}")
    @search = ((cond.size > 1 || @options[:sub_s].to_i > -1) ? 1 : 0)

    session[:user_hiden_stats] = @options
  end

  def hide
    user = User.where(id: params[:id]).first
    if user.blank? || user.id == 0
      flash[:notice] = _('User_was_not_found')
      redirect_to(action: 'list') && (return false)
    end

    if user.toggle_hidden == 1
      flash[:status] = _('User_hidden') + ': ' + nice_user(user)
      redirect_to(action: 'hidden')
    else
      flash[:status] = _('User_unhidden') + ': ' + nice_user(user)
      redirect_to action: 'list'
    end
  end

  def show
    @user = User.where(id: params[:id]).first
  end

  def new
    @page_title = _('New_user')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/User_Details'

    check_for_accountant_create_user
    @lcrs = current_user.load_lcrs({order: 'name ASC'})
    @groups = AccGroup.where(group_type: 'accountant')
    @groups_resellers = AccGroup.where(group_type: 'reseller')
    owner = (accountant? ? 0 : session[:user_id])

    cond = @user_wholesale_disabled ? " AND purpose = 'user' " : " AND (purpose = 'user' OR purpose = 'user_wholesale') "

    @tariffs = Tariff.where("owner_id = '#{owner}' #{cond} ").order('purpose ASC, name ASC')

    @countries = Direction.order(:name)

    @user, @address, @tax, @default_country_id = Confline.new_user_defaults(owner)

    if @lcrs.empty? && allow_manage_providers?
      flash[:notice] = _('No_lcrs_found_user_not_functional')
      redirect_to(action: 'list') && (return false)
    end

    if @tariffs.empty?
      flash[:notice] = _('No_tariffs_found_user_not_functional')
      redirect_to(action: 'list') && (return false)
    end

    @user.assign_attributes(agreement_date: Time.now.to_s(:db),
                            owner_id: owner,
                            tax: @tax,
                            address: @address,
                            agreement_number: next_agreement_number,
                            recording_enabled: Confline.get_value('Default_User_recording_enabled').to_i)
    @user.change_warning_balance_currency

    @i = @user.get_invoices_status

    @blacklists_on = true if admin?
    @bl_global_setting = Confline.get_value('blacklist_enabled', 0).to_i.equal?(1) ? 'Yes' : 'No'
    @pbx_pools = PbxPool.where(owner_id: current_user_id).order('name ASC').all.map { |pool| [pool.name, pool.id] }
    @show_rspro_button = (reseller_pro_active? || (User.where(owner_id: current_user_id, own_providers: 1).count == 0))
    @count_rs = User.where(usertype: 'reseller', own_providers: 0, owner_id: current_user_id).count
    @count_rspro = User.where(usertype: 'reseller', own_providers: 1, owner_id: current_user_id).count
  end

  def create
    # MorLog.my_debug params.to_yaml
    @page_title = _('New_user')
    @page_icon = 'add.png'

    check_for_accountant_create_user
    sanitize_user_params_by_accountant_permissions

    params[:user] = params[:user].each_value(&:strip!)
    params[:address] = params[:address].each_value(&:strip!) if params[:address]
    params[:user] = User.default_blacklist_params(params[:user])

    # accountant cannot create accountant
    if accountant? && ['accountant'].include?(params[:user][:usertype])
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    if ['accountant', 'reseller'].include?(params[:user][:usertype])
      if params[:accountant_type].to_i == 0
        dont_be_so_smart
        redirect_to(:root) && (return false)
      else
        params[:user][:acc_group_id] = params[:accountant_type].to_i
        params[:hide_non_answered_calls] = 0
      end
    else
      params[:user][:acc_group_id] = 0
    end
    if params[:privacy]
      if params[:privacy][:global].to_i == 1
        params[:user][:hide_destination_end] = -1
      else
        params[:user][:hide_destination_end] = params[:privacy].values.sum { |value| value.to_i }
      end
    end

    params[:user][:cyberplat_active] = params[:cyberplat_active].to_i == 1 ? 1 : 0
    params[:user][:generate_invoice] = params[:user][:generate_invoice].to_i == 1 ? 1 : 0

    #    if  !Email.address_validation(params[:address][:email]) and params[:address][:email].to_s.length > 0
    #      flash[:notice] = _('Please_enter_correct_email')
    #      redirect_to :action => 'new' and return false
    #    end

    owner_id = correct_owner_id
    if reseller? && params[:user][:usertype] != 'user'
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    if accountant? && params[:user][:usertype] == 'admin'
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    @user = Confline.get_default_object(User, owner_id)
    @user.attributes = params[:user]
    @user.owner_id = owner_id
    @user.warning_email_active = params[:user][:warning_email_active].to_i

    if params[:password][:password].strip.length < @user.minimum_password
      @user.errors.add(:password, _('Password_must_be_longer', (@user.minimum_password - 1)))
    end

    @user.password = Digest::SHA1.hexdigest(params[:password][:password].to_s.strip)
    @user.recording_hdd_quota = (params[:user][:recording_hdd_quota].to_d * 1048576).to_i
    @user.agreement_date = params[:agr_date][:year].to_s + '-' + params[:agr_date][:month].to_s + '-' + params[:agr_date][:day].to_s

    @invoice = invoice_params_for_user
    @user.send_invoice_types = @invoice
    @user.cyberplat_active = params[:cyberplat_active].to_i
    if params[:unlimited] == '1'
      @user.credit = -1
    else
      @user.credit = params[:credit].to_d
      @user.credit = 0 if @user.credit < 0
    end

    @lcrs = current_user.load_lcrs({order: 'name ASC'})

    owner = (accountant? ? 0 : session[:user_id])
    cond = @user_wholesale_disabled ? " AND purpose = 'user' " : " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    @tariffs = Tariff.where("owner_id = '#{owner}' #{cond} ").order('purpose ASC, name ASC')

    @countries = Direction.order(:name)

    @user.block_conditional_use = params[:block_conditional_use].to_i
    @user.allow_loss_calls = params[:allow_loss_calls].to_i
    @user.hide_non_answered_calls = params[:hide_non_answered_calls].to_i

    tax = Tax.create(tax_from_params)

    @user.tax_id = tax.id

    @user.warning_email_active = params[:warning_email_active].to_i
    @user.invoice_zero_calls = params[:show_zero_calls].to_i
    @pbx_pools = PbxPool.where(owner_id: current_user.id).order('name ASC').all.map { |pool| [pool.name, pool.id] }

    @user.own_providers = params[:own_providers].to_i if @user.usertype == 'reseller'

    # reseller support
    if @user.owner_id != 0
      reseller = User.where(id: @user.owner_id).first
      @user.lcr_id = reseller.lcr_id unless reseller.can_own_providers?

      # ticket #5246
      # @user.allow_loss_calls = reseller.allow_loss_calls
    end

    if rec_active?
      @user.recording_enabled = params[:recording_enabled].to_i
      @user.recording_forced_enabled = params[:recording_forced_enabled].to_i
    else
      @user.recording_enabled = 0
      @user.recording_forced_enabled = 0
    end
    @user.balance = params[:user][:balance].to_d

    if params[:warning_email_active]
      @user.warning_email_hour = params[:user][:warning_email_hour].to_i != -1 ? params[:date][:warning_email_hour].to_i : params[:user][:warning_email_hour].to_i
    end

    @address = Address.new(params[:address])
    @address.email = nil if @address.email.to_s.blank?
    if @address.save
      @user.address_id = @address.id
    else
      @user.tax.destroy if @user.tax
      @user.address.destroy if @user.address
      @i = @user.get_invoices_status
      flash_errors_for(_('User_was_not_created'), @address)
      render(:new) && (return false)
    end

    if @user.postpaid?
      @user.minimal_charge = params[:minimal_charge_value].to_i
      if params[:minimal_charge_value].to_i != 0 && params[:minimal_charge_date]
        year = params[:minimal_charge_date][:year].to_i
        month = params[:minimal_charge_date][:month].to_i
        day = 1
        @user.minimal_charge_start_at = Date.new(year, month, day)
      elsif params[:minimal_charge_value].to_i == 0
        @user.minimal_charge_start_at = nil
      end
    end

    if params[:user][:username].strip.length < @user.minimum_username
      @user.errors.add(:username, _('Username_must_be_longer', (@user.minimum_username - 1)))
    end

    @count_rs = User.where(usertype: 'reseller', own_providers: 0, owner_id: current_user.id).count
    @count_rspro = User.where(usertype: 'reseller', own_providers: 1, owner_id: current_user.id).count

    if (admin? || accountant?) && !reseller_active? && (params[:user][:usertype] == 'reseller')
      rs_limit = 1
      if params && (params[:own_providers].to_i == 0) && (@count_rs >= rs_limit)
        @user.errors.add(:username, _('resellers_restriction')) unless reseller_active?
      end
    end
    if (admin? || accountant?) && !reseller_pro_active? && (params[:user][:usertype] == 'reseller')
      rspro_limit = 1
      if params && (params[:own_providers].to_i == 1) && (@count_rspro >= rspro_limit)
        @user.errors.add(:username, _('resellers_pro_restriction')) unless reseller_pro_active?
      end
    end

    unless params[:warning_email_balance].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ || params[:warning_email_balance].to_s == ''
      @user.errors.add(:warning_email_balance, _('user_warning_balance_numerical'))
    end

    if params[:warning_email_active].to_i == 1
      @user.warning_email_balance = params[:warning_email_balance].to_s.strip.sub(/[\,\.\;]/, '.').to_d
    end

    unless reseller?
      unless params[:warning_email_balance_admin].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ || params[:warning_email_balance_admin].to_s == ''
        @user.errors.add(:warning_email_balance_admin, _('admin_warning_balance_numerical'))
      end

      unless params[:warning_email_balance_manager].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ || params[:warning_email_balance_manager].to_s == ''
        @user.errors.add(:warning_email_balance_manager, _('manager_warning_balance_numerical'))
      end

      if params[:warning_email_active].to_i == 1
        @user.warning_email_balance_admin = params[:warning_email_balance_admin].to_s.strip.sub(/[\,\.\;]/, '.').to_d
        @user.warning_email_balance_manager = params[:warning_email_balance_manager].to_s.strip.sub(/[\,\.\;]/, '.').to_d
      end
    end

    if @user.errors.count.zero? && @user.valid?
      @user.attributes.delete(:id)
      @user_create = User.create(@user.attributes)
      if @user_create.errors.count == 0
        flash[:status] = _('user_created')
        redirect_to(action: 'list') && (return false)
      else
        @user.tax.destroy if @user.tax
        @user.address.destroy if @user.address
        @user.fix_when_is_rendering
        @i = @user.get_invoices_status
        @groups = AccGroup.where(group_type: 'accountant')
        @groups_resellers = AccGroup.where(group_type: 'reseller')
        @blacklists_on = true if admin?
        @bl_global_setting = Confline.get_value('blacklist_enabled', 0).to_i.equal?(1) ? 'Yes' : 'No'
        flash_errors_for(_('User_was_not_created'), @user_create)
        render(:new) && (return false)
      end
    else
      @user.tax.destroy if @user.tax
      @user.address.destroy if @user.address
      @user.fix_when_is_rendering
      @i = @user.get_invoices_status
      @groups = AccGroup.where(group_type: 'accountant')
      @groups_resellers = AccGroup.where(group_type: 'reseller')
      @blacklists_on = true if admin?
      @bl_global_setting = Confline.get_value('blacklist_enabled', 0).to_i.equal?(1) ? 'Yes' : 'No'
      flash_errors_for(_('User_was_not_created'), @user)
      render(:new) && (return false)
    end
  end

  def edit
    if params[:id].to_i == 0
      redirect_to(action: 'personal_details') && (return false)
    end

    @return_controller = params[:return_to_controller] || 'users'
    @return_action = params[:return_to_action] || 'list'

    find_user(params[:id])
    check_owner_for_user(@user.id)

    @page_title = _('users_settings') + ': ' + nice_user(@user)
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/User_Details'
    @i = @user.get_invoices_status

    @lcrs = current_user.load_lcrs({order: 'name ASC'})
    @blacklists_on = true if admin?
    @bl_global_setting = Confline.get_value('blacklist_enabled', 0).to_i.equal?(1) ? 'Yes' : 'No'

    owner = accountant? ? 0 : session[:user_id]

    cond = @user_wholesale_disabled ? " AND purpose = 'user' " : " AND (purpose = 'user' OR purpose = 'user_wholesale') "

    @tariffs = Tariff.where("(owner_id = '#{owner}' #{cond}) OR id = #{@user.tariff_id} ").order('purpose ASC, name ASC')
    @countries = Direction.order(:name)

    # for backwards compatibility - user had no address before, so let's give it to him
    unless @user.address
      address = Address.new
      address.email = nil if address.email.to_s.blank?
      address.save
      @user.address = address
      @user.save
    end

    @user.assign_default_tax if !@user.tax || @user.tax_id.to_i == 0

    @total_recordings_size = Recording.select("SUM(size) AS 'total_size'").where(user_id: @user.id, deleted: 0).first['total_size'].to_d
    @address = @user.address
    @groups = AccGroup.where(group_type: 'accountant')
    @groups_resellers = AccGroup.where(group_type: 'reseller')

    @pbx_pools = PbxPool.where(owner_id: current_user_id).order('name ASC').all.map { |pool| [pool.name, pool.id] }
    @create_own_providers = Confline.get_value('Disallow_to_create_own_providers', @user.id).to_i
    @chanspy_disabled = Confline.chanspy_disabled?
    @devices = @user.devices(conditions: "device_type != 'FAX'")

    current_user_users_number = User.where(owner_id: current_user_id, own_providers: 1).count
    @show_rspro_button = (reseller_pro_active? || (current_user_users_number == 0) || (@user.own_providers == 1))
    @selected_user_users_number = User.where(owner_id: @user.id).count
    @count_rs = User.where(usertype: 'reseller', own_providers: 0, owner_id: current_user_id).count
    @count_rspro = User.where(usertype: 'reseller', own_providers: 1, owner_id: current_user_id).count

    # Warning balance email send log
    @warning_balance_email_send_log = {}

    send_log_for_user =
      Action.select('date', 'target_type')
      .where("(action = 'warning_balance_send') AND (target_id = #{@user.id.to_i}) AND (data = #{@user.id.to_i})")
      .order('date')
      .last
    @warning_balance_email_send_log[:user] =
      "Last email sent: #{send_log_for_user.date.strftime('%F %T')} to #{send_log_for_user.target_type}" unless
        send_log_for_user.blank?

    send_log_for_admin =
      Action.select('date', 'target_type')
      .where("(action = 'warning_balance_send') AND (target_id = 0) AND (data = #{@user.id.to_i})")
      .order('date')
      .last
    @warning_balance_email_send_log[:admin] =
      "Last email sent: #{send_log_for_admin.date.strftime('%F %T')} to #{send_log_for_admin.target_type}" unless
        send_log_for_admin.blank?

    send_log_for_manager =
      Action.select('date', 'target_type')
      .where("(action = 'warning_balance_send') AND (target_id = #{@user.responsible_accountant_id.to_i}) AND (data = #{@user.id.to_i})")
      .order('date')
      .last
    @warning_balance_email_send_log[:manager] =
      "Last email sent: #{send_log_for_manager.date.strftime('%F %T')} to #{send_log_for_manager.target_type}" unless
        send_log_for_manager.blank?

    flash[:notice] = _('No_lcrs_found_user_not_functional') if @lcrs.blank?

    flash[:notice] = _('No_tariffs_found_user_not_functional') if @tariffs.blank?
  end

  # sets @user in before filter
  def update
    owner_valid = check_owner_for_user(@user.id)
    return false unless owner_valid

    params[:own_providers] = 1 if @user.own_providers == 1

    bad_username = true if params[:user][:username].present? && params[:user][:username].to_s.strip.length < @user.minimum_username
    bad_password = true if params[:password].present? && params[:password][:password].present? && params[:password][:password].to_s.strip.length < @user.minimum_password

    notice, par = @user.validate_from_update(current_user, params, @allow_edit)

    @count_rs = User.where(usertype: 'reseller', own_providers: 0, owner_id: current_user.id).count
    @count_rspro = User.where(usertype: 'reseller', own_providers: 1, owner_id: current_user.id).count

    if (admin? || accountant?) && !reseller_pro_active? && (@user.usertype == 'reseller')
      rspro_limit = 1
      if params && (params[:own_providers].to_i == 1) && (@count_rspro >= rspro_limit)
        @user.errors.add(:username, _('resellers_pro_restriction')) unless reseller_pro_active?
        flash_errors_for(_('User_was_not_updated'), @user)
        redirect_to(action: :edit, id: @user.id) && (return false)
      end
    end

    if notice.present?
      flash[:notice] = notice
      redirect_to(:root) && (return false)
    end

    if par[:user].nil?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    warning_balance_email_active_reset = {}
    warning_balance_email_active_reset[:user] = @user.warning_email_balance
    warning_balance_email_active_reset[:admin] = @user.warning_email_balance_admin
    warning_balance_email_active_reset[:manager] = @user.warning_email_balance_manager
    warning_balance_email_active_reset[:hour] = @user.warning_email_hour

    @user.update_from_edit(par, current_user, tax_from_params, rec_active?)
    @return_controller = 'users'
    @return_action = 'list'

    @user.address.email = nil if @user.address.email.to_s.blank?

    unless params[:warning_email_balance].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ || params[:warning_email_balance].to_s == ''
      @user.errors.add(:warning_email_balance, _('user_warning_balance_numerical'))
    end

    unless params[:warning_email_balance_admin].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ || params[:warning_email_balance_admin].to_s == ''
      @user.errors.add(:warning_email_balance_admin, _('admin_warning_balance_numerical'))
    end

    unless params[:warning_email_balance_manager].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ || params[:warning_email_balance_manager].to_s == ''
      @user.errors.add(:warning_email_balance_manager, _('manager_warning_balance_numerical'))
    end

    if params[:warning_email_active].to_i == 1
      @user.warning_email_balance = params[:warning_email_balance].to_s.strip.sub(/[\,\.\;]/, '.').to_d
      @user.warning_email_balance_admin = params[:warning_email_balance_admin].to_s.strip.sub(/[\,\.\;]/, '.').to_d
      @user.warning_email_balance_manager = params[:warning_email_balance_manager].to_s.strip.sub(/[\,\.\;]/, '.').to_d
    end

    warning_email_balance_errors = @user.errors.messages.keys.select do |key|
      key.to_s.[] 'warning_email_balance'
    end
    if warning_email_balance_errors.size > 0
      flash_errors_for(_('User_was_not_updated'), @user)
      redirect_to(action: 'edit', id: @user.id, warning_email_balance: params[:warning_email_balance],
                  warning_email_balance_admin: params[:warning_email_balance_admin],
                  warning_email_balance_manager: params[:warning_email_balance_manager]
      ) && (return false)
    end

    # Reset warning email send activeness if params changed
    if warning_balance_email_active_reset[:user] != @user.warning_email_balance
      @user.warning_email_sent = 0
    end

    if warning_balance_email_active_reset[:admin] != @user.warning_email_balance_admin
      @user.warning_email_sent_admin = 0
    end

    if warning_balance_email_active_reset[:manager] != @user.warning_email_balance_manager
      @user.warning_email_sent_manager = 0
    end

    if warning_balance_email_active_reset[:hour] != @user.warning_email_hour
      @user.warning_email_sent = 0
      @user.warning_email_sent_admin = 0
      @user.warning_email_sent_manager = 0
    end

    if @user.warning_email_active == 0
      @user.warning_email_sent = @user.warning_email_sent_admin = @user.warning_email_sent_manager = 0
    end

    if !bad_username && !bad_password  && @user.address.valid? && @user.save
      if @user.usertype == 'reseller'
        @user.check_default_user_conflines

        if params[:own_providers].to_i == 1 && params[:create_own_providers].to_i == 1
          Confline.set_value('Disallow_to_create_own_providers', 1, @user.id)
        elsif Confline.get_value('Disallow_to_create_own_providers', @user.id)
          Confline.set_value('Disallow_to_create_own_providers', 0, @user.id)
        end
      end

      # @user.address.update_attributes(params[:address])
      @user.address.email = nil if @user.address.email.to_s.blank?
      @user.address.save

      flash[:status] = _('user_details_changed') + ': ' + nice_user(@user)
      redirect_to(action: :edit, id: @user.id) && (return false)
    else
      check_owner_for_user(@user.id)

      @i = @user.get_invoices_status

      @lcrs = current_user.load_lcrs({order: 'name ASC'})
      if accountant?
        owner = User.where(id: session[:user_id].to_i).first.get_owner.id.to_i
      else
        owner = session[:user_id]
      end

      cond = @user_wholesale_disabled ? " AND purpose = 'user' " : " AND (purpose = 'user' OR purpose = 'user_wholesale') "
      @tariffs = Tariff.where("owner_id = '#{owner}' #{cond} ").order('purpose ASC, name ASC')

      @countries = Direction.order(:name)

      # for backwards compatibility - user had no address before, so let's give it to him
      unless @user.address
        address = Address.new
        address.email = nil if address.email.to_s.blank?
        address.save
        @user.address = address
        @user.save
      end

      @user.fix_when_is_rendering
      @user.assign_default_tax if !@user.tax || @user.tax_id.to_i == 0
      @total_recordings_size = Recording.select("SUM(size) AS 'total_size'").where(user_id: @user.id, deleted: 0).first['total_size'].to_d
      @address = @user.address
      @groups = AccGroup.where(group_type: 'accountant')
      @groups_resellers = AccGroup.where(group_type: 'reseller')
      @devices = @user.devices(conditions: "device_type != 'FAX'")
      @blacklists_on = true if admin?
      @bl_global_setting = Confline.get_value('blacklist_enabled', 0).to_i.equal?(1) ? 'Yes' : 'No'
      @pbx_pools = PbxPool.where(owner_id: current_user.id).order('name ASC').all.map { |pool| [pool.name, pool.id] }

      @user.errors.add(:password, _('Password_must_be_longer', (@user.minimum_password - 1))) if bad_password
      @user.errors.add(:username, _('Username_must_be_longer', (@user.minimum_username - 1))) if bad_username

      if !@user.address.valid?
        flash_errors_for(_('User_was_not_updated'), @user.address)
      else
        flash_errors_for(_('User_was_not_updated'), @user)
      end
      render :edit
    end
  end

  def destroy
    return_controller = params[:return_to_controller] || 'users'
    return_action = params[:return_to_action] || 'list'

    user = User.where(id: params[:id]).first
    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to(action: 'list') && (return false)
    end
    unless check_owner_for_user(user)
      dont_be_so_smart && (return false)
    end

    devices = user.devices
    devices.each do |device|
      if device.has_forwarded_calls
        flash[:notice] = _('Cant_delete_user_has_forwarded_calls')
        redirect_to(controller: return_controller, action: return_action) && (return false)
      end
    end

    if user.id.to_i == session[:user_id]
      flash[:notice] = _('Cant_delete_self')
      redirect_to(controller: return_controller, action: return_action) && (return false)
    end

    if !user.callshops.blank? && !user.callshops.select { |callshop| callshop.manager_users.map(&:id).include? user.id }.blank?
      flash[:notice] = _('Cant_delete_user_it_has_callshops')
      redirect_to(controller: return_controller, action: return_action) && (return false)
    end

    if user.dids.count > 0
      flash[:notice] = _('Cant_delete_user_it_has_dids')
      redirect_to(controller: return_controller, action: return_action) && (return false)
    end

    if user.all_calls.count > 0
      flash[:notice] = _('Cant_delete_user_has_calls')
      redirect_to(controller: return_controller, action: return_action) && (return false)
    end

    if user.payments.count > 0
      flash[:notice] = _('Cant_delete_user_it_has_payments')
      redirect_to(controller: return_controller, action: return_action) && (return false)
    end

    if user.is_reseller?
      rusers = User.where(owner_id: user.id).count.to_i
      if rusers > 0
        flash[:notice] = _('Cant_delete_reseller_whit_users')
        redirect_to(controller: return_controller, action: return_action) && (return false)
      end
    end

    if user.is_accountant?
      accountant_users = User.where(responsible_accountant_id: user.id).count.to_i
      if accountant_users > 0
        flash[:notice] = _('Cant_delete_accountant_with_users')
        redirect_to(controller: return_controller, action: return_action) && (return false)
      end
    end
    dev_size = AstQueue.joins('LEFT JOIN devices ON (devices.id = queues.failover_data)').where("queues.failover_action = 'device' AND devices.user_id = #{user.id}").count
    if dev_size > 0
      flash[:notice] = _('User_Has_queues')
      redirect_to(controller: return_controller, action: return_action) && (return false)
    end

    agents_size = QueueAgent.joins('LEFT JOIN devices ON (devices.id = queue_agents.device_id)').where("devices.user_id = #{user.id}").count
    if agents_size > 0
      flash[:notice] = _('User_Has_queue_agents')
      redirect_to(controller: return_controller, action: return_action) && (return false)
    end

    if Alert.where(check_type: 'user', check_data: user.id).first
      flash[:notice] = _('User_Has_alerts')
      redirect_to(controller: return_controller, action: return_action) && (return false)
    end

    user_id = params[:id].to_i
    if user_id != 0
      username, nice_name = user.username, nice_user(user)
      user.destroy_everything
      action_hash = {action: 'user_deleted', target_id: user_id, data: username, target_type: 'user', data2: nice_name}
      Action.add_action_hash(current_user, action_hash)
      flash[:status] = _('User_deleted')
    else
      flash[:notice] = _('Cant_delete_sysadmin')
    end

    redirect_to(controller: return_controller, action: return_action)
  end

  ############# Device groups ###########
  # in before filter : user (:find_user)
  def device_groups
    @page_title = _('Device_groups')
    @page_icon = 'groups.png'

    unless @user.try :is_user?
      flash[:notice] = _('User_not_found')
      redirect_to(:root) && (return false)
    end

    @devicegroups = @user.devicegroups
    # for backwards compatibility - user had no device group before, so let's create one for him
    unless @user.primary_device_group
      devgroup = Devicegroup.new
      devgroup.init_primary(@user.id, 'primary', @user.address_id)
    end
  end

  # in before filter : devicegroup (:find_devicegroup)
  def device_group_edit
    @page_title = _('Device_group_edit')
    @page_icon = 'edit.png'

    @user = @devicegroup.user
    @countries = Direction.order(:name)
    @address = @devicegroup.address
  end

 # in before filter : devicegroup (:find_devicegroup)
  def device_group_update
    @devicegroup.update_attributes(params[:devicegroup])

    @address = @devicegroup.address
    @address.update_attributes(params[:address])
    @address.email = nil if @address.email.blank?
    if @address.save
      flash[:status] = _('Dev_groups_details_changed')
      redirect_to(action: 'device_groups', id: @devicegroup.user.id)
    else
      @user = @devicegroup.user
      @countries = Direction.order(:name)

      flash_errors_for(_('Dev_group_details_not_changed'), @address)
      render :device_group_edit
    end
  end

  # in before filter : user (:find_user)
  def device_group_new
    @page_title = _('Device_group_new')
    @page_icon = 'add.png'

    @devicegroup = Devicegroup.new
    @devicegroup.added = Time.now
    @devicegroup.name = _('Please_change')

    @countries = Direction.order(:name)
  end

  # in before filter : user (:find_user)
  def device_group_create
    @address = Address.new(params[:address])
    @address.email = nil if @address.email.to_s.blank?

    @devicegroup = Devicegroup.new(user_id: @user.id, name: params[:devicegroup][:name], added: Time.now.to_s(:db))
    if @address.save

      @devicegroup.address = @address

      if @devicegroup.save
        flash[:status] = _('Dev_group_created')
        redirect_to(action: 'device_groups', id: @devicegroup.user.id) && (return false)
      else

        @countries = Direction.order(:name)
        flash_errors_for(_('Dev_group_not_created'), @devicegroup)
        render :device_group_new
      end
    else

      @countries = Direction.order(:name)
      flash_errors_for(_('Dev_group_not_created'), @address)
      render :device_group_new
    end
  end

  # in before filter : devicegroup (:find_devicegroup)
  def device_group_delete
    user_id = @devicegroup.user_id
    if @devicegroup.destroy_everything
      flash[:status] = _('Dev_group_deleted')
    else
      flash[:notice] = _('Dev_group_not_deleted')
    end
    redirect_to(action: 'device_groups', id: user_id)
  end

  # in before filter : user (find_user_from_session)
  def personal_details
    @page_title = _('Personal_details')
    @page_icon = 'edit.png'

    @address = @user.address
    @countries = Direction.order(:name)
    @total_recordings_size = Recording.select("SUM(size) AS 'total_size'").where(user_id: @user.id).first['total_size'].to_d
    @i = @user.get_invoices_status

    @disallow_email_editing = Confline.get_value('Disallow_Email_Editing', current_user.owner.id) == '1'

    unless @address
      address = Address.new
      address.save
      @user.update_attributes(address: address)
    end

    @search_user = Device.where(id: @user.try(:spy_device_id)).first.try(:user)
    if user? || accountant?
      @devices = Device.find_all_for_select(current_user.id)
    else
      @devices = @search_user ? Device.where(user_id: @search_user.id) : []
    end
  end

  # in before filter : user (find_user_from_session)
  def update_personal_details
    current_user_id = current_user.id.to_i
    if params[:user].blank? || @user.id != current_user_id
      return false unless check_owner_for_user(@user.id)
    end
    unless current_user.check_for_own_providers
      @invoice = invoice_params_for_user

      @user.send_invoice_types = @invoice
    end

    bad_username = true if !params[:user] && !params[:user][:username].blank? && params[:user][:username].to_s.strip.length < @user.minimum_username
    bad_password = true if !params[:password].blank? && !params[:password][:password].blank? && params[:password][:password].to_s.strip.length < @user.minimum_password

    @user.update_attributes(current_user.safe_attributtes(params[:user].each_value(&:strip!), @user.id, current_user))
    @user.spy_device_id = params[:s_device]
    # A.S:  no more usertype switching #7908
    # @user.usertype = usertype
    @user.warning_email_active = params[:warning_email_active].to_i
    @user.password = Digest::SHA1.hexdigest(params[:password][:password]) if params[:password][:password].length > 0
    @user.warning_email_hour = params[:user][:warning_email_hour].to_i != -1 ? params[:date][:user_warning_email_hour].to_i : params[:user][:user_warning_email_hour].to_i
    if !@user.address
      address = Address.create(params[:address].each_value(&:strip!)) if params[:address]
      @user.address = address
    else
      @user.address.update_attributes(params[:address].each_value(&:strip!)) if params[:address]
    end
    @user.address.email = nil if @user.address.email.to_s.blank?

    if !bad_username && !bad_password && @user.address.valid? && @user.save

      # renew_session(@user)

      session[:first_name] = @user.first_name
      session[:last_name] = @user.last_name
      @user.address.save
      session[:show_currency] = @user.currency.name
      flash[:status] = _('Personal_details_changed')
      redirect_to :root
    else
      if user? || accountant?
        @devices = current_user.devices(conditions: "device_type != 'FAX'")
      else
        @devices = Device.find_all_for_select(corrected_user_id)
      end
      @countries = Direction.order(:name)
      @total_recordings_size = Recording.select("SUM(size) AS 'total_size'").where(user_id: @user.id).first['total_size'].to_d
      @i = @user.get_invoices_status
      @address = @user.address

      @user.errors.add(:password, _('Password_must_be_longer', (@user.minimum_password - 1))) if bad_password
      @user.errors.add(:username, _('Username_must_be_longer', (@user.minimum_username - 1))) if bad_username

      if !@user.address.valid?
        flash_errors_for(_('User_was_not_updated'), @user.address)
      else
        flash_errors_for(_('User_was_not_updated'), @user)
      end
      redirect_to(action: 'personal_details')
    end
  end

  # ============== CUSTOM RATES ===============

  # in before filter : user (:find_user)
  def custom_rates
    @page_title = _('Custom_rates')
    @page_icon = 'coins.png'

    unless @user.try(:is_user?) || @user.try(:is_reseller?)
      flash[:notice] = _('User_not_found')
      redirect_to(:root) && (return false)
    end
    @tariff = @user.tariff
    @crates = @user.customrates
    udestgroups = Destinationgroup.select('destinationgroups.id')
                                   .joins('LEFT JOIN customrates ON customrates.destinationgroup_id = destinationgroups.id
                                          LEFT JOIN users ON customrates.user_id = users.id')
                                   .where("user_id = #{@user.id}").order('destinationgroups.name')

    udg = []
    udestgroups.each { |udestgroup| udg << udestgroup['id'].to_i }

    @destgroups = []
    Destinationgroup.order(:name).each do |dg|
      @destgroups << dg unless udg.include?(dg.id)
    end

    @acc_finances	= (accountant? ? session[:acc_see_financial_data].to_i	: 2)
    @acc_manage_tariff	= (accountant? ? session[:acc_tariff_manage].to_i	: 2)
    @acc_tariff		= (accountant? ? session[:acc_user_create_opt_4].to_i	: 2)
  end

  # in before filter : user (:find_user)
  def user_custom_rate_add_new
    user_id = @user.id
    if accountant? && (session[:acc_user_create_opt_4].to_i != 2 || session[:acc_see_financial_data].to_i != 2)
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    else
      rate = Customrate.new(user_id: user_id,
                            destinationgroup_id: params[:dg_new])
      rate.save
      detail = Acustratedetail.new(from: 1,
                                   duration: -1,
                                   artype: 'minute',
                                   round: 1,
                                   price: 0,
                                   customrate: rate)
      detail.save

      flash[:status] = _('Custom_rate_added')
      redirect_to(action: 'custom_rates', id: user_id)
    end
  end

  # in before filter : customrate (:find_customrate)
  def user_delete_custom_rate
    user_id = @customrate.user_id
    @customrate.destroy_all
    flash[:status] = _('Custom_rate_deleted')
    redirect_to(action: 'custom_rates', id: user_id)
  end

  # in before filter : customrate (:find_customrate) ; ards (:find_ard_all)
  def artg_destroy
    dt = params[:dt] ? params[:dt] : ''

    pet = nice_time2(@ards[0].start_time - 1.second)

    @ards.each { |ard| ard.destroy }

    pards = Acustratedetail.where(customrate_id: @customrate.id, end_time: pet, daytype: dt)

    unless pards || (pards && pards.size.to_i == 0)
      flash[:notice] = _('Acustratedetails_not_found')
      redirect_to(:root) && (return false)
    end

    pards.each do |pard| pard.end_time = '23:59:59'
      pard.save
    end

    flash[:status] = _('Rate_details_updated')
    redirect_to(action: 'user_acustrates_full', id: @customrate.user_id, dg: @customrate.destinationgroup_id)
  end

  # in before filter : customrate (:find_customrate)
  def ard_manage
    status = @customrate.manage_details(params[:rdaction])
    status.each { |message| flash[:status] = message } if status.present?

    redirect_to(action: 'user_acustrates_full', id: @customrate.user_id, dg: @customrate.destinationgroup_id)
  end

  # in before filter : user (:find_user)
  def user_acustrates_full
    if accountant? && (session[:acc_user_create_opt_4].to_i != 2 || session[:acc_see_financial_data].to_i != 2)
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    end

    @page_title = _('Custom_rate_details')
    @page_icon = 'coins.png'

    if (@user.owner_id != current_user.id && !accountant?) || (accountant? && @user.owner_id != 0) || params[:dg].blank?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    @dgroup = Destinationgroup.where(id: params[:dg]).first
    @custrate = @dgroup.custom_rate(@user.id)
    @rate = @custrate
    @ards = @custrate.acustratedetails

    @wdfd, @st_arr, @et_arr, @wst_arr, @wet_arr, @fst_arr, @fet_arr = @custrate.manage_details_times
  end

# in before filter : customrate (:find_customrate); ards (:find_ard_all)
  def user_ard_time_edit
    if accountant? && session[:acc_user_create_opt_4].to_i != 2
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    end

    date = params[:date]
    hour = date[:hour]
    minute = date[:minute]
    second = date[:second]

    redirect_path = {action: 'user_acustrates_full', id: @customrate.user_id, dg: @customrate.destinationgroup_id}

    dt = params[:daytype] || ''
    et = [hour, minute, second].join(':')
    st = params[:st]

    if st.to_s > et.to_s
      flash[:notice] = _('Bad_time')
      redirect_to(redirect_path) && (return false)
    end

    rdetails = @customrate.acustratedetails_by_daytype(params[:daytype])
    aratedetail = Acustratedetail.where(customrate_id: @customrate.id, start_time: st, daytype: dt).first

    unless aratedetail
      flash[:notice] = _('Acustratedetail_not_found')
      redirect_to(:root) && (return false)
    end

    # we need to create new rd to cover all day
    if (et != '23:59:59') && ((rdetails[(rdetails.size - 1)].start_time == aratedetail.start_time))
      @ards.each do |ard|
        nst = Time.mktime('2000', '01', '01', hour, minute, second) + 1.second
        new_detail = Acustratedetail.new(from: ard.from,
                                         duration: ard.duration,
                                         artype: ard.artype,
                                         round: ard.round,
                                         price: ard.price,
                                         customrate: ard.customrate,
                                         start_time: nst,
                                         end_time: '23:59:59',
                                         daytype: ard.daytype)
        new_detail.save
        ard.end_time = et
        ard.save
      end
    end

    flash[:status] = _('Rate_details_updated')
    redirect_to(redirect_path)
  end

# in before filter : customrate (:find_customrate); ards (:find_ard_all)
  def user_acustrates
    if accountant? && (session[:acc_user_create_opt_4].to_i != 2 || session[:acc_see_financial_data].to_i != 2)
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    end

    @user = @customrate.user
    @page_title = _('Custom_rate_details')
    @page_icon = 'coins.png'
    @dgroup = @customrate.destinationgroup

    if (!accountant? && @user.owner_id != current_user.id) || (accountant? && @user.owner_id != 0)
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    @st = params[:st]
    @dt = params[:dt] ? params[:dt] : ''
    @et = nice_time2(@ards[0].end_time)

    @can_add = false
    lard = @ards[@ards.size - 1]
    if (lard.duration != -1 && lard.artype == 'minute') || (lard.artype == 'event')
      @can_add = true
      @from = lard.from + lard.duration if lard.artype == 'minute'
      @from = lard.from if lard.artype == 'event'
    end

    @acc_finances	= accountant? ? session[:acc_see_financial_data].to_i	: 2
    @acc_manage_tariff	= accountant? ? session[:acc_tariff_manage].to_i	: 2
    @acc_tariff		= accountant? ? session[:acc_user_create_opt_4].to_i	: 2
  end

# in before filter : ard (:find_ard)
  def user_custom_rate_update
    rate = @ard.customrate
    @dgroup = rate.destinationgroup
    @user = rate.user

    artype = params[:artype]

    duration = params[:duration].to_i
    infinity = params[:infinity]
    duration = -1 if infinity == '1' && artype == 'minute'
    duration = 0 if artype == 'event'

    round = params[:round].to_i
    price = params[:price].to_d
    round = 1 if round < 1

    @ard.update_attributes(from: params[:from],
                           artype: artype,
                           duration: duration,
                           round: round,
                           price: price)

    rate_id = @ard.customrate_id
    st = nice_time2 @ard.start_time
    dt = @ard.daytype

    flash[:status] = _('Custom_rate_updated')
    redirect_to(action: 'user_acustrates', id: rate_id, st: st, dt: dt)
  end

# in before filter : customrate (:find_customrate)
  def user_custom_rate_add
    if accountant? && (session[:acc_user_create_opt_4].to_i != 2 || session[:acc_see_financial_data].to_i != 2)
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    else
      artype = params[:artype]

      duration = params[:duration].to_i
      infinity = params[:infinity]
      duration = -1 if infinity == '1' && artype == 'minute'
      duration = 0 if artype == 'event'

      round = params[:round].to_i
      price = params[:price].to_d
      round = 1 if round < 1

      rate_id = @customrate.id
      st = params[:st]
      et = params[:et]
      dt = params[:dt] || ''

      @ard = Acustratedetail.new(from: params[:from],
                                 artype: artype,
                                 duration: duration,
                                 round: round,
                                 price: price,
                                 customrate: @customrate,
                                 daytype: dt,
                                 start_time: st,
                                 end_time: et)
      @ard.save

      flash[:status] = _('Custom_rate_updated')
      redirect_to(action: 'user_acustrates', id: rate_id, st: st, dt: dt)
    end
  end

# in before filter : ard (:find_ard)
  def user_custom_rate_delete
    rate_id = @ard.customrate_id
    st = nice_time2 @ard.start_time
    dt = @ard.daytype
    @ard.destroy
    flash[:status] = _('Custom_rate_updated')
    redirect_to(action: 'user_acustrates', id: rate_id, st: st, dt: dt)
  end

  def default_user
    @page_title = _('Default_user')
    @page_icon = 'edit.png'
    owner = correct_owner_id
    if Confline.where(["name LIKE 'Default_Tax_%' AND owner_id = ?", owner]).count > 0
      @tax = Confline.get_default_object(Tax, owner)
    else
      @tax = Tax.new
      if reseller?
        reseller = User.where(id: owner).first
        @tax = reseller.get_tax.dup
      else
        @tax.assign_default_tax({}, {save: false})
      end
    end
    @user = Confline.get_default_object(User, owner)

    @user.owner_id = owner # owner_id nera default data. taigi reikia ji papildomai nustatyt
    @address = Confline.get_default_object(Address, owner)
    @user.tax = @tax
    @user.address = @address
    @groups = AccGroup.where(group_type: 'accountant')
    @groups_resellers = AccGroup.where(group_type: 'reseller')

    @lcrs = current_user.load_lcrs({order: 'name ASC'})

    cond = @user_wholesale_disabled ? " AND purpose = 'user' " : " AND (purpose = 'user' OR purpose = 'user_wholesale') "

    @tariffs = Tariff.where("owner_id = '#{owner}' #{cond} ").order('purpose ASC, name ASC')
    @countries = Direction.order(:name)

    @password_length = Confline.get_value('Default_User_password_length', owner).to_i
    @username_length = Confline.get_value('Default_User_username_length', owner).to_i

    @password_length = 8 if @password_length.equal? 0
    @username_length = 1 if @username_length.equal? 0

    @warning_email = {}
    @warning_email[:balance] = Confline.get_value('Default_User_warning_email_balance', owner)
    @warning_email[:balance_admin] = Confline.get_value('Default_User_warning_email_balance_admin', owner)
    @warning_email[:balance_manager] = Confline.get_value('Default_User_warning_email_balance_manager', owner)

    if User.current.try(:currency)
      @warning_email[:balance] = (@warning_email[:balance].to_d * User.current.currency.exchange_rate.to_d).to_d
      @warning_email[:balance_admin] = (@warning_email[:balance_admin].to_d * User.current.currency.exchange_rate.to_d).to_d
      @warning_email[:balance_manager] = (@warning_email[:balance_manager].to_d * User.current.currency.exchange_rate.to_d).to_d
    end

    if @lcrs.empty? && allow_manage_providers?
      flash[:notice] = _('No_lcrs_found_user_not_functional')
      redirect_to(action: 'list') && (return false)
    end

    if @tariffs.empty?
      flash[:notice] = _('No_tariffs_found_user_not_functional')
      redirect_to(action: 'list') && (return false)
    end

    @i = @user.get_invoices_status

    @blacklists_on = true if admin?
    @bl_global_setting = Confline.get_value('blacklist_enabled', 0).to_i.equal?(1) ? 'Yes' : 'No'
    @pbx_pools = PbxPool.where(owner_id: current_user.id).order('name ASC').all.map { |pool| [pool.name, pool.id] }
  end

  def default_user_update
    owner = correct_owner_id

    @invoice = invoice_params_for_user

    params[:user][:send_invoice_types] = @invoice
    params[:user][:generate_invoice] = params[:user][:generate_invoice].to_i
    params[:user][:recording_enabled] = params[:recording_enabled]
    params[:user][:recording_forced_enabled] = params[:recording_forced_enabled]
    params[:user][:allow_loss_calls] = params[:allow_loss_calls].to_i
    params[:user][:hide_non_answered_calls] = params[:hide_non_answered_calls].to_i
    params[:user][:block_conditional_use] = params[:block_conditional_use].to_i
    params[:user][:block_at] = params[:block_at_date][:year].to_s + '-' + params[:block_at_date][:month].to_s + '-' + params[:block_at_date][:day].to_s
    params[:user][:warning_email_active] = params[:warning_email_active].to_i
    params[:user][:invoice_zero_calls] = params[:show_zero_calls].to_i
    params[:user][:acc_group_id] = params[:accountant_type]
    params[:user][:cyberplat_active] = params[:cyberplat_active].to_i
    params[:user][:balance] = current_user.convert_curr(params[:user][:balance].to_d)
    params[:user][:recording_hdd_quota] = (params[:user][:recording_hdd_quota].to_d * 1048576).to_i
    params[:user] = User.default_blacklist_params(params[:user])
    # for validating threshold values
    # routing_thresholds = {}
    # routing_thresholds[:routing_threshold] = params[:user][:routing_threshold].to_s.strip
    # routing_thresholds[:routing_threshold_2] = params[:user][:routing_threshold_2].to_s.strip
    # routing_thresholds[:routing_threshold_3] = params[:user][:routing_threshold_3].to_s.strip
    # blacklist_lcrs = {}
    # blacklist_lcrs[:blacklist_lcr] = params[:user][:blacklist_lcr]
    # blacklist_lcrs[:blacklist_lcr_2] = params[:user][:blacklist_lcr_2]
    # blacklist_lcrs[:blacklist_lcr_3] = params[:user][:blacklist_lcr_3]
    # validate_with_letters = false

    # flash[:notice], err = Application.validate_routing_threshold_values(routing_thresholds, blacklist_lcrs, validate_with_letters)

    # if err == 1
    #   redirect_to :action => :default_user and return false
    # end

    params[:user][:minimal_charge] = params[:minimal_charge_value].to_i
    if params[:minimal_charge_value].to_i != 0 && params[:minimal_charge_date]
      year = params[:minimal_charge_date][:year].to_i
      month = params[:minimal_charge_date][:month].to_i
      params[:user][:minimal_charge_start_at] = Time.gm(year, month, 1, 0, 0, 0)
    elsif params[:minimal_charge_value].to_i == 0
      params[:user][:minimal_charge_start_at] = nil
    end

    if params[:unlimited].to_i == 1
      params[:user][:credit] = -1
    else
      params[:user][:credit] = params[:credit].to_d
      params[:user][:credit] = 0 if params[:user][:credit] < 0
    end

    # privacy
    if params[:privacy]
      if params[:privacy][:global].to_i == 1
        params[:user][:hide_destination_end] = -1
      else
        params[:user][:hide_destination_end] = params[:privacy].values.sum { |value| value.to_i }
      end
    end

    if params[:username_length].strip.to_i < 1
      flash[:notice] = _('Username_must_be_longer', 0)
      redirect_to(action: :default_user) && (return false)
    end

    if params[:password_length].strip.to_i < 6
      flash[:notice] = _('Password_must_be_longer', 5)
      redirect_to(action: :default_user) && (return false)
    end

    if params[:password_length].strip.to_i > 30
      flash[:notice] = _('Password_cannot_be_longer_than')
      redirect_to(action: :default_user) && (return false)
    end

    if !Email.address_validation(params[:address][:email]) && params[:address][:email].to_s.length.to_i > 0
      flash[:notice] = _('Email_address_not_correct')
      redirect_to(action: :default_user) && (return false)
    end

    unless params[:warning_email_balance].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ || params[:warning_email_balance].to_s == ''
      flash[:notice] = _('user_warning_balance_numerical')
      redirect_to(action: :default_user, warning_email_balance: params[:warning_email_balance]) && (return false)
    end

    unless params[:warning_email_balance_admin].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ || params[:warning_email_balance_admin].to_s == ''
      flash[:notice] = _('admin_warning_balance_numerical')
      redirect_to(action: 'default_user', warning_email_balance_admin: params[:warning_email_balance_admin]) && (return false)
    end

    unless params[:warning_email_balance_manager].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ || params[:warning_email_balance_manager].to_s == ''
      flash[:notice] = _('manager_warning_balance_numerical')
      redirect_to(action: 'default_user', warning_email_balance_manager: params[:warning_email_balance_manager]) && (return false)
    end

    params[:warning_email_balance] = params[:warning_email_balance].to_s.strip.sub(/[\,\.\;]/, '.').to_d
    params[:warning_email_balance_admin] = params[:warning_email_balance_admin].to_s.strip.sub(/[\,\.\;]/, '.').to_d
    params[:warning_email_balance_manager] = params[:warning_email_balance_manager].to_s.strip.sub(/[\,\.\;]/, '.').to_d

    if params[:warning_email_active]
      params[:user][:warning_email_hour] = params[:user][:warning_email_hour].to_i != -1 ? params[:date][:user_warning_email_hour].to_i : params[:user][:warning_email_hour].to_i
    end

    Confline.set_default_object(User, owner, params[:user])
    Confline.set_default_object(Address, owner, params[:address])
    tax = tax_from_params
    @blacklists_on = true if admin?
    @bl_global_setting = Confline.get_value('blacklist_enabled', 0).to_i.equal?(1) ? 'Yes' : 'No'
    tax[:total_tax_name] = 'TAX' if tax[:total_tax_name].blank?
    tax[:tax1_name] = params[:total_tax_name].to_s if params[:tax1_name].blank?
    Confline.set_default_object(Tax, owner, tax)

    params[:password_length] = 8 if params[:password_length].to_i < 1
    Confline.set_value('Default_User_password_length', params[:password_length].to_i, owner)
    Confline.set_value('Default_User_username_length', params[:username_length].to_i, owner)

    if User.current.try(:currency)
      user_exchange_rate = User.current.currency.exchange_rate.to_d
      params[:warning_email_balance] = (params[:warning_email_balance].to_d / user_exchange_rate).to_d
      params[:warning_email_balance_admin] = (params[:warning_email_balance_admin].to_d / user_exchange_rate).to_d
      params[:warning_email_balance_manager] = (params[:warning_email_balance_manager].to_d / user_exchange_rate).to_d
    end

    Confline.set_value('Default_User_warning_email_balance', params[:warning_email_balance], owner)
    Confline.set_value('Default_User_warning_email_balance_admin', params[:warning_email_balance_admin], owner)
    Confline.set_value('Default_User_warning_email_balance_manager', params[:warning_email_balance_manager], owner)

    flash[:status] = _('Default_User_Saved')
    redirect_to(action: :default_user)
  end

  # lets hope thats temporary hack so that we wouldnt duplicate code
  # when dinamicaly generating queries. may be someday we wouldnt be
  # generating them this way.
  def users_sql
    joins = []
    joins << 'LEFT JOIN tariffs ON users.tariff_id = tariffs.id'
    joins << 'LEFT JOIN addresses ON users.address_id = addresses.id'
    joins << 'LEFT JOIN lcrs ON users.lcr_id = lcrs.id'
    select = []
    select << 'users.*'
    select << 'addresses.city, addresses.county'
    select << 'lcrs.name AS lcr_name'
    select << 'tariffs.name AS tariff_name'
    [select.join(','), joins.join(' ')]
  end

  def users_weak_passwords
    if current_user.is_admin?
      select, join = users_sql
      @users = User.select(select).joins(join).where(["password = SHA1('') or password = SHA1(username)"])
    end
  end

  def users_postpaid_and_allowed_loss_calls
    @page_title = _('User_is_set_to_postpaid_and_allowed_loss_calls')
    @page_icon = 'vcard.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Loss_Making_Calls'
    @users_postpaid_and_loss_calls = User.where(postpaid: 1, allow_loss_calls: 1)

    # order
    @options = params.reject { |key, _| %w(controller action).member? key.to_s }

    @options[:order_desc] = params[:order_desc].to_i
    @options[:order_by] = params[:order_by]

    @users_postpaid_and_loss_calls.sort_by! do |user|
      nice_user(@options[:order_by] == 'user' ? user : user.owner).downcase
    end
    @users_postpaid_and_loss_calls.reverse! if @options[:order_desc].to_i.zero?
  end

  def default_user_errors_list
    @page_title, @page_icon, @help_link = [_('Default_users_are_set_to_postpaid_and_allowed_loss_calls'),
                                           'vcard.png',
                                           'http://wiki.kolmisoft.com/index.php/Loss_Making_Calls']

    ownr = Confline.get_default_user_pospaid_errors
    ids = []
    ownr.each { |owner| ids << owner['owner_id'] }
    @default_users_postpaid_and_loss_calls = User.where(id: ids)

    # order
    @options = params.reject { |key, _| %w(controller action).member? key.to_s }

    @options[:order_desc] = params[:order_desc].to_i
    @options[:order_by] = params[:order_by]

    @default_users_postpaid_and_loss_calls = User.where(id: ids).sort_by! { |user| nice_user(user).downcase }
    @default_users_postpaid_and_loss_calls.reverse! if @options[:order_desc].to_i.zero?
  end

  # we need to find all accountants that might be responsible for admins users, so that we could
  # show them in /users/edit/X or /users/default_user. but only for admin. and there would be no
  # purpose to show that list /users/edit/X if X would be smt other than simple admins users.
  # But that's in theory, at this moment we dont have infomration about user - @user is set in
  # controller's action, dont know why...
  def find_responsible_accountants
    @responsible_accountants = User.responsible_acc if admin? || accountant?
  end

  def reseller_users_restriction
    reseller? && (!reseller_active? || ((current_user.own_providers == 1) && !reseller_pro_active?))
  end

  def default_user_options(session_user_stats, its_list)
    default = {
      items_per_page: session[:items_per_page].to_i,
      page: '1',
      order_by: 'nice_user',
      order_desc: 0,
      s_username: '',
      s_first_name: '',
      s_last_name: '',
      s_agr_number: '',
      s_acc_number: '',
      s_clientid: '',
      sub_s: '-1',
      user_type: '-1',
      s_email: '',
      s_id: ''
    }
    default[:responsible_accountant_id] = '' if its_list

    options = params[:clean] || !session_user_stats ? default : session_user_stats

    default.each { |key, _value| options[key] = params[key] if params[key] }
    options[:order_by_full] = options[:order_by] + (options[:order_desc] == 1 ? ' DESC' : ' ASC')
    options[:order] = User.users_order_by(params, options)

    options
  end

  def get_users_map
    output = []
    style = "width='177px' style='margin-left:20px;padding-left:6px;font-size:10px;font-weight: normal;'"
    @user_str = params[:livesearch].to_s

    unless @user_str.blank?
      output, @total_users = User.seek_by_filter(current_user, @user_str, style, params)
    end

    if params[:empty_click].to_s == 'true'
      output << ["<tr><td id='-2' #{style}>" << _('Enter_value_here') << '</td></tr>']
    end

    render(text: output.join)
  end

  private

  def check_owner_for_user(user)
    user = User.where(id: user).first unless user.class == User

    if user.blank?
      flash[:notice] = _('User_was_not_found')
      redirect_to(action: 'list') && (return false)
    end

    if accountant?
      if user.id == session[:user_id]
        redirect_to(action: 'personal_details') && (return true)
      end
      owner_id = User.where(id: session[:user_id].to_i).first.get_owner.id.to_i
      if user.is_admin? || user.is_accountant?
        flash[:notice] = _('You_have_no_permission')
        redirect_to(action: 'list') && (return false)
      end
    else
      owner_id = session[:user_id]
    end

    if user.owner_id != owner_id
      flash[:notice] = _('You_have_no_permission')
      redirect_to(action: 'list') && (return false)
    end
    true
  end

 # Checks if accountant is allowed to create devices.
  def check_for_accountant_create_user
    if accountant? && session[:acc_user_create] != 2
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

 # Clears values accountant is not allowed to send.
  def sanitize_user_params_by_accountant_permissions(user = nil)
    if accountant?
      if session[:acc_user_create_opt_1] != 2
        if params[:action] != 'update'
          length = Confline.get_value('Default_User_password_length', correct_owner_id).to_i
          length = 8 if length <= 0
          params[:password] = {} if params[:password].nil?
          params[:password][:password] = random_password(length)
        else
          params[:password] = nil
        end
      end
      {acc_user_create_opt_2: [:usertype],
       acc_user_create_opt_3: [:lcr_id],
       acc_user_create_opt_4: [:tariff_id],
       acc_user_create_opt_5: [:balance],
       acc_user_create_opt_6: [:postpaid, :hidden],
       acc_user_create_opt_7: [:call_limit]
      }.each do |option, fields|
        fields.each { |field| params[:user].except!(field) if session[option] != 2 }
      end
      params[:password] = nil if user.try(:is_admin?)
    end
  end

  def check_params
    unless params[:user]
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def find_user(ignore_owner = false)
    join = ['LEFT JOIN `addresses` ON `addresses`.`id` = `users`.`address_id`']
    join << 'LEFT JOIN `taxes` ON `taxes`.`id` = `users`.`tax_id`'
    join << 'LEFT JOIN `tariffs` ON `tariffs`.`id` = `users`.`tariff_id`'
    @user = User.select('users.*, tariffs.purpose').joins([join.join(' ')]).where(['users.id = ?', params[:id].to_i]).first

    if !@user || (@user.owner_id != current_user.get_correct_owner_id && !ignore_owner)
      flash[:notice] = _('User_not_found')
      redirect_to(:root) && (return false)
    end
  end

  def find_user_from_session
    @user = User.where(id: session[:user_id]).first

    unless @user
      flash[:notice] = _('User_not_found')
      redirect_to(:root) && (return false)
    end
  end

  def find_devicegroup
    @devicegroup = Devicegroup.includes(:user).where(['devicegroups.id = ? AND users.owner_id = ?', params[:id], current_user.id]).references(:user).first
    unless @devicegroup
      flash[:notice] = _('Dev_group_not_found')
      redirect_to(:root) && (return false)
    end
  end

  def find_customrate
    @customrate = Customrate.where(id: params[:id]).first

    if @customrate.blank?
      flash[:notice] = _('Customrate_not_found')
      redirect_to(:root) && (return false)
    end
  end

  def find_ard
    @ard = Acustratedetail.where(id: params[:id]).first

    if @ard.blank?
      flash[:notice] = _('Acustratedetail_not_found')
      redirect_to(:root) && (return false)
    end
  end

  def find_ard_all
    if params[:action] == 'user_ard_time_edit'
      dt = params[:daytype] ? params[:daytype] : ''
    else
      dt = params[:dt] ? params[:dt] : ''
    end
    @ards = Acustratedetail.where(customrate_id: @customrate.id, start_time: params[:st], daytype: dt).order('acustratedetails.from ASC, artype ASC')
    if !@ards || (@ards && @ards.size.to_i == 0)
      flash[:notice] = _('Acustratedetails_not_found')
      redirect_to(:root) && (return false)
    end
  end

  def check_with_integrity
    session[:integrity_check] = current_user.integrity_recheck_user if current_user
  end

  def check_rs_user_count
    users_limit = 2
    if User.where(owner_id: current_user.id).count >= users_limit
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    end
  end

  def check_selected_rs_user_count
    users_count = User.where(owner_id: params[:id]).count
    if (params[:own_providers].to_i == 1) && (users_count > 2)
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def user_wholesale_disabled
    @user_wholesale_disabled = Confline.get_value('User_Wholesale_Enabled').to_i == 0
  end

  def invoice_params_for_user
    @i1 = params[:i1]
    @i2 = params[:i2]
    @i3 = params[:i3]
    @i4 = params[:i4]
    @i5 = params[:i5]
    @i6 = params[:i6]
    @i7 = params[:i7]
    @i8 = params[:i8]
    @i1.to_i + @i2.to_i + @i3.to_i + @i4.to_i + @i5.to_i + @i6.to_i + @i7.to_i + @i8.to_i
  end

  def default_blacklist_thresholds_and_lcrs
    @bl_global_threshold, @bl_global_threshold_2, @bl_global_threshold_3 = User.find_global_thresholds
    @bl_default_lcr, @bl_default_lcr_2, @bl_default_lcr_3 = User.find_global_lcrs
  end
end
