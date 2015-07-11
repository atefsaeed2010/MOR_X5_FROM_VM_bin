# -*- encoding : utf-8 -*-
class PaymentsController < ApplicationController

  require "digest"
  require 'google4r/checkout'

  layout "callc"
  skip_before_filter :verify_authenticity_token, :only => [:paypal_ipn]
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization, :except => [:paypal_ipn, :webmoney_result, :cyberplat_result, :ouroboros_accept, :linkpoint_ipn]
  before_filter :authorize, :except => [:paypal_ipn, :webmoney_result, :cyberplat_result, :ouroboros_accept, :linkpoint_ipn]
  before_filter :check_if_can_see_finances, :only => [:index, :list, :payments_csv, :show, :new, :create, :update, :destroy]
  before_filter :find_user_session, :only => [:paypal, :paypal_pay, :personal_payments, :ouroboros, :ouroboros_pay, :webmoney, :webmoney_pay, :cyberplat, :cyberplat_pay, :linkpoint_pay, :confirm_payment]
  before_filter :find_payment, :only => [:confirm_payment, :change_description]
  before_filter :provider_billing_check, :only => [:manual_payment, :manual_payment_status, :manual_payment_finish], :if => lambda { params.key? :provider_id }
  before_filter :limit_payment, :only => [ :paypal, :paypal_pay, :webmoney, :webmoney_pay, :linkpoint, :linkpoint_pay, :cyberplat, :cyberplat_pay, :ouroboros, :ouroboros_pay ], :if => lambda { not payment_gateway_active? }

  @@payments_view = [:list, :payments_csv]
  @@payments_edit = [:manual_payment, :manual_payment_status]
  before_filter(:only => @@payments_view+@@payments_edit) { |c|
    allow_read, allow_edit = c.check_read_write_permission(@@payments_view, @@payments_edit, {:role => "accountant", :right => :acc_payments_manage, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  def index
    redirect_to :action => :list and return false
  end

  def list
    @page_title = _('Payments')
    @page_icon = 'creditcards.png'

    change_date

    @clear = 0
    session[:payments_list_c] ? @options = session[:payments_list_c] : @options = {}
    [:s_transaction, :s_completed, :s_username, :s_first_name, :s_last_name, :s_paymenttype, :s_amount_min, :s_amount_max, :s_currency, :s_number, :s_pin].each { |key|
      if params[:clear].to_i == 1
        @options[key] = ""
        change_date_to_present
        @clear = 0
      elsif params[key]
          @options[key] = params[key].to_s
          @clear = 1
      else
          @options[key] = "" if !@options[key]
      end
    }

    hide_uncompleted_payment = Confline.get_value('Hide_non_completed_payments_for_user', 0).to_i

    cond = ['date_added BETWEEN ? AND ?']
    cond << 'payments.owner_id = ?'
    cond_param = [q(session_from_datetime), q(session_till_datetime), correct_owner_id]

    if hide_uncompleted_payment == 1
      cond << " (payments.pending_reason != 'Unnotified payment' or payments.pending_reason is null)"
    end

    ['username', 'first_name', 'last_name'].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s+'%', "users.#{col} LIKE ?", cond, cond_param) }

    ['number', 'pin'].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s+'%', "cards.#{col} LIKE ?", cond, cond_param) }

    ['paymenttype', 'currency', 'completed'].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s, "payments.#{col} = ?", cond, cond_param) }

    ['transaction'].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s+"%", "payments.transaction_id LIKE ?", cond, cond_param) }

    cond << "amount >= '#{current_user.to_system_currency(q(@options[:s_amount_min]))}' " if !@options[:s_amount_min].blank?
    cond << "amount <= '#{current_user.to_system_currency(q(@options[:s_amount_max]))}' " if !@options[:s_amount_max].blank?
    cond << "( users.hidden = 0 OR payments.card != 0 OR payments.user_id = -1 )"

    @payments = Payment.select("payments.*, payments.user_id as 'user_id', payments.first_name as 'payer_first_name', payments.last_name as 'payer_last_name', users.username, users.first_name, users.last_name, cards.number, cards.pin, cards.id as card_id",).where([cond.join(" AND ")] + cond_param).joins("left join users on (payments.user_id = users.id and payments.card = '0') left join cards on (payments.user_id = cards.id and payments.card != '0')   left join cardgroups on (cards.cardgroup_id = cardgroups.id)")

    @search = 1

    sql = "SELECT DISTINCT SUBSTRING(date_added,1,10) as 'pdate' FROM payments ORDER BY SUBSTRING(date_added,1,10) ASC"
    @payment_dates = ActiveRecord::Base.connection.select_all(sql)

    sql = "SELECT DISTINCT paymenttype as 'ptype' FROM payments ORDER BY paymenttype ASC"
    @payment_types = ActiveRecord::Base.connection.select_all(sql)

    sql = "SELECT DISTINCT currency as 'pcurr' FROM payments ORDER BY currency ASC"
    @payment_currencies = ActiveRecord::Base.connection.select_all(sql)

    @page = 1
    @page = params[:page].to_i if params[:page] and params[:page].to_i > 0

    @total_pages = (@payments.size.to_d / session[:items_per_page].to_d).ceil
    @page = @total_pages if params[:page].to_i > @total_pages
    @all_payments = @payments
    @payments= []

    iend = ((session[:items_per_page].to_i * @page) - 1)
    iend = @all_payments.size - 1 if iend > (@all_payments.size - 1)
    for i in ((@page - 1) * session[:items_per_page].to_i)..iend
      @payments << @all_payments[i] if !@all_payments[i].blank?
    end

    @total_amaunt= 0.to_d
    @total_amaunt_completed = 0.to_d
    @total_fee= 0.to_d
    @total_fee_completed= 0.to_d
    @total_amaunt_with_vat= 0.to_d
    @total_amaunt_with_vat_completed= 0.to_d

    for payment in @all_payments
      pa = payment.payment_amount
      #      if payment.paymenttype == "paypal" or payment.paymenttype == "manual"
      #        user = payment.user
      #        if user
      #          #tax = user.get_tax
      #          pa = payment.payment_amount if payment.paymenttype == "manual"
      #          #pa = tax.apply_tax(payment.gross) if payment.paymenttype == "paypal"
      #          pa = payment.payment_amount if payment.paymenttype == "paypal"
      #        end
      #      end
      #      pa = payment.gross if ["webmoney", "cyberplat",  "linkpoint", "voucher", "ouroboros", "subscription"].include?(payment.paymenttype.to_s)
      #      pa = payment.amount if payment.paymenttype == "invoice"
      @total_amaunt += get_price_exchange(pa, payment.currency)
      @total_fee += get_price_exchange(payment.fee, payment.currency)
      digits = (payment.paymenttype == "invoice" and payment.invoice) ? nice_invoice_number_digits(payment.invoice.invoice_type) : 0
      awv = payment.payment_amount_with_vat(digits)
      @total_amaunt_with_vat += get_price_exchange(awv, payment.currency)

      #Ticket 3421
      if payment.completed.to_i != 0
        @total_amaunt_completed += get_price_exchange(pa, payment.currency)
        @total_fee_completed += get_price_exchange(payment.fee, payment.currency)
        @total_amaunt_with_vat_completed += get_price_exchange(awv, payment.currency)
      end
    end

    session[:payments_list_c] = @options
    store_location
  end

  def payments_csv
    change_date

    session[:payments_list_c] ? @options = session[:payments_list_c] : @options = {}
    [:s_completed, :s_username, :s_first_name, :s_last_name, :s_paymenttype, :s_amount_min, :s_amount_max, :s_currency, :s_number, :s_pin].each { |key|
      params[key] ? @options[key] = params[key].to_s : (@options[key] = "" if !@options[key])
    }

    cond = ["date_added BETWEEN ? AND ?"]
    cond << "payments.owner_id = ?"
    cond_param = [q(session_from_datetime), q(session_till_datetime), correct_owner_id]

    ["username", "first_name", "last_name"].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s+"%", "users.#{col} LIKE ?", cond, cond_param) }

    ["number", "pin"].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s+"%", "cards.#{col} LIKE ?", cond, cond_param) }

    ["paymenttype", "currency", "completed", "description"].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".intern].to_s, "payments.#{col} = ?", cond, cond_param) }

    cond << "amount >= '#{q(@options[:s_amount_min])}' " if !@options[:s_amount_min].blank?
    cond << "amount <= '#{q(@options[:s_amount_max])}' " if !@options[:s_amount_max].blank?

    payments = Payment.select("payments.*, payments.user_id as 'user_id', users.username, users.first_name, users.last_name, cards.number, cards.pin, cards.id as card_id").
                       joins("left join users on (payments.user_id = users.id and payments.card = '0') left join cards on (payments.user_id = cards.id and payments.card != '0') left join cardgroups on (cards.cardgroup_id = cardgroups.id)").
                       where([cond.join(" AND ")] + cond_param)

    sep = Confline.get_value("CSV_Separator", 0).to_s
    dec = Confline.get_value("CSV_Decimal", 0).to_s

    csv_string = "#{_('User')}/#{_('Card')}#{sep}#{_('Date')}#{sep}#{_('Confirm_date')}#{sep}#{_('Type')}#{sep}#{_('Amount')}#{sep}#{_('Fee')}#{sep}#{_('Amount_with_VAT')}#{sep}#{_('Currency')}#{sep}#{_('Completed')}*#{sep}#{_('Description')}\n"

    total_amaunt= 0.to_d
    total_fee= 0.to_d
    total_amaunt_with_vat= 0.to_d

    for payment in payments

      if payment.card == 0
        name = nice_user(payment)
      else
        name = payment.number
      end

      tag = ""

      if payment.paymenttype.to_s == "voucher" and voucher = payment.voucher
        tag = " (" + voucher.tag.to_s + ")"
      end

      pa = payment.amount
      user = payment.user
      if (payment.paymenttype == "paypal" or payment.paymenttype == "manual") and user
        tax = user.get_tax
        pa = payment.payment_amount if payment.paymenttype == "manual"
        pa = tax.apply_tax(payment.amount) if payment.paymenttype == "paypal"
      end
      pa = payment.gross if payment.paymenttype == "webmoney" or payment.paymenttype == "cyberplat"

      digits = (payment.paymenttype == "invoice" and payment.invoice) ? nice_invoice_number_digits(payment.invoice.invoice_type) : 0
      awv = payment.payment_amount_with_vat(digits)

      completed = _('_Yes')
      if  payment.completed.to_i == 0
        completed = _('_No')
        completed += " (" + payment.pending_reason + ")" if payment.pending_reason
      end

      csv_string += "#{name.to_s}#{sep}#{nice_date_time payment.date_added}#{sep}#{nice_date_time payment.shipped_at}#{sep}#{payment.paymenttype.capitalize.to_s + tag.to_s}#{sep}#{pa.to_s.gsub(".", dec).to_s}#{sep}#{payment.fee.to_s.gsub(".", dec).to_s}#{sep}#{awv.to_s.gsub(".", dec).to_s}#{sep}#{payment.currency}#{sep}#{completed}#{sep}#{payment.description}\n"
      total_amaunt += get_price_exchange(pa, payment.currency)
      total_fee += get_price_exchange(payment.fee, payment.currency)
      total_amaunt_with_vat += get_price_exchange(awv, payment.currency)
    end

    dc = current_user.currency.name
    csv_string += "#{_('Total')}#{sep}#{sep}#{sep}#{sep}#{total_amaunt.to_s.gsub(".", dec).to_s}(#{dc})#{sep}#{total_fee.to_s.gsub(".", dec).to_s}(#{dc})#{sep}#{sep}#{total_amaunt_with_vat.to_s.gsub(".", dec).to_s}(#{dc })#{sep}#{sep}#{sep}\n"
    filename = "Payments.csv"
    session[:payments_list_c] = @options
    if params[:test].to_i == 1
      render :text => "Payments_csv_is_ok\n\n"+csv_string
    else
      send_data(csv_string, :type => 'text/csv; charset=utf-8; header=present', :filename => filename)
    end

  end

  ########## Linkpoint ##########################
  # added by A.Mazunin 16.04.2008               #
  # LinkpointCentral Payment System Integration #
  ###############################################

  def linkpoint
    @enabled = Confline.get_value("Linkpoint_Enabled", 0).to_i
    unless @enabled == 1
      render :text => "" and return false
    end
    @page_title = _('LinkPoint')
    @page_icon = "money.png"
    @currency = Confline.get_value("Linkpoint_Default_Currency")

  end

  def linkpoint_pay
    #@user in before filter
    unless Confline.get_value("Linkpoint_Enabled").to_i == 1
      render :text => "" and return false
    end

    Action.add_error(session[:user_id], "Linkpoint_user_URL_mismatches_WebURL", {:data2 => Web_URL + Web_Dir, :data3 => request.protocol + request.host}) unless check_request_url(request)
    @page_title = _('LinkPoint')
    @page_icon = "money.png"
    @enabled = Confline.get_value("Linkpoint_Enabled", 0).to_i
    @linkpoint_ipn = Web_URL + Web_Dir + "/payments/linkpoint_ipn"
    @amount = Confline.get_value("Linkpoint_Default_Amount").to_d
    @amount = params[:amount].to_d if params[:amount]
    lp_min_amount = Confline.get_value("Linkpoint_Min_Amount").to_d
    @amount = lp_min_amount if @amount < lp_min_amount

    @amount_with_vat = @user.get_tax.count_tax_amount(@amount) + @amount

    @currency = Confline.get_value("Linkpoint_Default_Currency")
    @payment = Payment.unnotified_payment('linkpoint') do |p|
      p.amount = @amount_with_vat
      p.currency = @currency
      p.gross = @amount
      p.tax = @amount_with_vat - @amount
    end
  end

  def linkpoint_ipn
    unless Confline.get_value('Linkpoint_Enabled').to_i == 1
      render :text => '' and return false
    end
    my_debug('linkpoint success accessed')
    @page_title = _('LinkPoint_Result')
    @page_icon = 'money.png'
    @success = false
    if request.raw_post
      notify = Linkpoint::Notification.new(request.raw_post)
      @payment = Payment.where(["id = ?", notify.transaction_id]).first
      @test = Confline.get_value('Linkpoint_Test').to_i
      if request.protocol == "https://" or Confline.get_value('Linkpoint_Allow_HTTP').to_i == 1
        @payment, @user, @reason, @success = Payment.linkpoint_ipn(@payment, @test, notify)
      else
        @reason = _('Unsecure_Transaction')
        MorLog.my_debug('Linkpoint: Unsecure access attempt. Suspected hack.')
        MorLog.my_debug("Payment:   '#{request.protocol}'")
        MorLog.my_debug("Expected:  'https://'")
      end
    else
      @reason = _('Empty_Response')
      MorLog.my_debug('Linkpoint: Empty response.')
    end
  end

  ############ PAYPAL ############

  def paypal
    #@user in before filter
    @page_title = _('PayPal')
    @page_icon = "money.png"

    if session[:paypal_enabled].to_i == 0
      dont_be_so_smart
      redirect_to :root and return false
    end

    @pp_min_amount = Confline.get_value("PayPal_Min_Amount", @user.owner_id)
    @pp_max_amount = Confline.get_value("PayPal_Max_Amount", @user.owner_id)

    @currency = Confline.get_value("Paypal_Default_Currency", @user.owner_id)
  end

  def paypal_pay
    #@user in before filter
    @page_title = _('PayPal')
    @page_icon = "money.png"

    if session[:paypal_enabled].to_i == 0
      dont_be_so_smart
      redirect_to :root and return false
    end
    #ticket 3698

    owner_id = @user.owner_id

    custom_redirect = Confline.get_value('PayPal_Custom_redirect', owner_id).to_i
    custom_redirect_successful_payment = Confline.get_value('Paypal_return_url', owner_id)
    custom_redirect_canceled_payment = Confline.get_value('Paypal_cancel_url', owner_id)

    if custom_redirect and custom_redirect.to_i == 1
      @paypal_return_url = session[:url] + "/" + custom_redirect_successful_payment.to_s
      @paypal_cancel_url = session[:url] + "/" + custom_redirect_canceled_payment.to_s
    else
      @paypal_return_url = session[:url] + Web_Dir + "/payments/personal_payments"
      @paypal_cancel_url = session[:url] + Web_Dir + "/callc/main"
    end

    @paypal_ipn_url = session[:url] + Web_Dir + "/payments/paypal_ipn"

    @amount = Confline.get_value("PayPal_Default_Amount", owner_id).to_d
    @amount = params[:amount].to_d if params[:amount]

    pp_min_amount = Confline.get_value("PayPal_Min_Amount", owner_id).to_d
    pp_max_amount = Confline.get_value("PayPal_Max_Amount", owner_id).to_d

    @amount = pp_min_amount if pp_min_amount > 0.0 && @amount < pp_min_amount
    @amount = pp_max_amount if pp_max_amount > 0.0 && @amount > pp_max_amount

    @amount_with_vat = @user.get_tax.count_tax_amount(@amount) + @amount

    #testing
    if Confline.get_value("PayPal_Test", owner_id).to_i == 1
      @paypal_url = Paypal::Notification.test_ipn_url
    else
      @paypal_url = Paypal::Notification.ipn_url
    end

    @currency = Confline.get_value("Paypal_Default_Currency", owner_id)

    @payment = Payment.unnotified_payment('paypal') do |p|
      p.gross = @amount
      p.amount = @amount_with_vat
      p.email = Confline.get_value("PayPal_Email", owner_id)
      p.currency = @currency.to_s
    end
  end

  def paypal_ipn
    MorLog.my_debug('paypal_ipn accessed', true)

    notify = Paypal::Notification.new(request.raw_post)
    if notify.reversed?
      payment = Payment.where(["id = ?", notify.item_id]).first
    else
      payment = Payment.where(["id = ? AND completed = 0", notify.item_id]).first
    end
    if payment
      user = payment.user
      if user
        if Confline.get_value('PayPal_Enabled', user.owner_id).to_i == 0
          dont_be_so_smart
          redirect_to :root and return false
        end
        @payment, @user, @paypal_url = Payment.paypal_ipn(notify, payment, user)
      else
        MorLog.my_debug('transaction NOT completed (User NOT found)', true)
        dont_be_so_smart
        redirect_to :root and return false
      end
    else
      MorLog.my_debug('transaction NOT completed (Payment NOT found)')
      dont_be_so_smart
      redirect_to :root and return false
    end
    render :nothing => true
  end

  # before_filter
  #   find_user_session
  #   find_payment
  def confirm_payment
    user = @payment.user
    unless user.owner_id == @user.id || @user.is_admin?
      flash[:notice] = _("Not_authorized_to_confirm_payment")
      redirect_to :root and return false
    end


    payment_curency = @payment.currency
    payment_fee = @payment.fee
    exchange_rate = Currency.count_exchange_rate(payment_curency, Currency.first.name)
    current_user_exchange_rate = User.current.currency.exchange_rate.to_d

    # round to cents rounds to floor.
    user.balance += round_to_cents(@payment.payment_amount * exchange_rate.to_d * current_user_exchange_rate)
    if @payment.paymenttype == "paypal" and payment_fee.to_d != 0.0 and Confline.get_value("PayPal_User_Pays_Transfer_Fee", user.owner_id).to_i == 1
      # sprintf rounds to ceiling.
      user.balance -= sprintf("%.2f", payment_fee * exchange_rate * current_user_exchange_rate).to_d
      fee_payment = @payment.dup
      fee_payment.update_attributes(paymenttype: 'paypal_fee',
                                    fee: 0,
                                    tax: 0,
                                    completed: 1,
                                    pending_reason: 'Completed',
                                    amount: payment_fee * -1,
                                    gross: payment_fee * -1,
                                    shipped_at: Time.now)
      fee_payment.save
      Action.add_action(user.id, "PayPal", "User paid paypal fee: #{payment_fee} #{payment_curency}")
      user.save
    end

    Action.add_action_hash(user.id,
                           {:action => "payment_confirmation",
                            :data => "Payment confirmed",
                            :data2 => "payment id: #{@payment.id}",
                            :data3 => "#{@payment.amount} #{payment_curency}"
                           })

    user.save
    Application.reset_user_warning_email_sent_status(user)
    MorLog.my_debug('transaction succesfully confirmed')

    @payment.update_attributes({:completed => 1, :pending_reason => "Completed", :shipped_at => Time.now})
    flash[:status] = _('Payment_confirmed')


    redirect_back_or_default("/payments/list")
  end

  def fix_paypal_payments
    change_date
    @payments = Payment.where(["paymenttype = 'paypal' AND date_added BETWEEN ? AND ? ", session_from_datetime, session_till_datetime])

    MorLog.my_debug("DELETE FROM payments WHERE id IN (#{@payments.map { |p| p.id }.join(",")});")

    insert = []
    insert_header = "INSERT INTO payments (`id`, `tax`, `completed`, `paymenttype`, `shipped_at`, `hash`, `pending_reason`, `amount`, `transaction_id`, `card`, `owner_id`, `fee`, `gross`, `user_id`, `vat_percent`, `last_name`, `bill_nr`, `currency`, `date_added`, `payer_status`, `payer_email`, `residence_country`, `email`, `first_name`)"
    @payments.each { |payment|
      insert << "(#{payment.id},#{payment.tax},#{payment.completed},'#{payment.paymenttype}','#{payment.shipped_at.to_s(:db) if payment.shipped_at}','#{payment.payment_hash}','#{payment.pending_reason}',#{payment.amount},'#{payment.transaction_id}',#{payment.card},#{payment.owner_id},#{payment.fee},#{payment.gross},#{payment.user_id},#{payment.vat_percent},'#{payment.last_name}',#{payment.bill_nr},'#{payment.currency}','#{payment.date_added.to_s(:db) if payment.date_added}', '#{payment.payer_status}','#{payment.payer_email}','#{payment.residence_country}','#{payment.email}','#{payment.first_name}')".gsub("''", "NULL").gsub(",,", ",NULL,")
      unless payment.gross.to_d == 0.0
        payment.amount = payment.gross.to_d
      end
      payment.gross = payment.amount.to_d - payment.tax.to_d
      payment.save
      if insert.size > 1000
        MorLog.my_debug("#{insert_header} VALUES#{insert.join(",")};")
        insert = []
      end
    }
    MorLog.my_debug("#{insert_header} VALUES#{insert.join(",")};")

    flash[:notice] = _("Payments_converted")
    redirect_to :controller => "callc", :action => "global_settings" and return false
  end

  ########### PERSONAL ##########

  def personal_payments
    #@user in before filter
    unless (user? or reseller?)
      dont_be_so_smart
      redirect_to :root and return false
    end
    @page_title = _('Payments')
    @page_icon = "creditcards.png"
    @payments = @user.payments
  end

  #--------------- manual payments ------------

  def manual_payment
    @page_title = _('Add_manual_payment')
    @page_icon = "add.png"
    @users = []

    owner_id = (accountant? ? 0 : current_user.id)

    params.delete(:user_id) if params[:user_id] and params[:user_id].to_i == 0

    if params[:user_id].present?
      user = User.includes(:tax).where(["owner_id = ? AND users.id = ?", owner_id, params[:user_id]]).first
      unless (user.try :is_user? or user.try :is_reseller?)
        flash[:notice] = _('User_was_not_found')
        redirect_to :root and return false
      end
      @users = [user].compact
    else
      if params[:provider_id]
        @provider = current_user.providers.where(["providers.id = ?", params[:provider_id]]).first
        unless @provider
          flash[:notice] = _('Provider_was_not_found')
          redirect_to :root and return false
        end

      else

        @user = nil
        @users = User.where(["usertype not in ('admin','accountant') AND hidden = 0 AND owner_id = ?", owner_id]).order("first_name ASC")

        if !@users or @users.size == 0
          flash[:notice] = _('No_users_to_make_payments')
          redirect_to :controller => :payments, :action => :list and return false
        end
      end
    end
    @currs = Currency.where(["active = '1'"]).all
  end

  def manual_payment_status
    @page_title = _('Add_manual_payment')
    @page_icon = "add.png"

    if params[:provider_id]
      @provider = current_user.providers.where(["providers.id = ?", params[:provider_id]]).first
      unless @provider
        flash[:notice] = _('Provider_was_not_found')
        redirect_to :root and return false
      end

      user = @provider.device.user if @provider.device and @provider.device.user
      if !params[:amount].blank?
        @amount =  params[:amount].to_d
        @am_typ = "ammount"
        @real_amount = user ?  user.get_tax.apply_tax(@amount) : @amount
      else
        @am_typ = "amount_with_tax"
        @real_amount = params[:amount_with_tax].to_d #if !params[:amount_with_tax].blank?
        @amount  = user ?  user.get_tax.count_amount_without_tax(@real_amount) : @real_amount
      end

    else
      @user = User.includes(:tax).where(["users.id = ? AND owner_id = ?" ,params[:s_user_id], correct_owner_id]).first
      unless @user
        Action.add_action(session[:user_id], "error", "User: #{params[:s_user_id]} was not found") if session[:user_id].to_i != 0
        dont_be_so_smart
        redirect_to :root and return false
      end
      if !params[:amount].blank?
        @amount =  params[:amount].to_d
        @am_typ = "ammount"
        @real_amount = @user.get_tax.apply_tax(@amount)
      else
        @am_typ = "amount_with_tax"
        @real_amount = params[:amount_with_tax].to_d #if !params[:amount_with_tax].blank?
        @amount  = @user.get_tax.count_amount_without_tax(@real_amount)
      end
    end

    @curr = params[:p_currency]
    @curr_amount =  @amount.to_d
    @curr_real_amount =  @real_amount.to_d
    @description = params[:description]
    @exchange_rate = count_exchange_rate(current_user.currency.name, @curr)
    @amount = @amount.to_d /  @exchange_rate.to_d
    @real_amount = @real_amount.to_d /  @exchange_rate.to_d
    if @amount.to_d == 0.to_d
      flash[:notice] = _('Please_add_correct_amount')
      redirect_to :action => 'manual_payment', s_user: params[:s_user], s_user_id: params[:s_user_id]
    end
  end



  def manual_payment_finish
    if params[:provider_id]

      # manual payment for provider

      provider = current_user.providers.where(["providers.id = ?", params[:provider_id]]).first
      unless provider
        # Action.add_action(session[:user_id], "error", "User: #{params[:provider_id]} was not found") if session[:user_id].to_i != 0
        dont_be_so_smart
        redirect_to :root and return false
      end

      Payment.manual_payment_finish_for_provider(provider, params, current_user)

      flash[:status] = _('Payment_added')
    else

      # manual payment for user

      user = User.includes(:tax).where(["users.id = ?", params[:user]]).first
      unless user
        Action.add_action(session[:user_id], 'error', "User: #{params[:user]} was not found") if session[:user_id].to_i != 0
        dont_be_so_smart
        redirect_to :root and return false
      end

      amount = params[:amount].to_d
      real_amount = params[:real_amount].to_d
      currency = params[:p_currency]
      exchange_rate = count_exchange_rate(current_user.currency.name, currency)

      curr_amount =  amount / exchange_rate.to_d
      curr_real_amount =  real_amount / exchange_rate.to_d

      # logger.fatal "#{Time.now}  -  Manual Payment TRY TO ADD - User:#{user.id}; balance:#{user.balance}; amount_to_add:#{curr_amount}"

      user.balance +=  curr_amount
      if user.save
        Payment.manual_payment_finish_for_user(user, amount, real_amount, currency, exchange_rate, curr_amount,
                                               curr_real_amount, params, current_user, session)

        flash[:status] = _('Payment_added')
      else
        # logger.fatal "#{Time.now}  -  Manual Payment User NOT saved - User:#{user.id}; balance:#{user.balance}; amount_to_add:#{curr_amount}"
        flash_errors_for(_('Payment_failed'), user)
      end
    end

    redirect_to :action => 'list'
  end


  def delete_payment
    paym = Payment.where(["id = ?", params[:id]]).first
    unless paym
      flash[:notice] = _('Payment_was_not_found')
      redirect_to :action => 'list' and return false
    end

    if not ["manual", "credit note"].include? paym.paymenttype
      flash[:notice] = _('Only_manual_or_credit_note_payments_can_be_deleted')
      redirect_to :action => 'list' and return false
    end

    current_user_id = current_user.id.to_i
    if paym.owner_id != current_user_id
      flash[:notice] = _('Forbidden_to_delete_payments')
      dont_be_so_smart
      redirect_to :action => 'list' and return false
    end

    user = User.includes(:tax).where(["users.id = ?", paym.user_id]).first
    if user and user.class == User
      real_amount = user.get_tax.count_amount_without_tax(paym.amount) / Currency::count_exchange_rate(current_user.currency.name, paym.currency)
      user.balance -= real_amount
      user.save
    end

    paym.destroy
    if paym.paymenttype == "credit note"
      paym.destroy_credit_note
    end

    flash[:notice] = _('Payment_deleted')
    redirect_to :action => 'list'
  end

  ########### WebMoney #########

  def webmoney
    #@user in before filter
    @page_title = _('WebMoney')
    @page_icon = "money.png"
    @enabled = Confline.get_value("WebMoney_Enabled", @user.owner_id).to_i
    @currency = Confline.get_value("WebMoney_Default_Currency", @user.owner_id)
  end

