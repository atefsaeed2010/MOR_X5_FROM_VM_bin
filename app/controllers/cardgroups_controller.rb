# -*- encoding : utf-8 -*-
class CardgroupsController < ApplicationController

  layout "callc"
  before_filter :check_post_method, only: [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize

  before_filter :check_if_can_see_finances, only: [:new, :create]
  #before_filter :authorize_admin
  before_filter :allow_add_card_group?, only: [:new, :crate]
  before_filter :set_cardgroups_page, only: [:list, :search, :user_search]

  @@card_view_res = []
  @@card_edit_res = [:list, :search, :show, :new, :create, :edit, :update, :destroy, :cards_to_csv, :upload_card_image]
  before_filter(only: @@card_view_res+@@card_edit_res) { |card|
    allow_read, allow_edit = card.check_read_write_permission(@@card_view_res, @@card_edit_res, {:role => 'reseller', :right => :res_calling_cards, :ignore => true})
    card.instance_variable_set :@allow_read_res, allow_read
    card.instance_variable_set :@allow_edit_res, allow_edit
    true
  }

  before_filter :find_card_group , only: [:destroy, :show, :edit, :update, :cards_to_csv, :upload_card_image, :gmp_list]

  def index
    redirect_to(action: 'list') && (return false)
  end

  def list
    usertype_accountant = (session[:usertype] == 'accountant')
    session_acc_callingcard_manage = session[:acc_callingcard_manage].to_i
    @show_pin = !(usertype_accountant && session[:acc_callingcard_pin].to_i == 0)
    @allow_manage = !(usertype_accountant && (session_acc_callingcard_manage == 0 || session_acc_callingcard_manage == 1))
    @allow_read = !(usertype_accountant && (session_acc_callingcard_manage == 0))
    if @allow_read == false
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    @allow_add_new_cardgroup = ((Cardgroup.where(owner_id: current_user_id).count < 1) || (calling_cards_active?))

    user_id = get_user_id()

    session[:cardgroup_search_options] ||= {}

    @search, @options = 0, {
        's_number' => '',
        's_pin' => '',
        's_balance_max' => '',
        's_balance_min' => '',
        's_sold' => '',
        's_caller_id' => ''
    }

    @options = @options.merge(session[:cardgroup_search_options])

    @cardgroups = Cardgroup.select('cardgroups.*, COUNT(cards.id) AS card_count').joins('LEFT JOIN cards ON (cards.cardgroup_id = cardgroups.id and cards.hidden = 0)').where(['cardgroups.owner_id = ?', user_id]).group('cardgroups.id').all

    if !cc_active? && !@cardgroups.empty?
      set_card_groups
    end
  end

  # card group list for distributors
  def user_list
    current_user_cards = current_user.cards
    if !current_user_cards || current_user_cards.size.to_i == 0
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    end

    @page_title = _('Card_groups')

    session[:cardgroup_search_options] ||= {}

    @options = {
      's_number' => '',
      's_pin' => '',
      's_balance_max' => '',
      's_balance_min' => '',
      's_sold' => '',
      's_caller_id' => ''
    }

    @pin_visible = Confline.get_value('CCShop_hide_pins_for_distributors').to_i.zero?
    @options = @options.merge(session[:cardgroup_search_options])

    @cardgroups = Cardgroup.select('cardgroups.*, COUNT(cards.id) AS card_count').joins('LEFT JOIN cards ON (cards.cardgroup_id = cardgroups.id and cards.hidden = 0)').where(['cards.user_id = ?', current_user_id]).group('cardgroups.id').all
  end

  def search
    session_usertype = session[:usertype]
    session_items_per_page = session[:items_per_page]
    session_acc_callingcard_manage = session[:acc_callingcard_manage].to_i
    user_accountant = (session_usertype == 'accountant')
    manage_zero = (session_acc_callingcard_manage == 0)
    @allow_manage = !(user_accountant && (manage_zero || session_acc_callingcard_manage == 1))
    @allow_read = !(user_accountant && (manage_zero))
    if @allow_read == false
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    @show_pin = !(user_accountant && session[:acc_callingcard_pin].to_i == 0)

    manage_search_options
    @page = params[:page].to_i

    @options['trial'] = !calling_cards_active?

    @cards, @card_count = Card.search(corrected_user_id, @options, page: @page, per_page: session_items_per_page)
    @total_pages = (@card_count / session_items_per_page.to_d).ceil
  end

  def user_search
    params_page = params[:page].to_i
    session_items_per_page = session[:items_per_page]
    @pin_visible = Confline.get_value('CCShop_hide_pins_for_distributors').to_i.zero?

    manage_search_options
    @page = params_page.zero? ? 1 : params_page

    @options['trial'] = !calling_cards_active?

    @cards, @card_count = Card.search(current_user_id, @options, page: @page - 1, per_page: session_items_per_page)
    @total_pages = (@card_count / session_items_per_page.to_d).ceil
  end

  def show
    session_acc_callingcard_manage = session[:acc_callingcard_manage].to_i
    @allow_manage = !(session[:usertype] == 'accountant' && (session_acc_callingcard_manage == 0 || session_acc_callingcard_manage == 1))
    @page_title = _('Card_group_details')
    @page_icon = 'details.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Calling_Card_Groups'

    variables_by_cardgroup

    unless @cardgroup
      flash[:notice] = _('Cardgroup_not_found')
      redirect_to(action: 'list') && (return false)
    end
    check_user_for_cardgroup(@cardgroup)

    # Dialplan <-> Did association is broken: did belongs to dialplan but dialplan DOES NOT have many dids for some insane reason!
    @assigned_dids = current_user.dialplans.where(data1: @cardgroup.number_length, data2: @cardgroup.pin_length).inject([]) { |dids, dialplan| dids.push(dialplan.dids) }.flatten
  end

  def new
    session_usertype = session[:usertype].to_s
    session_acc_callingcard_manage = session[:acc_callingcard_manage].to_i
    session_tmp_new_tax = session[:tmp_new_tax]
    session_tmp_new_cardgroup = session[:tmp_new_cardgroup]
    @allow_manage = !(session_usertype == 'accountant' && (session_acc_callingcard_manage == 0 || session_acc_callingcard_manage == 1))
    unless @allow_manage
      flash[:notice] = _('You_have_no_editing_permission')
      redirect_to(:root) && (return false)
    end
    @page_title = _('New_card_group')
    @page_icon = 'add.png'

    if session_tmp_new_cardgroup.nil?
      @cardgroup = Cardgroup.new
      @price_with_vat = 0
    else
      @cardgroup = session_tmp_new_cardgroup
      cardgroup_price = @cardgroup.price
      if @cardgroup.tax
        @price_with_vat = cardgroup_price + @cardgroup.get_tax.count_tax_amount(cardgroup_price)
      else
        @price_with_vat = cardgroup_price
      end
    end

    user_id = get_user_id
    user = User.where(id: user_id).first

    if session_tmp_new_tax.nil?
      if session_usertype == 'reseller'
        tax = user.get_tax
      else
        tax = Tax.new
        tax.assign_default_tax({}, { save: false })
      end
    else
      tax = session_tmp_new_tax
    end

    current_user_lcrs = current_user.lcrs
    if reseller? && !current_user.reseller_allow_providers_tariff?
      @lcrs = current_user_lcrs.where(id: user.lcr_id).order('name ASC').all
    else
      @lcrs = current_user_lcrs.order('name ASC').all
    end
    @locations = current_user.locations

    @cardgroup.tax = tax
    @tariffs = Tariff.find_by_user(user_id)

    if @tariffs.empty?
      flash[:notice] = _('No_tariffs_found')
      redirect_to(action: 'list') && (return false)
    end

    @currencies = Currency.get_active
  end

  def create
    change_date

    price_with_vat = params[:price_with_vat].to_d
    tax = tax_from_params

    @cardgroup = Cardgroup.new(params[:cardgroup]) do |cg|
      cg.temp_pl = params[:cardgroup][:pin_length]
      cg.valid_from = nice_date_from_params(params[:date_from]) + ' 00:00:00'
      cg.valid_till = nice_date_from_params(params[:date_till]) + ' 23:59:59'
      cg.owner_id = get_user_id
      cg.allow_loss_calls = params[:allow_loss_calls].to_i
      cg.disable_voucher = params[:disable_voucher].to_i
    end

    @cardgroup.tax = Tax.new(tax)
    tax_save = @cardgroup.tax.save

    @cardgroup.price = @cardgroup.tax.count_amount_without_tax(price_with_vat)

    if session[:usertype].to_s == 'reseller' && current_user.own_providers.to_i == 0
      user = User.where(id: get_user_id).first
      @cardgroup.assign_attributes(lcr: Lcr.where(id: user.lcr_id).order('name ASC').first)
    end
    if @cardgroup.save && tax_save
      session[:tmp_new_cardgroup] = nil
      session[:tmp_new_tax] = nil
      flash[:status] = _('Cardgroup_was_successfully_created')
      redirect_to action: 'show', id: @cardgroup.id
    else
      session[:tmp_new_cardgroup] = @cardgroup
      session[:tmp_new_tax] = @cardgroup.tax
      @cardgroup.tax.destroy if @cardgroup.tax
      @cardgroup.fix_when_is_rendering

      flash_errors_for(_('Cardgroup_was_not_created'), @cardgroup)
      redirect_to action: 'new'
    end
  end

  def edit
    @page_title = _('Card_group_edit')
    @page_icon = 'edit.png'
    @cardgroup = Cardgroup.includes(:tax).where(id: params[:id]).first
    unless @cardgroup
      flash[:notice] = _('Cardgroup_was_not_found')
      redirect_to(action: 'list') && (return false)
    end

    @cardgroup.assign_default_tax if @cardgroup.tax.nil?
    check_user_for_cardgroup(@cardgroup)

    user_id = get_user_id
    user= User.where(id: user_id).first

    if reseller? && !current_user.reseller_allow_providers_tariff?
      @lcrs = current_user.lcrs.where(id: user.lcr_id).order('name ASC').all
    else
      @lcrs = current_user.lcrs.order('name ASC').all
    end

    @locations = current_user.locations
    @tariffs= Tariff.find_by_user(user_id)

    @price_with_vat = @cardgroup.price.to_d + @cardgroup.get_tax.count_tax_amount(@cardgroup.price.to_d).to_d

    @cardgroup.valid_from = (Date.today.to_s + ' 00:00:00') if @cardgroup.valid_from.blank? || @cardgroup.valid_from.to_s == '0000-00-00 00:00:00'
    @cardgroup.valid_till = (Date.today.to_s + ' 23:59:59') if @cardgroup.valid_till.blank? || @cardgroup.valid_till.to_s == '0000-00-00 00:00:00'
    @cardgroup.save

    time_from = @cardgroup.valid_from.to_time
    @year_from = time_from.year
    @month_from = time_from.month
    @day_from = time_from.day
    time_till = @cardgroup.valid_till.to_time
    @year_till = time_till.year
    @month_till = time_till.month
    @day_till = time_till.day

    # my_debug @year_till
    @currencies = Currency.get_active
    @cardgroup.fix_when_is_rendering
  end

  def update
    @cardgroup = Cardgroup.includes(:tax).where(id: params[:id]).first
    unless @cardgroup
      flash[:notice] = _('Cardgroup_was_not_found')
      redirect_to(action: 'list') && (return false)
    end
    check_user_for_cardgroup(@cardgroup)
    change_date
    @cardgroup.update_attributes(params[:cardgroup])
    @price_with_vat = price_with_vat = params[:price_with_vat].to_d

    tax = tax_from_params
    @cardgroup.get_tax.update_attributes(tax)
    @cardgroup.assign_attributes(price: @cardgroup.get_tax.count_amount_without_tax(price_with_vat),
                                 valid_from: session_from_date + ' 00:00:00',
                                 valid_till: session_till_date + ' 23:59:59',
                                 allow_loss_calls: params[:allow_loss_calls].to_i,
                                 disable_voucher: params[:disable_voucher].to_i)

    if @cardgroup.save
      flash[:status] = _('Cardgroup_was_successfully_updated')
      redirect_to action: 'show', id: @cardgroup
    else
      @currencies = Currency.get_active
      flash_errors_for(_('Cardgroup_was_not_updated'), @cardgroup)
      user_id = get_user_id
      current_user_lcrs = current_user.lcrs
      if reseller? && !current_user.reseller_allow_providers_tariff?
        @lcrs = current_user_lcrs.where(id: user.lcr_id).order('name ASC').all
      else
        @lcrs = current_user_lcrs.order('name ASC').all
      end

      @locations = current_user.locations

      @tariffs = Tariff.find_by_user(user_id)
      @cardgroup.fix_when_is_rendering
      render :edit
    end
  end

  def destroy
    @cg.validate_before_destroy
    if @cg.respond_to?(:errors) && @cg.errors.size.to_i > 0
      flash_errors_for(_('Cardgroup_cannot_be_deleted'), @cg)
      redirect_to(action: 'list') && (return false)
    end

    if @cg.destroy_or_hide
      flash[:status] = _('Cardgroup_was_deleted')
      unless @cg.status.blank?
        @cg.status.each do |msg|
          flash[:status] += "<br />* #{msg}"
        end
      end
      redirect_to(action: 'list')
    else
      flash_errors_for(_('Card_was_not_deleted'), @cg)
      redirect_to(action: 'list') && (return false)
    end
  end

  def cards_to_csv
    params[:file].to_s == 'false' ? @file = false : @file = true
    cg = Cardgroup.find(params[:id])
    show_pin = (!(session[:usertype] == 'accountant' && session[:acc_callingcard_pin].to_i == 0) && (cg.owner_id == current_user_id || Confline.get_value('CCShop_hide_pins_for_distributors', 0).to_i.zero?))
    check_user_for_cardgroup(cg)
    if current_user.usertype == 'user'
      cards = cg.cards.where("user_id = #{current_user_id}")
    else
      cards = cg.cards
    end
    sep, dec = current_user.csv_params

    showing_pin = (show_pin == true)
    csv_string = _('Number') + sep
    if showing_pin
      csv_string += _('Pin') + sep
    end

    if can_see_finances?
      csv_string += _('Balance') + sep + _('Sold') + sep
    end
    csv_string += _('First_use') + sep + _('Daily_charge_paid_till')
    csv_body = [csv_string]
    cards.each do |card|
      csv_line = card.to_csv_line(can_see_finances?, showing_pin, dec)
      csv_body << csv_line.join(sep)
    end

    csv_full_string = csv_body.join("\n")
    if @file
      filename = "Cards-#{cg.name}.csv"
      send_data(csv_full_string, type: 'text/csv; charset=utf-8; header=present', filename: filename)
    else
      render text: csv_full_string, layout: false
    end
  end

  def upload_card_image
    path = Actual_Dir + '/public/images/cards/'
    params_card_image = params[:Card_image]
    @cardgroup = Cardgroup.where(id: params[:id]).first
    cardgroup_id = @cardgroup.id
    unless @cardgroup
      flash[:notice] = _('Cardgroup_now_found')
      redirect_to(action: 'show', id: cardgroup_id) && (return false)
    end

    check_user_for_cardgroup(@cardgroup)

    if params_card_image
      @file = params_card_image
      file_size = @file.size
      if file_size > 0
        if file_size < 524288
          @filename = sanitize_filename(@file.original_filename)
          @ext = @filename.split('.').last.downcase
          if @ext == 'jpg' || @ext == 'jpeg' || @ext == 'png' || @ext == 'gif'
            system("rm #{path}#{@cardgroup.image}")
            @filename=(cardgroup_id).to_s + '.' + @ext.to_s
            File.open(Actual_Dir + '/public/images/cards/' + @filename, 'wb') do |file|
              file.write(params_card_image.read)
            end
            @cardgroup.update_attributes(image: @filename)
            flash[:status] = _('Card_image_uploaded')
          else
            flash[:notice] = _('Not_a_picture')
          end
        else
          flash[:notice] = _('Image_to_big_max_size_500kb')
        end
      else
        flash[:notice] = _('Zero_size_file')
      end
    else
      flash[:notice] = _('Select_a_file')
    end
    redirect_to(action: 'show', id: cardgroup_id) && (return false)
  end

  def loss_calls
    @page_title = _('Loss_calls')
    @page_icon = 'call.png'

    @allow_read = !(session[:usertype] == 'accountant' && (session[:acc_callingcard_manage].to_i == 0))
    if @allow_read == false
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    user_id = get_user_id
    change_date

    params_s_cardgroup = params[:s_cardgroup]
    @search_cardgroup = -1
    @search_cardgroup = params_s_cardgroup if params_s_cardgroup

    @cgs = Cardgroup.where("owner_id = '#{user_id}'").order('name Asc')
    # MorLog.my_debug @cgs.size
    cond = ''

    search_cardgroup_local = @search_cardgroup.to_i
    if search_cardgroup_local != -1
      cond += " AND cards.cardgroup_id = '#{search_cardgroup_local}' "
    end

    sql = "SELECT cards.*, cardgroups.price, calls.calldate, calls.dst, calls.user_price FROM cards
    JOIN calls ON (calls.card_id = cards.id)
    JOIN cardgroups ON (cards.cardgroup_id = cardgroups.id)
    WHERE calls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' AND cards.balance < '0' AND cards.owner_id = '#{user_id}' #{cond}
    ORDER BY cards.id , calldate ASC "

    # MorLog.my_debug "_______________________________(sql)______________________________________________"
    # MorLog.my_debug sql
    decimal_zero = 0.to_d
    price = decimal_zero
    card_id = 0
    @cards_calls = Card.find_by_sql(sql)
    @cards_callsv = []
    @c_c = @cards_calls
    @cards_calls = []
    @t_cards = 0
    @t_price = decimal_zero
    @c_c.each do |call|
      call_price = call.price.to_d
      call_user_price = call.user_price.to_d
      call_id = call.id
      if crad_id.to_i != call_id.to_i
        card_id = call_id
        price = decimal_zero
        @t_cards += 1
      end
      price += call_user_price
      if price.to_d >= call_price
        @t_price += call_user_price
        # MorLog.my_debug " Pridejo #{call.id}, nes #{price.to_i} >= #{call.price.to_i}"
        @cards_callsv << call
      end
    end
    # MorLog.my_debug "________________________(masyvas)__________________________________"
    # MorLog.my_debug @cards_callsv.to_yaml
  end

  def gmp_list
    @page_title = _('Ghost_minutes_percents')
    @page_icon = 'view.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Ghost_Minute_Percent_per_Destination_for_Calling_Card_Group'

    @cg = Cardgroup.where(id: params[:id]).first
    cg_id = @cg.id
    unless @cg
      flash[:notice] = _('Cardgroup_now_found')
      redirect_to(action: 'show', id: cg_id) && (return false)
    end

    check_user_for_cardgroup(@cg)

    @gmps = CcGhostminutepercent.where(cardgroup_id: cg_id).all
  end

  def gmp_create
    @cg = Cardgroup.where(id: params[:cg].to_i).first
    cg_id = @cg.id
    unless @cg
      flash[:notice] = _('Cardgroup_now_found')
      redirect_to(action: 'list') && (return false)
    end

    prefix = params[:prefix].to_s.strip
    if prefix.length == 0
      flash[:notice] = _('Empty_prefix')
      redirect_to(action: 'gmp_list', id: cg_id) && (return false)
    end

    percent = params[:percent].to_d
    if percent == 0
      flash[:notice] = _('Bad_percent')
      redirect_to(action: 'gmp_list', id: cg_id) && (return false)
    end

    old_gmp = CcGhostminutepercent.where(cardgroup_id: cg_id, prefix: prefix, percent: percent).first
    if old_gmp
      flash[:notice] = _('Duplicate_record')
      redirect_to(action: 'gmp_list', id: cg_id) && (return false)
    end

    gmp = CcGhostminutepercent.new(cardgroup_id: cg_id, prefix: prefix, percent: percent)
    gmp.save

    flash[:status] = _('Record_created')
    redirect_to action: 'gmp_list', id: cg_id
  end

  def gmp_destroy
    gmp = CcGhostminutepercent.where(id: params[:id].to_i).first
    unless gmp
      flash[:notice] = _('Record_not_found')
      redirect_to(action: 'list') && (return false)
    end

    @cg = gmp.cardgroup
    unless @cg
      flash[:notice] = _('Cardgroup_now_found')
      redirect_to(action: 'list') && (return false)
    end

    gmp.destroy

    flash[:status] = _('Record_deleted')
    redirect_to(action: 'gmp_list', id: @cg.id)
  end

  def gmp_edit
    @page_title = _('Ghost_minutes_percent_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Ghost_Minute_Percent_per_Destination_for_Calling_Card_Group'

    @gmp = CcGhostminutepercent.where(id: params[:id].to_i).first
    unless @gmp
      flash[:notice] = _('Record_not_found')
      redirect_to(action: 'list') && (return false)
    end

    @cg = @gmp.cardgroup
    unless @cg
      flash[:notice] = _('Cardgroup_now_found')
      redirect_to(action: 'list') && (return false)
    end
  end

  def gmp_update
    @gmp = CcGhostminutepercent.where(id: params[:id].to_i).first
    unless @gmp
      flash[:notice] = _('Record_not_found')
      redirect_to(action: 'list') && (return false)
    end

    @cg = @gmp.cardgroup
    cg_id = @cg.id
    unless @cg
      flash[:notice] = _('Cardgroup_now_found')
      redirect_to(action: 'list') && (return false)
    end

    prefix = params[:prefix].to_s.strip
    if prefix.length == 0
      flash[:notice] = _('Empty_prefix')
      redirect_to(action: 'gmp_list', id: cg_id) && (return false)
    end

    percent = params[:percent].to_i
    if percent == 0
      flash[:notice] = _('Bad_percent')
      redirect_to(action: 'gmp_list', id: cg_id) && (return false)
    end

    old_gmp = CcGhostminutepercent.where(cardgroup_id: cg_id, prefix: prefix, percent: percent).first
    if old_gmp
      flash[:notice] = _('Duplicate_record')
      redirect_to(action: 'gmp_list', id: cg_id) && (return false)
    end

    @gmp.update_attributes(prefix: prefix, percent: percent)
    @gmp.save

    flash[:status] = _('Record_updated')
    redirect_to(action: 'gmp_list', id: cg_id)
  end

  def cardgroups_stats
    @page_title = _('Cardgroup_Stats')
    change_date

    params_s_only_first_use = params[:s_only_first_use]
    session_card_groups_stats_options = session[:card_groups_stats_options]
    session_card_groups_stats_options ? @options = session_card_groups_stats_options : @options = {}

    # params[:page]          ? @options[:page] = params[:page].to_i                   : (@options[:page] = 1 if !@options[:page] or params[:page].to_i <= 0)
    params_s_only_first_use ? @options[:s_only_first_use] = params_s_only_first_use.to_i : (params[:clean] || !session_card_groups_stats_options) ? @options[:s_only_first_use] = 0 : @options[:s_only_first_use] = session_card_groups_stats_options[:s_only_first_use]

    user_id = get_user_id

    arr = { joins: 'LEFT JOIN cards ON (cards.cardgroup_id = cardgroups.id)', conditions: ['cardgroups.owner_id = ?', user_id] }
    sum_if = "SUM(IF(cards.first_use IS NOT NULL AND (cards.first_use BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'),"
    if @options[:s_only_first_use].to_i == 1
      arr[:select] = "COUNT(cards.id) as c_id,  #{sum_if}1,0)) as c_siz, #{sum_if}cards.balance,0)) as sum_b"
    else
      arr[:select] = "COUNT(cards.id) as c_id,  #{sum_if}1,0)) as c_siz, SUM(balance) as sum_b"
    end
    @cg_total = Cardgroup.select(arr[:select]).joins(arr[:joins]).where(arr[:conditions]).all
    arr[:select] = "cardgroups.id, cardgroups.name,  " + arr[:select]
    arr[:group] = 'cardgroups.id'
    @cgs = Cardgroup.select(arr[:select]).joins(arr[:joins]).where(arr[:conditions]).group(arr[:group]).all
  end

  def aggregate
    @page_title = _('Aggregate')
    change_date
    user_id = get_user_id

    # 2011.11.18 #3047 reseller doesnt have rights to view callcards/aggregate,
    # cant find any link from menu to link to this page and  acording to ticket
    # he shouldnt. but theres some doubt because code looks like he could
    # 2012.04.04 #5379 apprarently rs pro should be able to see this page if he
    # has cc addon enabled
    # 2012.05.15 me again. seems like any reseller with calling cards addon should
    # have rights to view this page
    if current_user.usertype.include?('reseller') && !calling_cards_active?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    session_aggregate_cards_list_options = session[:aggregate_cards_list_options]
    # if we have some options preset in session we can retreave them if not new options hash is created.
    session_aggregate_cards_list_options ? @options = session_aggregate_cards_list_options : @options = {}

    params_test = params[:test]
    params_csv = params[:csv].to_i
    params_page = params[:page]
    params_order_desc = params[:order_desc]
    params_order_by = params[:order_by]
    params_destination_grouping = params[:destination_grouping]
    params_cardgroup = params[:cardgroup]
    params_prefix = params[:prefix]

    params_page ? @options[:page] = params_page.to_i : (@options[:page] = 1 unless @options[:page])
    params_destination_grouping ? @options[:destination_grouping] = params_destination_grouping.to_i : (@options[:destination_grouping] = 1 unless @options[:destination_grouping])
    params_order_desc ? @options[:order_desc] = params_order_desc.to_i : (@options[:order_desc] = 1 unless @options[:order_desc])
    params_order_by ? @options[:order_by] = params_order_by.to_s : (@options[:order_by] = 'direction' unless @options[:order_by])

    params_cardgroup ? @options[:cardgroup] = params_cardgroup : (@options[:cardgroup] = 'any' unless @options[:cardgroup])
    params_prefix ? @options[:prefix] = params_prefix.gsub(/[^0-9]/, '') : (@options[:prefix] = '' unless @options[:prefix])

    @options[:order] = Call.calls_order_by(params, @options)
    @cardgroups = Cardgroup.includes(:tax).where(owner_id: user_id).order('name ASC')

    @options[:csv] = params_csv
    @options[:from] = session_from_datetime
    @options[:till] = session_till_datetime
    @options[:user_id] = user_id

    if params_csv == 1
      session[:aggregate_cards_list_options] = @options
      settings_owner_id = (['reseller', 'admin'].include?(session[:usertype]) ? session[:user_id] : session[:owner_id])
      @options[:collumn_separator] = Confline.get_csv_separator(settings_owner_id)
      @options[:current_user] = current_user
      filename, data = Call.cardgroup_aggregate(@options.merge(test: params_test))
      filename = load_file_through_database(filename) if Confline.get_value('Load_CSV_From_Remote_Mysql').to_i == 1
      if filename
        filename = archive_file_if_size(filename, 'csv', Confline.get_value('CSV_File_size').to_d)
        if params_test.to_i != 1
          send_data(File.open(filename).read, filename: filename)
        else
          render text: filename.to_s + data.to_s
        end
      else
        flash[:notice] = _('Cannot_Download_CSV_File_From_DB_Server')
        redirect_to(root) && (return false)
      end
    else
      @result_full = Call.cardgroup_aggregate(@options)
      @result = []
      @total_calls = @result_full.size
      # calculate total values of dataset.
      @total = { duration:  0, user_price: 0, provider_price: 0, total_calls: 0, asr: 0, acd: 0, answered_calls: 0, profit: 0, margin: 0, markup: 0 }
      @result_full.each do |row|
        row_provider_price = row.provider_price.to_d
        row_user_price = row.user_price.to_d
        @total[:duration] += row.duration.to_d
        @total[:total_calls] += row.total_calls.to_i
        @total[:answered_calls] += row.answered_calls.to_i
        @total[:user_price] += row_user_price
        @total[:provider_price] += row_provider_price
        @total[:profit] += row_user_price - row_provider_price
      end
      decimal_zero = 0.to_d
      total_answered_calls = @total[:answered_calls].to_d
      @total[:total_calls] == 0 ? @total[:asr] = 0 : @total[:asr] = total_answered_calls.to_d / @total[:total_calls].to_d * 100
      total_answered_calls == decimal_zero ? @total[:acd] = 0 : @total[:acd] = @total[:duration].to_d / total_answered_calls.to_d
      @total[:margin] = ((@total[:user_price] - @total[:provider_price]) / @total[:user_price]) * 100 if @total[:provider_price].to_d != decimal_zero
      @total[:markup] = ((@total[:user_price] / @total[:provider_price]) * 100) - 100 if @total[:provider_price].to_d != decimal_zero

      # fetch required number of items.
      session_items_per_page = session[:items_per_page]
      @result = []
      @total_pages = (@total_calls.to_d / session_items_per_page.to_d).ceil
      @options[:page] = @total_pages if @options[:page] > @total_pages
      start = session_items_per_page * (@options[:page] - 1)
      (start..(start + session_items_per_page) - 1).each do |index|
        result_full = @result_full[index]
        @result << result_full if result_full
      end
      session[:aggregate_cards_list_options] = @options
    end
  end

  private

  def check_user_for_cardgroup(cardgroup)
    cardgroup_owner_id = cardgroup.owner_id
    if session[:usertype].to_s == 'accountant'
      if cardgroup_owner_id != 0 or session[:acc_callingcard_manage].to_i == 0
        dont_be_so_smart
        redirect_to(controller: 'cardgroups', action: 'list') && (return false)
      end
    end

    user_is_not_owner = (cardgroup_owner_id != session[:user_id])
    if session[:usertype].to_s == 'reseller'
      if user_is_not_owner || session[:res_calling_cards].to_i != 2
        MorLog.my_debug('Redirect')
        dont_be_so_smart
        redirect_to(controller: 'cardgroups', action: 'list') && (return false)
        MorLog.my_debug('post_check')
      end
    end

    if session[:usertype].to_s == 'admin'
      if user_is_not_owner
        dont_be_so_smart
        redirect_to(:root) && (return false)
      end
    end
    true
  end

  def get_user_id
    (session[:usertype].to_s == 'accountant') ? 0 : session[:user_id]
  end

  def find_card_group
    @cg = Cardgroup.includes([:tariff, :lcr, :location, :tax]).where(['cardgroups.id=? and cardgroups.hidden = 0',params[:id]]).first
    unless @cg
      flash[:notice] = _('Cardgroup_was_not_found')
      redirect_to(action: 'list') && (return false)
    end
    check_user_for_cardgroup(@cg)
  end

  def allow_add_card_group?
    if !calling_cards_active? && (Cardgroup.where(owner_id: current_user_id).count >= 1)
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to :root
    end
  end

  def nice_date_from_params(options = {})
    if options.size > 0 && options[:year].to_i > 2000
      year = options[:year].to_i
      month = options[:month].to_i    # <= 0 ? 1 :  options[:month].to_i
      if options[:day].to_i < 1
        options[:day] = 1
      else
        unless Date.valid_civil?(year.to_i, month.to_i, options[:day].to_i)
          options[:day] = last_day_of_month(year, month)
        end
      end
      day = options[:day]
      Time.mktime(year.to_i, month, day).to_date.to_s
    else
      Date.now.to_s
    end
  end

  def set_card_groups
    @cardgroups.first.card_count = 10 if @cardgroups.first.card_count > 10
    @cardgroups = [@cardgroups.first]
  end

  def manage_search_options
    @page_select_params = {}
    session[:cardgroup_search_options] ||= {}

    options = {
      's_number' => '',
      's_pin' => '',
      's_balance_max' => '',
      's_balance_min' => '',
      's_active' => '',
      's_sold' => '',
      's_caller_id' => ''
    }
    @options = options.merge!(session[:cardgroup_search_options])

    [:s_number, :s_pin, :s_caller_id, :s_balance_min, :s_balance_max].each do |key|
      @options[key] = params[key] || @options[key] || ''
      params[key] = @options[key].to_s.strip
    end

    @options.merge!(params.slice(*@options.keys))
    session[:cardgroup_search_options] = @options
  end

  def variables_by_cardgroup
    # @cardgroup = Cardgroup.find(:first, :include => [:tariff, :lcr, :location, :tax], :conditions => ["cardgroups.id = ?", params[:id]])
    @cardgroup = Cardgroup.where(['cardgroups.id = ?', params[:id]]).includes([:tariff, :lcr, :location, :tax]).first
    cardgroup_lcr = @cardgroup.lcr
    cardgroup_cards_size = @cardgroup.cards.size.to_i
    @lcr_owner = true if cardgroup_lcr && ((reseller? || admin?) && (cardgroup_lcr.user_id == current_user_id))

    @show_create_buttons = (cc_active? || (cardgroup_cards_size < 10))
    @cards_number = @show_create_buttons ? cardgroup_cards_size : 10
  end

  def set_cardgroups_page
    @page_title = _('Card_groups')
    @help_link = 'http://wiki.kolmisoft.com/index.php/Calling_Card_Groups'
  end
end