=begin rdoc

=end

  def webmoney_pay
    #@user in before filter
    @page_title = _('WebMoney')
    @page_icon = "money.png"
    @enabled = Confline.get_value("WebMoney_Enabled", @user.owner_id).to_i
    if @enabled == 1

      @webmoney_result_url = Web_URL + Web_Dir + "/payments/webmoney_result"
      @webmoney_fail_url = Web_URL + Web_Dir + "/payments/webmoney_fail"
      @webmoney_success_url = Web_URL + Web_Dir + "/payments/webmoney_success"

      #@user = User.find(session[:user_id])
      @user_id = session[:user_id]


      @amount = Confline.get_value("WebMoney_Default_Amount", @user.owner_id).to_d
      @amount = params[:amount].to_d if params[:amount]

      wm_min_amount = Confline.get_value("WebMoney_Min_Amount", @user.owner_id).to_d

      @amount = wm_min_amount if @amount < wm_min_amount
      @test = Confline.get_value('WebMoney_Test', @user.owner_id)
      @test_mode = Confline.get_value('WebMoney_SIM_MODE', @user.owner_id)

      @amount_with_vat = @user.get_tax.apply_tax(@amount)
      @currency = confline('WebMoney_Default_Currency')
      @description = session[:company] + " balance update"

      @payment = Payment.unnotified_payment('webmoney') do |p|
        p.amount = @amount_with_vat
        p.currency = Confline.get_value('WebMoney_Default_Currency', @user.owner_id)
        p.gross = @amount
        p.tax = @amount_with_vat - @amount
      end
      @payment_id = @payment.id
    end

  end

  def webmoney_result

    my_debug ""
    my_debug "===== Webmoney result reached ====="
    my_debug params.to_yaml

    #@user = User.find(params[:user])
    @enabled = Confline.get_value("WebMoney_Enabled", 0).to_i
    @test = Confline.get_value('WebMoney_Test', 0).to_i
    @skip_prerequest = Confline.get_value('Webmoney_skip_prerequest', 0).to_i
    if  params[:LMI_PREREQUEST].to_i == 1 && @enabled == 1
      @payment = Payment.find(params[:LMI_PAYMENT_NO])
      if @payment
        if @payment.amount.to_d == params[:LMI_PAYMENT_AMOUNT].to_d
          if params[:LMI_PAYEE_PURSE].to_s == confline("WebMoney_Purse").to_s
            @payment.pending_reason = 'Notified payment'
            @payment.save
            @view_var = "YES"
            render(:layout => false) and return false
          else
            @viev_var = "Wrong purse."
          end
        else
          @view_var = "Amount mismach."
        end
      else
        @view_var = "Payment not found."
      end

    else
      @payment = Payment.where("id = #{params[:LMI_PAYMENT_NO].to_i}").first
      if @payment
        if @payment.pending_reason.to_s == 'Notified payment' or @skip_prerequest == 1
          if @payment.amount.to_d == params[:LMI_PAYMENT_AMOUNT].to_d
            if params[:LMI_MODE].to_i == confline('WebMoney_Test').to_i
              if params[:LMI_PAYEE_PURSE].to_s == confline('WebMoney_Purse').to_s
                @hash_str = ''
                @hash_str += params[:LMI_PAYEE_PURSE].to_s
                @hash_str += params[:LMI_PAYMENT_AMOUNT].to_s
                @hash_str += params[:LMI_PAYMENT_NO].to_s
                @hash_str += params[:LMI_MODE].to_s
                @hash_str += params[:LMI_SYS_INVS_NO].to_s
                @hash_str += params[:LMI_SYS_TRANS_NO].to_s
                @hash_str += params[:LMI_SYS_TRANS_DATE].to_s
                #                   If Server does not using SSL, Secret Key is not in request,
                #                   so we need to store it in database
                #                   Fixed by A.Mazunin
                #                  if params[:LMI_SECRET_KEY].to_s==''
                #                    @hash_str += confline('WebMoney_Purse').to_s
                #                  else
                #                    @hash_str +=params[:LMI_SECRET_KEY].to_s
                #                  end
                secret_key = Confline.get_value("WebMoney_Secret_key").to_s
                if secret_key and secret_key.length>0
                  @hash_str+= secret_key
                end

                @hash_str += params[:LMI_PAYER_PURSE].to_s
                @hash_str += params[:LMI_PAYER_WM].to_s
                @hash = Digest::MD5.hexdigest(@hash_str).to_s.upcase
                if @hash == params[:LMI_HASH].to_s
                  @payment.completed = 1
                  @payment.transaction_id = params[:LMI_SYS_TRANS_NO]
                  @payment.shipped_at = Time.now
                  @payment.payer_email = params[:LMI_PAYER_PURSE]
                  @payment.payment_hash = params[:LMI_HASH]
                  @payment.bill_nr = params[:LMI_SYS_INVS_NO]
                  @payment.pending_reason = ''
                  @payment.save
                  @user = User.find(params[:user])
                  #@user.balance += params[:gross].to_d
                  @user.balance += params[:gross].to_d*Currency.count_exchange_rate(@payment.currency, @user.currency).to_d
                  @user.save
                  Application.reset_user_warning_email_sent_status(@user)
                else
                  MorLog.my_debug('Hash mismatch')
                  MorLog.my_debug('    System hash:' + @hash)
                  MorLog.my_debug('    WM     hash:' + params[:LMI_HASH].to_s)
                end
              else
                MorLog.my_debug('Payment notification : Merchant purse missmach')
                MorLog.my_debug('   SYSTEM:' + confline('WebMoney_Purse'))
                MorLog.my_debug('   WM    :' + params[:LMI_PAYEE_PURSE])
              end
            else
              MorLog.my_debug('Payment notification : Mode missmach')
              MorLog.my_debug('   SYSTEM:' + confline('WebMoney_Test'))
              MorLog.my_debug('   WM    :' + params[:LMI_MODE].to_s)
              MorLog.my_debug(params.to_yaml) if params
              MorLog.my_debug('-------------------------------------')
            end
          else
            MorLog.my_debug('Payment notification : payment amount missmach')
            MorLog.my_debug('   SYSTEM :' + @payment.amount.to_s)
            MorLog.my_debug('   WM     :' + params[:LMI_PAYMENT_AMOUNT].to_s)
          end
        else
          MorLog.my_debug('Payment notification : Payment was not prerequested')
        end
      else
        MorLog.my_debug('Payment notification : Payment was not found')
      end
      render :nothing => true and return false
    end
  end

  def webmoney_success

    MorLog.my_debug ""
    MorLog.my_debug "===== Webmoney success reached ====="
    MorLog.my_debug params.to_yaml

    if params[:LMI_PAYMENT_NO].to_i > 0
      MorLog.my_debug "payment_id received"
      @payment = Payment.where(["id = ?", params[:LMI_PAYMENT_NO]]).first
      @user = User.find(session[:user_id])
      @amount = @payment.gross
    else
      MorLog.my_debug('Params in webmoney_success action')
      MorLog.my_debug(params.to_yaml) if params
      MorLog.my_debug('-------------------------------------')
      MorLog.my_debug "payment_id not received"
      redirect_to :root and return false

    end

  end

  def webmoney_fail
    if params[:LMI_PAYMENT_NO].to_i > 0 and @payment = Payment.where(["id =?", params[:LMI_PAYMENT_NO].to_i]).first
      @payment.destroy
    end
  end

  ################# Cyberplat ####################################################

  def cyberplat
    # @user in before filter
    @page_title = _('Cyberplat')
    @page_icon = "money.png"
    @enabled = Confline.get_value("Cyberplat_Enabled", @user.owner_id).to_i
    @user_enabled = @user.cyberplat_active.to_i
    @currencies = Currency.get_active
    @disabled_message = Confline.get_value2("Cyberplat_Disabled_Info", @user.owner_id)
  end

  def cyberplat_pay
    # @user in before filter
    if !File.exist?("#{Actual_Dir}/lib/cyberplat/checker.ini")
      flash[:notice] = _("Cyberplat_is_not_configured")
      Action.add_error(session[:user_id], _('Cyberplat') + ': ' + _('/lib/cyberplat/checker.ini_was_not_found'))
      redirect_to :root and return false
    end
    @page_title = _('Cyberplat')
    @page_icon = 'money.png'

    @amount, @amount_with_vat, @cp_default_curr, @cyberplat_result_url, @description, @disabled_message, @enabled, @fee,
        @fee_sum, @language, @payment, @payment_id, @submit_url, @test, @user, @user_amount, @user_amount_with_vat,
        @user_curr, @user_enabled, @user_fee_sum, @user_id, @user_vat_sum, @vat_sum = Payment.cyberplat_pay(params)
  end

  def cyberplat_result

    @page_title = _('Cyberplat')
    @page_icon = "money.png"

    # @payment = Payment.find(:first, :conditions => "id = #{params[:orderid]}")
    if params[:orderid] == nil or (@payment = Payment.where("id = #{params[:orderid]}").first) == nil
      redirect_to :root and return false
    end

    @auth_code, @cp_default_curr, @customer_name, @customer_title, @description, @enabled, @error_code, @order_id,
        @payment, @payment_details, @status, @terminal, @test, @transaction_amount, @transaction_currency,
        @transaction_date, @transaction_id, @user = Payment.cyberplat_result(params, session, @payment)

  end

  ################# /Cyberplat ###################################################


  ################# Ouroboros ####################################################


=begin rdoc
 Sets basic data for primary Ouroboros payment window.
=end

  def ouroboros
    #@user in before filter
    @page_title = _('Ouroboros')
    @page_icon = "money.png"
    @enabled = Confline.get_value("Ouroboros_Enabled", @user.owner_id).to_i
    @currencies = Currency.get_active
    @currency = Confline.get_value("Ouroboros_Default_Currency", @user.owner_id)
    @default_amount = Confline.get_value("Ouroboros_Default_Amount", @user.owner_id)
    @min_amount = Confline.get_value("Ouroboros_Min_Amount", @user.owner_id)
    MorLog.my_debug('Ouroboros payment : access', 1)
    MorLog.my_debug("Ouroboros payment : user - #{@user.id}", 1)
  end

  def ouroboros_pay
    #@user in before filter
    @page_title = _('Ouroboros')
    @page_icon = "money.png"
    @enabled = Confline.get_value("Ouroboros_Enabled", @user.owner_id).to_i
    MorLog.my_debug('Ouroboros payment : pay', 1)
    MorLog.my_debug("Ouroboros payment : user - #{@user.id}", 1)
    if @enabled == 1
      if params[:amount].to_d <= 0.0
        flash[:notice] = _('Enter_Payment_Amount')
        redirect_to :action => "ouroboros" and return false
      end
      @address = @user.address
      unless @address
        flash[:notice] = _('User_address_was_not_found')
        redirect_to :root and return false
      end

      @dir = @address.direction if  @address.direction_id.to_i > 0
      @direction = @dir.name if !@dir.nil?

      @merchant_code = Confline.get_value("Ouroboros_Merchant_Code", @user.owner_id)
      @lang = Confline.get_value("Ouroboros_Language", @user.owner_id)
      #@amount =            Confline.get_value("Ouronboros_Default_Amount", @user.owner_id).to_d
      @secret_key = Confline.get_value("Ouroboros_Secret_key", @user.owner_id)
      @ob_min_amount = Confline.get_value("Ouroboros_Min_Amount", @user.owner_id).to_d
      @ob_max_amount = Confline.get_value("Ouroboros_Max_Amount", @user.owner_id).to_d
      @currency = Confline.get_value('Ouroboros_Default_Currency', @user.owner_id)
      @retry_count = Confline.get_value("Ouroboros_Retry_Count", @user.owner_id)
      @completition = Confline.get_value("Ouroboros_Completion", @user.owner_id)
      @completition_over = Confline.get_value("Ouroboros_Completion_Over", @user.owner_id)
      @policy = OuroborosPayment.format_policy(@ob_max_amount, @retry_count, @completition, @completition_over)
      @amount = OuroborosPayment.format_amount(params[:amount], @ob_min_amount, @ob_max_amount)

      @ouroboros_return_url = Web_URL + Web_Dir + "/payments/ouroboros_result"
      @ouroboros_cancel_url = Web_URL + Web_Dir + "/callc/main"
      #@ouroboros_cancel_url = Web_URL + Web_Dir + "/payments/ouroboros_cancel"
      @ouroboros_accept_url = Web_URL + Web_Dir + "/payments/ouroboros_accept"
      @amount_with_vat = @user.get_tax.apply_tax(@amount)
      @description = session[:company] + " balance update"
      @payment = Payment.unnotified_payment('ouroboros') do |p|
        p.gross = @amount
        p.amount = @amount_with_vat
        p.currency = @currency
        p.tax = @amount_with_vat - @amount
      end
      MorLog.my_debug("Ouroboros payment : payment - #{@payment.id}", 1) if @payment
    end
  end

  # /pay by gateway

=begin rdoc

=end

  def ouroboros_accept
    MorLog.my_debug('Ouroboros payment : accept', 1)
    @payment = Payment.where("id = #{params[:order_id].to_i}").first
    if @payment
      @user = @payment.user
      MorLog.my_debug("Ouroboros payment : user - #{@user.id}", 1)
      @enabled = Confline.get_value("Ouroboros_Enabled", @user.owner_id).to_i
      if @enabled.to_i == 1
        if @payment.pending_reason.to_s == 'Unnotified payment'
          key = Confline.get_value("Ouroboros_Secret_key", @user.owner_id)
          @hash = Ouroboros::Hash.reply_hash(params, key)
          if @hash == params[:signature]
            if params[:amount].to_d == @payment.amount.to_d*100
              @currency = Confline.get_value('Ouroboros_Default_Currency', @user.owner_id)
              rate = count_exchange_rate(session[:default_currency], @payment.currency)
              balance = @payment.gross.to_d / rate
              @user.balance += balance
              @user.save
              Application.reset_user_warning_email_sent_status(@user)
              @payment.completed = 1
              @payment.transaction_id = params[:tid]
              @payment.shipped_at = Time.now
              @payment.payer_email = @user.email
              @payment.payment_hash = params[:signature]
              @payment.pending_reason = ''
              @payment.save
              MorLog.my_debug("Ouroboros payment : payment - #{@payment.id}", 1) if @payment
              MorLog.my_debug("Ouroboros payment : amount - #{balance}", 1)
              @error = 0
            else
              @error = 5
              MorLog.my_debug('Ouroboros payment : Amount missmach')
              MorLog.my_debug('   SYSTEM    :' + @payment.amount.to_s)
              MorLog.my_debug('   Ouroboros :' + (params[:amount].to_d/100).to_s)
            end
          else
            @error = 4
            MorLog.my_debug('Ouroboros payment : Hash missmach')
            MorLog.my_debug('   SYSTEM    :' + @hash)
            MorLog.my_debug('   Ouroboros :' + params[:signature])
          end
        else
          @error = 3
          MorLog.my_debug('Ouroboros payment : Unnotified payment.')
          MorLog.my_debug('   SYSTEM    : ' + @payment.pending_reason.to_s)
          MorLog.my_debug('   Ouroboros : Notified payment')
        end
      else
        @error = 2
        MorLog.my_debug('Ouroboros payment : Ouroboros disabled')
        MorLog.my_debug('   SYSTEM    : '+ @enabled.to_s)
      end
    else
      @error = 1
      MorLog.my_debug('Ouroboros payment : Payment was not found')
    end
  end

  ################# /Ouroboros ###################################################

  def change_description
    if @payment.owner_id == correct_owner_id
      @payment.description= params[:description].to_s.strip
      @payment.save
    end
    render :layout => false
  end

  private

  def check_request_url(request)
    Web_URL == request.protocol + request.host
  end

  def find_user_session
    @user = User.includes(:tax).where(['users.id = ?', session[:user_id]]).first

    unless @user
      flash[:notice] = _('User_was_not_found')
      redirect_to :root
    end
  end

  def find_payment
    @payment = Payment.where(:id => params[:id]).first

    unless @payment
      flash[:notice] = _('Payment_was_not_found')
      redirect_to :root
    end
  end

=begin rdoc
 Santitizes params for sql input.
=end

  def get_price_exchange(price, cur)
    exrate = Currency.count_exchange_rate(cur, current_user.currency.name)
    rate_cur = Currency.count_exchange_prices({exrate: exrate, prices: [price.to_d]})
    return rate_cur.to_d
  end

  def provider_billing_check
    unless provider_billing_active?
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def limit_payment
    @show_gateways = false
    if admin?
      last_payment = Payment.where("paymenttype NOT IN ('manual', 'credit note', 'invoice', 'voucher', 'subscription', 'Card')").last
      if (last_payment and (last_payment.date_added > (Time.now - 1.day)))
        flash[:notice] = _('payment_gateway_restriction_for_second_time')
        redirect_to :root and return false
      else
        @show_gateways = true
      end
    else
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to :controller => "/callc", :action => "main"
    end
  end
end
