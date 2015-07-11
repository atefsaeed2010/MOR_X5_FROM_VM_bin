# MOR accounting stuff
# -*- encoding : utf-8 -*-
class AccountingController < ApplicationController

  layout 'callc'
  before_filter :check_post_method, only: [:invoice_recalculate, :comment_invoice,
                                              :invoice_delete]
  before_filter :check_localization
  before_filter :authorize

  before_filter :check_if_can_see_finances, only: [:vouchers, :vouchers_list_to_csv,
                                                      :voucher_new, :voucher_create,
                                                      :voucher_delete]
  before_filter { |object_instance| object_instance.instance_variable_set :@allow_read, true
  object_instance.instance_variable_set :@allow_edit, true
  }

  @@voucher_view = [:vouchers, :vouchers_list_to_csv]
  @@voucher_edit = [:vouchers_new, :vouchers_create, :voucher_delete, :bulk_management]
  before_filter(:only => @@voucher_view + @@voucher_edit) { |object_instance|
    allow_read, allow_edit =
        object_instance.
            check_read_write_permission(@@voucher_view,
                                        @@voucher_edit,
                                        {:role => 'accountant',
                                         :right => :acc_vouchers_manage, :ignore => true})
    object_instance.instance_variable_set :@allow_read, allow_read
    object_instance.instance_variable_set :@allow_edit, allow_edit
    true
  }

  @@invoice_view = [:invoices]
  @@invoice_edit = [:generate_invoices]
  before_filter(:only => @@invoice_view + @@invoice_edit) { |object_instance|
    allow_read, allow_edit =
        object_instance.
            check_read_write_permission(@@invoice_view,
                                        @@invoice_edit,
                                        {:role => 'accountant',
                                         :right => :acc_invoices_manage, :ignore => true})
    object_instance.instance_variable_set :@allow_read, allow_read
    object_instance.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter :find_invoice, only: [:invoice_recalculate]

  def index
    redirect_to(action: 'user_invoices')
  end

  def index_main
    dont_be_so_smart
    redirect_to(:root) && (return false)
  end

  def generate_invoices
    @type = 'postpaid'
    @page_title = _('Generate_invoices')
    @page_icon = 'application_go.png'

    @post = 1
    @pre = 0
  end


  def generate_invoices_to_prepaid_users
    @page_title = _('Generate_invoices_to_prepaid_users')
    @page_icon = 'application_go.png'
  end

  # ================== sending invoices =============================
  def send_invoices
    change_date
    session[:invoice_sent_options] ?
        @sent_options = session[:invoice_sent_options] : @sent_options = {}

    [:s_username, :s_first_name, :s_last_name, :s_number, :s_period_start, :s_period_end,
     :s_issue_date, :s_sent_email, :s_sent_manually, :s_paid, :s_invoice_type].each { |key|
      params[key] ?
          @sent_options[key] = params[key].to_s.strip :
          (@sent_options[key] = '' if !@sent_options[key])
    }

    cond = []
    cond_param = []
    # params that need to be searched with appended any value via LIKE in users table
    ['username', 'first_name', 'last_name'].each { |col|
      add_contition_and_param(@sent_options["s_#{col}".to_sym],
                              @sent_options["s_#{col}".intern].to_s,
                              "users.#{col} LIKE ?", cond, cond_param)
    }

    # params that need to be searched with appended any value via LIKE in invoices table
    add_contition_and_param(@sent_options[:s_number],
                            @sent_options[:s_number].to_s,
                            'invoices.number LIKE ?', cond, cond_param)

    # params that need to be searched via equality.
    ['period_start', 'period_end', 'issue_date', 'sent_email',
     'sent_manually', 'paid', 'invoice_type'].each { |col|
      add_contition_and_param(@sent_options["s_#{col}".to_sym],
                              @sent_options["s_#{col}".to_sym],
                              "invoices.#{col} = ?", cond, cond_param)
    }

    session[:usertype] == 'accountant' ? owner_id = 0 : owner_id = session[:user_id]
    cond << 'users.owner_id = ?'
    cond_param << owner_id

    cond << 'users.send_invoice_types > 0'

    @invoices = Invoice.includes([:user, :tax]).where([cond.join(' AND ')] + cond_param)
    MorLog.my_debug("*************Invoice sending, found : #{@invoices.size.to_i}", 1)
    @number = 0
    not_sent = 0

    params[:email_or_not] = 1
    session[:invoice_sent_options] = @sent_options
    email_from = Confline.get_value('Email_from', correct_owner_id)
    if @invoices.size.to_i > 0
      @invoices.each { |invoice|
        user = invoice.user
        attach = []
        params[:id] = invoice.id
        prepaid = invoice.invoice_type.to_s == 'prepaid' ? 'Prepaid_' : ''
        @invoice = user.send_invoice_types.to_i
        if @invoice.to_i != 0
          if (user.email).length > 0
            if  !(user.postpaid == 0 && invoice.invoicedetails.first.try(:name).to_s == "Manual Payment")
              if (@invoice % 2) == 1
                @invoice = Confline.get_value("#{prepaid}Invoice_default",
                                              correct_owner_id).to_i
              end

              @invoice -= if @invoice >= 256
                            calls_cvs = {}
                            calls_cvs[:file] = get_prepaid_user_calls_csv(current_user,
                                                                          user,
                                                                          invoice.period_start,
                                                                          invoice.period_end)
                            calls_cvs[:content_type] = 'text/csv'
                            calls_cvs[:filename] = "#{_('Calls')}.csv"
                            attach << calls_cvs
                            256
                          else
                            0
                          end

              @invoice -= if @invoice >= 128
                            csv = {}
                            csv[:file] = generate_invoice_by_cid_csv
                            csv[:content_type] = 'text/csv'
                            csv[:filename] = "#{_('Invoice_by_CallerID_csv')}.csv"
                            attach << csv
                            128
                          else
                            0
                          end

              @invoice -= if @invoice >= 64
                            csv = {}
                            csv[:file] = generate_invoice_destinations_csv
                            csv[:content_type] = 'text/csv'
                            csv[:filename] = "#{_('Invoice_destinations_csv')}.csv"
                            attach << csv
                            64
                          else
                            0
                          end

              @invoice -= if @invoice >= 32
                            pdf = {}
                            pdf[:file] = generate_invoice_by_cid_pdf
                            pdf[:content_type] = 'application/pdf'
                            pdf[:filename] = "#{_('Invoice_by_CallerID_pdf')}.pdf"
                            attach << pdf
                            32
                          else
                            0
                          end

              @invoice -= if @invoice >= 16
                            csv = {}
                            csv[:file] = generate_invoice_detailed_csv
                            csv[:content_type] = 'text/csv'
                            csv[:filename] = "#{_('Invoice_detailed_csv')}.csv"
                            attach << csv
                            16
                          else
                            0
                          end

              @invoice -= if @invoice >= 8
                            pdf = {}
                            pdf[:file] = generate_invoice_detailed_pdf
                            pdf[:content_type] = 'application/pdf'
                            pdf[:filename] = "#{_('Invoice_detailed_pdf')}.pdf"
                            attach << pdf
                            8
                          else
                            0
                          end
            end

            @invoice -= if @invoice >= 4
                          csv = {}
                          csv[:file] = generate_invoice_csv
                          csv[:content_type] = 'text/csv'
                          csv[:filename] = "#{_('Invoice_csv')}.csv"
                          attach << csv
                          4
                        else
                          0
                        end

            if @invoice >= 2
              pdf = {}
              pdf[:file] = generate_invoice_pdf
              pdf[:content_type] = 'application/pdf'
              pdf[:filename] = "#{_('Invoice_pdf')}.pdf"
              attach << pdf
            end

            variables = email_variables(user)
            email= Email.where(["name = 'invoices' AND owner_id = ?", user.owner_id]).first
            MorLog.my_debug("Try send invoice to : #{user.address.email}, Invoice : #{invoice.id}, User : #{user.id}, Email : #{email.id}", 1)
            # @num = EmailsController.send_email_with_attachment(email, email_from,
            #                                                    user, attach, variables)
            variables = Email.email_variables(user)
            email.body = nice_email_sent(email, variables)

            @num = EmailsController.send_invoices(email, user.email.to_s,
                                                  email_from, attach,
                                                  invoice.number.to_s)

            MorLog.my_debug @num
            if @num == 'true'
              @number += 1
              invoice.sent_email = 1
              invoice.save
              Action.create_email_sending_action(user, 'email_sent', email)
            else
              not_sent += 1
              Action.create_email_sending_action(user, 'error', email,
                                                 {er_type: 1, err_message: @num})
            end
          else
            not_sent += 1
            email= Email.where(["name = 'invoices' AND owner_id = ?", user.owner_id]).first
            Action.create_email_sending_action(user, 'error', email, {:er_type => 1})
          end
        end
      }
    end

    flash[:notice] = _('ERROR') + ': ' + @num[1].to_s if  @num && @num[0] == 0
    if @number.to_i > 0
      flash[:status] = _('Invoices_sent') + ': ' + @number.to_s
    else
      flash[:notice] = _('Invoices_not_sent') + ': ' + not_sent.to_s if  not_sent.to_i > 0
    end
    flash[:notice] = _('No_invoices_found_in_selected_period') if @invoices.size.to_i == 0
    redirect_to(:action => "invoices") && (return false)
  end

  def get_prepaid_user_calls_csv(requesting_user, user, period_start, period_end)
    user_price, reseller_price, provider_price = requesting_user.get_price_calculation_sqls
    sql = "Select calls.calldate, calls.src, calls.dst, calls.billsec, #{user_price} AS user_price, calls.src_device_id,
                  calls.dst_device_id, calls.prefix, calls.disposition, destinations.name from calls
             JOIN devices on (devices.id = calls.src_device_id or devices.id = calls.dst_device_id)
             LEFT JOIN destinations ON (destinations.prefix = calls.prefix)
             #{SqlExport.left_join_reseler_providers_to_calls_sql}
                Where devices.user_id  = #{user.id}  AND disposition = 'ANSWERED' AND
                      calldate BETWEEN '#{period_start} 00:00:00' AND  '#{period_end} 23:59:59'
              ORDER BY calls.calldate ASC"

    sep, dec = user.csv_params

    calls = Call.find_by_sql(sql)
    csv_string = "#{_('Date')}#{sep}#{ _('Called_from')}#{sep}#{_('Called_to')}#{sep}#{_('Destination')}#{sep}#{_('Duration')}#{sep}#{_('Price')} (#{_(session[:default_currency].to_s)})\n"
    calls.each { |call|
      csv_string += "#{nice_date_time(call.calldate)}#{sep}#{call.src.to_s}#{sep}#{hide_dst_for_user(user, "csv", call.dst.to_s)}#{sep}#{call.name }#{sep}#{nice_time(call.billsec) }#{sep}#{nice_number(call.user_price).to_s.gsub(".", dec).to_s }\n"
    }
    csv_string
  end

  # ================= generate invoices ===============================
  def generate_invoices_status
    MorLog.my_debug " ********* \n for period #{session_from_date} - #{session_till_date}"
    change_date
    MorLog.my_debug "for period #{session_from_date} - #{session_till_date}"
    @page_title = _('Generate_invoices')
    @page_icon = 'application_go.png'

    @owner_id = correct_owner_id

    invoice_number_start = Confline.get_value('Invoice_Number_Start', @owner_id)
    invoice_number_length = Confline.get_value('Invoice_Number_Length', @owner_id).to_i
    invoice_number_type = Confline.get_value('Invoice_Number_Type', @owner_id).to_i

    MorLog.my_debug("\n\n========== Generating invoices ============", 1)

    add_action(current_user_id, 'Starting_invoices_generation', Time.now().to_s)
    # count for which period invoices should be generated

    unless params[:invoice]
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
    type = params[:invoice][:type]
    type = 'postpaid' if !(['postpaid', 'prepaid', 'user'].include?(type))
    redirect_to(action: 'generate_invoices_status_for_prepaid_users',
                invoice: {type: 'prepaid'},
                date_from: params[:date_from],
                date_till: params[:date_till],
                :date_issue => params[:date_issue]) && (return false) if type == 'prepaid'
    if type == 'user'
      @user = User.where(['users.id = ?', params[:s_user_id]]).first if params[:s_user_id]
      unless @user
        flash[:notice] = _('User_not_found')
        redirect_to(:action => :generate_invoices) && (return false)
      end
      if @user.postpaid == 0
        redirect_to(action: 'generate_invoices_status_for_prepaid_users',
                    invoice: {type: 'user'},
                    user: {id: @user.id},
                    date_from: params[:date_from],
                    date_till: params[:date_till],
                    date_issue: params[:date_issue]) && (return false)
      end
    end

    unless [1, 2].include?(invoice_number_type)
      flash[:notice] = _('Please_set_invoice_params')
      if session[:usertype] == 'reseller'
        redirect_to(controller: 'functions', action: 'reseller_settings') && (return false)
      else
        redirect_to(controller: 'functions', action: 'settings') && (return false)
      end
    end
    @period_start = session[:year_from].to_s + '-' +
        good_date(session[:month_from].to_s) + '-' +
        good_date(session[:day_from].to_s)

    @period_end = session[:year_till].to_s + '-' +
        good_date(session[:month_till].to_s) + '-' +
        good_date(session[:day_till].to_s)

    # period with time
    period_start = @period_start.to_time
    period_end = (@period_end + ' 23:59:59').to_time
    period_start_with_time = @period_start + ' 00:00:00'
    period_end_with_time = @period_end + ' 23:59:59'

    MorLog.my_debug session_from_date
    MorLog.my_debug session_till_date

    total_days = (@period_end.to_date - @period_start.to_date) + 1

    if session[:invoices_is_generating].to_i == 1
      flash[:notice] = _('Invoices_is_generating')
      redirect_to(:root) && (return false)
    else
      session[:invoices_is_generating] = 1
    end

    MorLog.my_debug("Invoices will be generated for period #{period_start_with_time} - #{period_end_with_time}")

    @invoices_generated = 0

    # retrieve users to generate invoices to
    if type == 'user'
      @users = User.includes([:tax]).where(["users.owner_id = ? AND users.hidden = 0 AND users.postpaid = 1 AND users.id = ? AND users.generate_invoice = 1 AND users.id not in (SELECT user_id from invoices where period_start = ? AND period_end = ? )", @owner_id, @user.id, @period_start, @period_end])
    else
      @users = User.includes([:tax]).where(["users.owner_id = ? AND users.hidden = 0 AND users.postpaid = 1 AND users.generate_invoice = 1 AND users.id not in (SELECT user_id from invoices where period_start = ? AND period_end = ? )", @owner_id, @period_start, @period_end])
    end

    ind_ex = ActiveRecord::Base.connection.select_all("SHOW INDEX FROM calls")

    use_index = 0
    ind_ex.to_yaml
    ind_ex.each { |ie| use_index = 1; use_index if ie[:key_name].to_s == 'calldate' } if ind_ex

    issue_date = Time.mktime(params[:date_issue][:year],
                             params[:date_issue][:month],
                             params[:date_issue][:day])

    nc = nice_invoice_number_digits('postpaid')
    @users.each { |user|
      MorLog.my_debug("******************** For user : #{user.id} ******************************", 1)
      # --- Subscriptions ---
      MorLog.my_debug('start incomming calls', 1)
      incoming_received_calls,
      incoming_received_calls_price,
      incoming_made_calls,
      incoming_made_calls_price,
      outgoing_calls_price,
      outgoing_calls_by_users_price,
      outgoing_calls,
      outgoing_calls_price,
      outgoing_calls_by_users,
      incoming_calls_by_users,
      incoming_calls_by_users_price,
      outgoing_calls_to_dids,
      outgoing_calls_price_to_dids = call_details_for_user(user,
                                                           period_start_with_time,
                                                           period_end_with_time, use_index)
      MorLog.my_debug('end incomming calls', 1)
      # find subscriptions for user in period
      MorLog.my_debug('start subscriptions', 1)
      subscriptions = user.subscriptions_in_period(period_start_with_time, period_end_with_time, 'invoices')
      MorLog.my_debug('end subscriptions', 1)
      total_subscriptions = 0
      total_subscriptions = subscriptions.size if subscriptions
      MorLog.my_debug("  Total subscriptions this period: #{total_subscriptions}", 1)

      # find sms for user in period
      total_sms, total_sms_price = SmsMessage.user_sms_in_period(period_start_with_time, period_end_with_time, user)

      # check whether the user registered during the invoice generation period
      reg_during_period = user.registered_during_period(@period_end)

      # -- Minimal charge -----
      # Minimal charge is counted for whole month(s), but only for postpaid users. To get a
      # better understang of what is a 'whole month' look at month_difference method
      minimal_charge_amount = 0
      if user.postpaid?
        if user.add_on_minimal_charge? period_end
          if user.minimal_charge_start_at < period_start
            month_diff = ApplicationController.month_difference(period_start, period_end)
          else
            month_diff = ApplicationController.month_difference(user.minimal_charge_start_at,
                                                                period_end)
          end
          minimal_charge_amount = month_diff * user.minimal_charge
        end
      end

      # check if we should generate invoice
      if ((outgoing_calls_price > 0) ||
          (outgoing_calls_by_users_price + incoming_calls_by_users_price > 0) ||
          (incoming_received_calls_price > 0) ||
          (incoming_made_calls_price > 0) ||
          (total_subscriptions > 0) ||
          (minimal_charge_amount > 0) ||
          ((user.invoice_zero_calls == 1) && (outgoing_calls_price >= 0) && (outgoing_calls > 0 )) ||
          ((user.invoice_zero_calls == 1) && (outgoing_calls_by_users_price + incoming_calls_by_users_price >= 0) && (outgoing_calls_by_users > 0)) ||
          ((user.invoice_zero_calls == 1) && (incoming_received_calls_price >= 0) && (incoming_received_calls > 0)) ||
          ((user.invoice_zero_calls == 1) && (incoming_made_calls_price >= 0) && (incoming_made_calls > 0 ))) &&
          (reg_during_period == true)

        MorLog.my_debug('    Generating invoice....', 1)

        tax = user.get_tax.dup
        tax.save
        invoice = Invoice.new(:user_id => user.id,
                              :period_start => @period_start,
                              :period_end => @period_end,
                              :issue_date => issue_date,
                              :paid => 0, :number => '',
                              :invoice_type => 'postpaid',
                              :tax_id => tax.id,
                              :invoice_precision => nc)
        invoice.save
        price = 0

        # --- add own outgoing calls ---
        if (outgoing_calls_price > 0) ||
            ((user.invoice_zero_calls == 1) &&
                (outgoing_calls_price >= 0) &&
                (outgoing_calls > 0))

          invoice.invoicedetails.create(name: _('Calls'),
                                        price: invoice.nice_invoice_number(outgoing_calls_price.to_d,
                                                                            {nc: nc, apply_rounding: true}),
                                        quantity: outgoing_calls, invdet_type: 0)

          price += invoice.nice_invoice_number(outgoing_calls_price.to_d,
                                               {nc: nc, apply_rounding: true}).to_d
        end

        # --- add own outgoing calls ---
        if (outgoing_calls_price_to_dids > 0) ||
            ((user.invoice_zero_calls == 1) &&
                (outgoing_calls_price_to_dids >= 0) &&
                (outgoing_calls_to_dids > 0))

          invoice.invoicedetails.create(name: _('Calls_To_Dids'),
                                        price: invoice.
                                            nice_invoice_number(outgoing_calls_price_to_dids.to_d,
                                                                {nc: nc,
                                                                 apply_rounding: true}),
                                        quantity: outgoing_calls_to_dids, invdet_type: 0)

          price += invoice.nice_invoice_number(outgoing_calls_price_to_dids.to_d,
                                               {nc: nc, apply_rounding: true}).to_d
        end

        # --- add resellers users outgoing calls ---
        if (outgoing_calls_by_users_price > 0) ||
            ((user.invoice_zero_calls == 1) &&
                (outgoing_calls_by_users_price >= 0) &&
                (outgoing_calls_by_users > 0))

          invoice.invoicedetails.create(name: _('Calls_from_users'),
                                        price: invoice.
                                            nice_invoice_number(outgoing_calls_by_users_price.to_d,
                                                                {nc: nc,
                                                                 apply_rounding: true}),
                                        quantity: outgoing_calls_by_users, invdet_type: 0)

          price += invoice.nice_invoice_number(outgoing_calls_by_users_price.to_d,
                                               {nc: nc, apply_rounding: true}).to_d
        end

        if user.postpaid?
          # if minimal charge is set for the user. and for this period
          # calculated price is less than minimal charge, then we should recalculate price
          if price < minimal_charge_amount
            price = minimal_charge_amount
          end
        end

        # --- add own received incoming calls ---
        if ['admin', 'accountant', 'reseller'].include?(session[:usertype])
          if (incoming_received_calls_price > 0)
            invoice.invoicedetails.create(name: _('Did_owner_cost'),
                                          price: incoming_received_calls_price.to_d,
                                          quantity: incoming_received_calls, :invdet_type => 0)

            price += incoming_received_calls_price.to_d
          elsif (incoming_calls_by_users_price > 0)
            invoice.invoicedetails.create(name: _('Did_owner_cost'),
                                          price: incoming_calls_by_users_price.to_d,
                                          quantity: incoming_calls_by_users, invdet_type: 0)

            price += incoming_calls_by_users_price.to_d
          end
        end

        # --- add own made incoming calls ---
        #        if (incoming_made_calls_price > 0)
        #          invoice.invoicedetails.create(:name => _('Incoming_made_calls'), :price => incoming_made_calls_price.to_d, :quantity => incoming_made_calls, :invdet_type => 0)
        #          price += incoming_made_calls_price.to_d
        #        end

        MorLog.my_debug("    Invoice price without subscriptions: #{price.to_s}", 1)
        # nasty hack for Balticom to recalculate invoices/balance - DO NOT USE!!!
        # user.balance -= price
        # user.save
        # --- add subscriptions ---
        MorLog.my_debug('start subscriptions sum', 1)
        subscriptions.each { |sub|
          service = sub.service
          count_subscription = 0
          MorLog.my_debug('start subscriptions flat_rate', 1)
          if service.servicetype == 'flat_rate'
            start_date, end_date = subscription_period(sub, period_start, period_end)
            if sub.no_expire == 1
              if ((period_start.localtime.to_date)..(period_end.localtime.to_date)) === sub.activation_start.to_date
                invd_price = service.read_attribute(:price)
                count_subscription = 1
              end
            else
              invd_price = service.read_attribute(:price) * (months_between(start_date.to_date, end_date.to_date) + 1)
              count_subscription = 1
            end
          end
          MorLog.my_debug('end subscriptions flat_rate', 1)
          MorLog.my_debug('start subscriptions one_time_fee', 1)
          if service.servicetype == 'one_time_fee'
            # one-time-fee subscription only counts once for full price
            if (sub.activation_start >= period_start and sub.activation_start <= period_end)
              invd_price = service.read_attribute(:price)
              count_subscription = 1
            end
          end
          MorLog.my_debug('end subscriptions one_time_fee', 1)
          MorLog.my_debug('start subscriptions periodic_fee', 1)
          if service.servicetype == 'periodic_fee'
            count_subscription = 1

            # from which day used?
            use_start = (sub.activation_start < period_start) ? period_start : sub.activation_start
            # till which day used?
            use_end = (sub.activation_end.blank? || (sub.activation_end > period_end)) ? period_end : sub.activation_end
            start_date = use_start.to_date
            end_date = use_end.to_date
            days_used = end_date - start_date

            if service.periodtype == 'day'
              invd_price = service.read_attribute(:price) * (days_used.to_i + 1)
            elsif service.periodtype == 'month'
              if start_date.month == end_date.month and start_date.year == end_date.year
                total_days = start_date.to_time.end_of_month.day.to_i
                invd_price = service.read_attribute(:price) / total_days * (days_used.to_i + 1)
              else
                invd_price = 0
                if months_between(start_date, end_date) > 1
                  # jei daugiau nei 1 menuo. Tarpe yra sveiku menesiu kuriem nereikia papildomai skaiciuoti intervalu
                  invd_price += (months_between(start_date, end_date)-1) * service.read_attribute(:price)
                end
                # suskaiciuojam pirmo menesio pabaigos ir antro menesio pradzios datas
                last_day_of_month = start_date.to_time.end_of_month.to_date
                last_day_of_month_on_end_date = end_date.to_time.end_of_month.to_date
                if (start_date.day - end_date.day) == 1
                  invd_price += service.read_attribute(:price)
                else
                  invd_price += service.read_attribute(:price) / last_day_of_month.day * (last_day_of_month - start_date + 1).to_i
                  invd_price += service.read_attribute(:price) / last_day_of_month_on_end_date.day * (end_date.day)
                end
              end
            end
          end
          MorLog.my_debug('end subscriptions periodic_fee', 1)
          MorLog.my_debug("    Invoice Subscriptions price: #{invd_price.to_s}", 1)

          if count_subscription == 1
            invoice.invoicedetails.create(name: service.name.to_s + ' - ' + sub.memo.to_s,
                                          price: invoice.
                                              nice_invoice_number(invd_price.to_d,
                                                                  {nc: nc,
                                                                   apply_rounding: true}),
                                          quantity: '1')

            price += invoice.nice_invoice_number(invd_price.to_d,
                                                 {nc: nc, apply_rounding: true}).to_d
          end
        }
        MorLog.my_debug('end subscriptions sum', 1)

        if total_sms.to_i > 0
          invoice.invoicedetails.create(name: _('SMS'), price: invoice.nice_invoice_number(total_sms_price.to_d,
                                                                                          {nc: nc,
                                                                                           apply_rounding: true}),
                                                        quantity: total_sms, invdet_type: 0)
          price += invoice.nice_invoice_number(total_sms_price.to_d, {nc: nc, apply_rounding: true}).to_d
        end

        invoice.price = invoice.nice_invoice_number(price.to_d,
                                                    {nc: nc, apply_rounding: true})
        invoice.number_type = invoice_number_type
        invoice.number = generate_invoice_number(invoice_number_start,
                                                 invoice_number_length,
                                                 invoice_number_type, invoice.id, period_start)

        invoice = invoice.
            generate_taxes_for_invoice(nice_invoice_number_digits(invoice.invoice_type), 1)
        currency = user.currency
        if currency.present?
          invoice.invoice_exchange_rate = currency.exchange_rate
          invoice.invoice_currency = currency.name
        end
        invoice.save

        MorLog.my_debug("    Invoice number: #{invoice.number}", 1)

        @invoices_generated += 1
      end
    }

    add_action(current_user_id, 'Finish_invoices_generation', Time.now().to_s)
    session[:invoices_is_generating] = 0
  end

  # before_filter
  #   find_invoice
  def invoice_recalculate
    invoice_id = @invoice.id

    if @invoice.paid?
      flash[:notice] = _('Invoice_already_paid')
      redirect_to action: :invoice_details, id: invoice_id
    end
    if @invoice.invoice_was_send?
        flash[:notice] = _('Invoice_already_send')
        redirect_to action: :invoice_details, id: invoice_id
    else
      regenerate_invoice_price(@invoice)
      flash[:status] = _('Invoice_successfully_recalculated')
      redirect_to action: :invoice_details, id: invoice_id
    end
  end

  def generate_invoices_status_for_prepaid_users
    @page_title = _('Generate_invoices')
    @page_icon = 'application_go.png'

    change_date

    MorLog.my_debug("==== generate_invoices_status_for_prepaid_users =====", 1)

    @owner_id = correct_owner_id
    type = params[:invoice][:type]
    invoice_number_start = Confline.get_value("Prepaid_Invoice_Number_Start", @owner_id).to_s
    invoice_number_length = Confline.get_value("Prepaid_Invoice_Number_Length", @owner_id).to_i
    if session[:usertype] == 'reseller'
      invoice_number_start = Confline.get_value("Invoice_Number_Start", @owner_id).to_s
      invoice_number_length = Confline.get_value("Invoice_Number_Length", @owner_id).to_i
      invoice_number_type = Confline.get_value("Invoice_Number_Type", @owner_id).to_i
    else
      invoice_number_type = Confline.get_value("Prepaid_Invoice_Number_Type", @owner_id).to_i
    end

    unless [1, 2].include?(invoice_number_type)
      flash[:notice] = _('Please_set_invoice_params')
      if session[:usertype] == 'reseller'
        redirect_to(controller: :functions, action: :reseller_settings) && (return false)
      else
        redirect_to(controller: :functions, action: :settings) && (return false)
      end
    end
    MorLog.my_debug("\n\n========== Generating invoices ============", 1)

    @period_start = session[:year_from].to_s + "-" +
        good_date(session[:month_from].to_s) + "-" +
        good_date(session[:day_from].to_s)

    @period_end = session[:year_till].to_s + "-" +
        good_date(session[:month_till].to_s) + "-" +
        good_date(session[:day_till].to_s)

    #    # period with time
    period_start = @period_start.to_time
    period_end = (@period_end + " 23:59:59").to_time
    period_start_with_time = @period_start + " 00:00:00"
    period_end_with_time = @period_end + " 23:59:59"
    total_days =(@period_end.to_date - @period_start.to_date) + 1

    if session[:invoices_is_generating].to_i == 1
      flash[:notice] = _('Invoices_is_generating')
      redirect_to :root and return false
    else
      session[:invoices_is_generating] = 1
    end

    MorLog.my_debug("Prepaid Invoices will be generated for period #{period_start_with_time} - #{period_end_with_time}", 1)

    @invoices_generated = 0

    # count total users (by owner_id)
    if type == 'user'
      @total_users = 1
    else
      @total_users = User.count(:all, :conditions => "owner_id = #{@owner_id} AND hidden = 0 AND postpaid = 0 AND users.id not in (SELECT user_id from invoices where period_start = '#{@period_start}' AND period_end = '#{@period_end}' )")
    end
    # retrieve users without invoices this period

    if type == 'user'
      @users = User.includes([:tax]).where(["users.owner_id = ? AND users.hidden = 0 AND users.postpaid = 0 AND users.id = ? AND users.id not in (SELECT user_id from invoices where period_start = ? AND period_end = ? )", @owner_id, params[:user][:id], @period_start, @period_end])
    else
      @users = User.includes([:tax]).where(["users.owner_id = ? AND users.hidden = 0 AND users.postpaid = 0 AND users.id not in (SELECT user_id from invoices where period_start = ? AND period_end = ? )", @owner_id, @period_start, @period_end])
    end

    ind_ex = ActiveRecord::Base.connection.select_all("SHOW INDEX FROM calls")
    use_index = 0
    ind_ex.to_yaml
    ind_ex.each { |ie| use_index = 1; use_index if ie[:key_name].to_s == 'calldate' } if ind_ex

    issue_date = Time.mktime(params[:date_issue][:year],
                             params[:date_issue][:month],
                             params[:date_issue][:day])

    nc = nice_invoice_number_digits('prepaid')

    @users.each { |user|
      MorLog.my_debug("******************** For user : #{user.id} ******************************", 1)
      MorLog.my_debug("incoming calls start", 1)
      incoming_received_calls,
          incoming_received_calls_price,
          incoming_made_calls,
          incoming_made_calls_price,
          outgoing_calls_price,
          outgoing_calls_by_users_price,
          outgoing_calls,
          outgoing_calls_price,
          outgoing_calls_by_users,
          incoming_calls_by_users,
          incoming_calls_by_users_price,
          outgoing_calls_to_dids,
          outgoing_calls_price_to_dids = call_details_for_user(user,
                                                               period_start_with_time,
                                                               period_end_with_time, use_index)

      MorLog.my_debug("incoming calls end", 1)
      MorLog.my_debug("subscriptions start", 1)
      subscriptions = user.subscriptions_in_period(period_start_with_time,
                                                   period_end_with_time,
                                                   'invoices')
      MorLog.my_debug("subscriptions end", 1)
      total_subscriptions = 0
      total_subscriptions = subscriptions.size if subscriptions

      # find sms for user in period
      total_sms, total_sms_price = SmsMessage.user_sms_in_period(period_start_with_time, period_end_with_time, user)

      # check whether the user registered during the invoice generation period
      reg_during_period = user.registered_during_period(@period_end)

      if ((outgoing_calls_price > 0) ||
          (outgoing_calls_by_users_price + incoming_calls_by_users_price > 0) ||
          (incoming_received_calls_price > 0) ||
          (incoming_made_calls_price > 0) ||
          (total_subscriptions > 0)) &&
          (reg_during_period == true)

        MorLog.my_debug("    Generating invoice....", 1)
        user_tax = user.tax
        # possible error fix
        if not user_tax
          user.assign_default_tax2
          user_tax = user.tax
        end

        # tax for invoice
        tax = user_tax.dup
        tax.save
        invoice = Invoice.new(
            user_id: user.id,
            period_start: @period_start,
            period_end: @period_end,
            issue_date: issue_date,
            paid: 1, number: '',
            invoice_type: 'prepaid',
            tax_id: tax.id,
            invoice_precision: nc)

        currency = user.currency
        if currency.present?
          invoice.invoice_exchange_rate = currency.exchange_rate
          invoice.invoice_currency = currency.name
        end

        invoice.save

        price = 0

        if (outgoing_calls_price > 0)
          invoice.invoicedetails.create(
              name: _('Calls'),
              price: invoice.
                  nice_invoice_number(outgoing_calls_price.to_d,
                                      {nc: nc, apply_rounding: true}),
              quantity: outgoing_calls,
              invdet_type: 0)

          price += invoice.nice_invoice_number(outgoing_calls_price.to_d,
                                               {nc: nc, apply_rounding: true}).to_d
        end

        if (outgoing_calls_price_to_dids > 0)
          invoice.invoicedetails.create(
              name: _('Calls_To_Dids'),
              price: invoice.nice_invoice_number(outgoing_calls_price_to_dids.to_d,
                                                 {nc: nc, apply_rounding: true}),
              quantity: outgoing_calls_to_dids,
              invdet_type: 0)

          price += invoice.nice_invoice_number(outgoing_calls_price_to_dids.to_d,
                                               {nc: nc, apply_rounding: true}).to_d
        end

        # --- add resellers users outgoing calls ---
        if (outgoing_calls_by_users_price > 0)
          invoice.invoicedetails.create(
              name: _('Calls_from_users'),
              price: invoice.nice_invoice_number(outgoing_calls_by_users_price.to_d,
                                                 {nc: nc, apply_rounding: true}),
              quantity: outgoing_calls_by_users,
              invdet_type: 0)

          price += invoice.nice_invoice_number(outgoing_calls_by_users_price.to_d,
                                               {nc: nc, apply_rounding: true}).to_d
        end

        #        # --- add own received incoming calls ---
        #        if (incoming_received_calls_price > 0)
        #          invoice.invoicedetails.create(:name => _('Incoming_received_calls'), :price => incoming_received_calls_price.to_d, :quantity => incoming_received_calls, :invdet_type => 0)
        #          price += incoming_received_calls_price.to_d
        #        end
        #
        #        # --- add own made incoming calls ---
        #        if (incoming_made_calls_price > 0)
        #          invoice.invoicedetails.create(:name => _('Incoming_made_calls'), :price => incoming_made_calls_price.to_d, :quantity => incoming_made_calls, :invdet_type => 0)
        #          price += incoming_made_calls_price.to_d
        #        end

        # --- add subscriptions ---
        MorLog.my_debug("start subscriptions sum", 1)
        subscriptions.each { |sub|

          service = sub.service
          count_subscription = 0
          MorLog.my_debug("start subscriptions one_time_fee", 1)
          if service.servicetype == 'one_time_fee'
            # one-time-fee subscription only counts once for full price
            if ((sub.activation_start >= period_start) && (sub.activation_start <= period_end))
              invd_price = service.price
              count_subscription = 1
            end
          end
          MorLog.my_debug("end subscriptions one_time_fee", 1)
          MorLog.my_debug("start subscriptions flat_rate", 1)
          if service.servicetype == 'flat_rate'
            if sub.no_expire == 1
              if ((period_start.localtime.to_date)..(period_end.localtime.to_date)) === sub.activation_start.to_date
                invd_price = service.price.to_d
                count_subscription = 1
              end
            else
              start_date, end_date = subscription_period(sub, period_start, period_end)
              invd_price = service.price.to_d * (months_between(start_date.to_date,
                                                                end_date.to_date) + 1)
              count_subscription = 1
            end
          end
          MorLog.my_debug("end subscriptions flat_rate", 1)
          MorLog.my_debug("start subscriptions periodic_fee", 1)
          if service.servicetype == 'periodic_fee'
            count_subscription = 1

            # from which day used?
            use_start =
                (sub.activation_start < period_start) ? period_start : sub.activation_start

            # till which day used?
            use_end =
                (sub.activation_end.blank? || (sub.activation_end > period_end)) ?
                    period_end : sub.activation_end

            start_date = use_start.to_date
            end_date = use_end.to_date
            days_used = end_date - start_date

            if (start_date.month == end_date.month) && (start_date.year == end_date.year)
              total_days = start_date.to_time.end_of_month.day
              invd_price = service.price / total_days.to_i * (days_used.to_i + 1)
            else
              invd_price = 0
              if months_between(start_date, end_date) > 1
                # jei daugiau nei 1 menuo. Tarpe yra sveiku menesiu kuriem nereikia papildomai skaiciuoti intervalu
                invd_price += (months_between(start_date, end_date)-1) * service.price.to_d
              end
              # suskaiciuojam pirmo menesio pabaigos ir antro menesio pradzios datas
              last_day_of_month = start_date.to_time.end_of_month.to_date
              last_day_of_month_on_end_date = end_date.to_time.end_of_month.to_date
              if (start_date.day - end_date.day) == 1
                invd_price += service.price
              else
                invd_price += service.price / last_day_of_month.day *
                    (last_day_of_month - start_date + 1).to_i

                invd_price += service.price / last_day_of_month_on_end_date.day * (end_date.day)
              end
            end
          end

          if count_subscription == 1
            invoice.invoicedetails.create(name: service.name.to_s + " - " + sub.memo.to_s,
                                          price: invoice.
                                              nice_invoice_number(invd_price.to_d,
                                                                  {nc: nc, apply_rounding: true}),
                                          quantity: "1")

            price += invoice.nice_invoice_number(invd_price.to_d,
                                                 {nc: nc, apply_rounding: true}).to_d
          end
          MorLog.my_debug("end subscriptions periodic_fee", 1)
        }
        MorLog.my_debug("end subscriptions sum", 1)

        if total_sms.to_i > 0
          invoice.invoicedetails.create(:name => _('SMS'), :price => invoice.nice_invoice_number(total_sms_price.to_d, {nc: nc, apply_rounding: true}), :quantity => total_sms, :invdet_type => 0)
          price += invoice.nice_invoice_number(total_sms_price.to_d, {nc: nc, apply_rounding: true}).to_d
        end

        invoice.price = invoice.nice_invoice_number(price.to_d, {nc: nc, apply_rounding: true})
        invoice.number_type = invoice_number_type
        invoice.number = generate_invoice_number(invoice_number_start, invoice_number_length,
                                                 invoice_number_type, invoice.id, period_start)
        invoice = invoice.generate_taxes_for_invoice(nc, 1)
        MorLog.my_debug("    Invoice number: #{invoice.number}", 1)
        invoice.save
        @invoices_generated += 1
      end
    }
    session[:invoices_is_generating] = 0
  end

  def date_query(date_from, date_till)
    # date query
    if date_from == ''
      date_sql = ''
    else
      if date_from.length > 11
        date_sql = "AND calldate BETWEEN '#{date_from.to_s}' AND '#{date_till.to_s}'"
      else
        date_sql = "AND calldate BETWEEN '" +
            date_from.to_s +
            " 00:00:00' AND '" +
            date_till.to_s +
            " 23:59:59'"
      end
    end
    date_sql
  end

  def invoices
    @show_currency_selector = 1

    @options = session[:invoice_options] ? session[:invoice_options] : {}
    @sent_options = session[:invoice_sent_options] ? session[:invoice_sent_options] : {}

    @page_title = _('Invoices')
    @page_icon = 'view.png'

    change_date

    # search params parsing. Assign new params if they were sent, default unset params to '' and leave if param is set but not sent
    if params[:clear].to_s == 'true'
      @options.each { |key, value|
        logger.debug "Need to clear search."
        if key.to_s.scan(/^s_.*/).size > 0
          @options[key] = nil
          logger.debug "     clearing #{key}"
        end
      }
    end
    [:s_username, :s_first_name, :s_last_name, :s_number, :s_period_start, :s_period_end,
     :s_issue_date, :s_sent_email, :s_sent_manually, :s_paid, :s_invoice_type].each { |key|
      @options[key] = (params[key] || @options[key] || '').to_s.strip
    }

    # page number is an exception because it defaults to 1
    if params[:page] and params[:page].to_i > 0
      @options[:page] = params[:page].to_i
    else
      @options[:page] = 1 if !@options[:page] or @options[:page] <= 0
    end

    # same goes for order descending
    params[:order_desc] ?
        @options[:order_desc] = params[:order_desc].to_i :
        (@options[:order_desc] = 0 if !@options[:order_desc])

    cond = []
    cond_param = []

    # params that need to be searched with appended any value via LIKE in users table
    ['username', 'first_name', 'last_name'].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym],
                              @options["s_#{col}".intern].to_s,
                              "users.#{col} LIKE ?", cond, cond_param)
    }

    # params that need to be searched with appended any value via LIKE in invoices table
    add_contition_and_param(@options[:s_number],
                            @options[:s_number].to_s,
                            "invoices.number LIKE ?", cond, cond_param)

    # params that need to be searched via equality.
    ['period_start', 'period_end', 'issue_date', 'sent_email',
     'sent_manually', 'paid', 'invoice_type'].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".to_sym],
                              "invoices.#{col} = ?", cond, cond_param) }

    owner_id = session[:usertype] == 'accountant' ? 0 : session[:user_id]
    cond << "users.owner_id = ?"
    cond_param << owner_id

    @options[:order_by], order_by = invoices_order_by(params, @options)

    @total_pages = (Invoice.count(:all, :include => [:user],
                                  :conditions => [cond.join(" AND ")] + cond_param).to_d /
        session[:items_per_page].to_d).ceil

    @options[:page] = @total_pages if @options[:page].to_i > @total_pages and @total_pages > 0

    dc = session[:show_currency]
    @ex = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    @conf = Confline.get_value("Invoice_allow_recalculate_after_send").to_i

    if params[:to_csv].to_i == 0
      @tot_in_wat = 0

      @total_invoice = Invoice.select("SUM(price * IF(invoice_currency = '#{dc}', invoice_exchange_rate, '#{@ex}')) AS price, SUM(price_with_vat * IF(invoice_currency = '#{dc}', invoice_exchange_rate, '#{@ex}')) AS price_with_vat").joins("LEFT JOIN users ON (users.id = invoices.user_id)").where([cond.join(" AND ")] + cond_param).first
      @total_invoice_price = @total_invoice.read_attribute(:price) ?
          @total_invoice.read_attribute(:price) : 0

      @tot_in_wat = @total_invoice.read_attribute(:price_with_vat)

      @invoices = Invoice.joins([:user, :tax]).
          where([cond.join(" AND ")] + cond_param).
          order(order_by).
          limit(session[:items_per_page]).
          offset(session[:items_per_page] * (@options[:page] - 1))

      @search = cond.length > 1 ? 1 : 0
      # cond.length > 1 ? @send_invoices = 1 : @send_invoices = 0
      @send_invoices = 0

      @period_starts = ActiveRecord::Base.connection.select_all("SELECT DISTINCT period_start FROM invoices, users where users.owner_id = #{corrected_user_id} and invoices.user_id = users.id")
      @period_ends = ActiveRecord::Base.connection.select_all("SELECT DISTINCT period_end FROM invoices, users where users.owner_id = #{corrected_user_id} and invoices.user_id = users.id")
      @issue_dates = ActiveRecord::Base.connection.select_all("SELECT DISTINCT issue_date FROM invoices, users where users.owner_id = #{corrected_user_id} and invoices.user_id = users.id")

      session[:invoice_options] = @options
    else
      nice_number_hash = {change_decimal: session[:change_decimal],
                          global_decimal: session[:global_decimal]}

      invoices = Invoice.includes([:user, :tax]).
          where([cond.join(" AND ")] + cond_param).order(order_by)

      sep, dec = current_user.csv_params
      csv_line = "'#{_('ID')}'#{sep}'#{_('User')}'#{sep}'#{_('Amount')} (#{dc})'#{sep}'#{_('Tax')}'#{sep}'#{_('Amount_with_tax')} (#{dc})'\n"
      csv_line += invoices.map { |result| "#{result.id}#{sep}" +
          "#{nice_user(result.user).delete(sep)}#{sep}" +
          "#{result.nice_invoice_number(result.converted_price(result.invoice_currency.to_s == dc ? result.invoice_exchange_rate : @ex), nice_number_hash).to_s.gsub(".", dec).to_s}#{sep}" +
          "#{result.nice_invoice_number((result.converted_price_with_vat(result.invoice_currency.to_s == dc ? result.invoice_exchange_rate : @ex) - result.converted_price(result.invoice_currency.to_s == dc ? result.invoice_exchange_rate : @ex)), nice_number_hash).to_s.gsub(".", dec).to_s}#{sep}" +
          "#{result.nice_invoice_number((result.converted_price_with_vat(result.invoice_currency.to_s == dc ? result.invoice_exchange_rate : @ex)), nice_number_hash).to_s.gsub(".", dec).to_s}"
      }.join("\n")
      if params[:test].to_i == 1
        render :text => "Invoices-#{session[:show_currency]}.csv" + csv_line.to_s
      else
        send_data(csv_line,
                  type: 'text/csv; charset=utf-8; header=present',
                  filename: "Invoices-#{session[:show_currency]}.csv")
      end
    end
  end

  def user_invoices
    @ex = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])
    @page_title = _('Invoices')
    @page_icon = 'view.png'

    if admin? or accountant?
      dont_be_so_smart
      redirect_to :root and return false
    end

    @invoices = Invoice.includes([:tax]).where(["invoices.user_id = ?", session[:user_id]])
  end

  def pay_invoice
    if request.get?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    invoice = Invoice.includes([:tax]).where(:id => params[:id]).first
    unless invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to(:root) && (return false)
    end
    invoice.pay(params, correct_owner_id)

    redirect_to(action: 'invoices')
  end

  def sent_invoice
    invoice = Invoice.where(:id => params[:id]).first
    unless invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to :root and return false
    end

    invoice.toggle_status(params[:status])

    redirect_to action: :invoice_details, id: invoice.id
  end

  def invoice_details
    @show_currency_selector = 1

    unless can_see_finances?
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to :root and return false
    end

    flash[:notice] = _('Invoice_not_found') and redirect_to :action => 'invoices' and return false unless params[:id]
    @invoice = Invoice.includes([:user]).where(:id => params[:id]).first

    unless @invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to(:root) && (return false)
    end

    @invoice_invoicedetails = @invoice.invoicedetails

    if @invoice.invoice_currency.to_s == session[:show_currency]
      @ex = @invoice.invoice_exchange_rate
    else
      @ex = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])
    end

    @day_selection = @invoice.paid_date || Time.now

    @user = @invoice.user
    @page_title = _('Invoice') + ': ' + @invoice.number
    @page_icon = 'view.png'
  end

  def comment_invoice
    invoice = Invoice.includes([:user]).where(["invoices.id = ?", params[:id]]).first
    unless invoice ||
        (['admin', 'accountant'].include?(session[:usertype])) ||
        (session[:user_id] == @invoice.user.owner_id)

      dont_be_so_smart
      redirect_to :root and return false
    end
    invoice.comment = params[:invoice][:comment].to_s
    if invoice.save
      flash[:status] = _('Invoice_Commented')
    else
      flash[:notice] = _('Invoice_Not_Commented')
    end
    redirect_to action: :invoice_details, id: invoice.id
  end

  def user_invoice_details
    @invoice = Invoice.includes([:tax, :user]).where(:id => params[:id]).first

    unless @invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to :root and return false
    end

   @ex = (@invoice.invoice_currency.present? ?
        @invoice.invoice_exchange_rate :
        Currency.count_exchange_rate(session[:default_currency], session[:show_currency]))

    @invoice_invoicedetails = @invoice.
        invoicedetails.select("name,  price * #{@ex} AS price, quantity, invdet_type")

    if @invoice.user_id != current_user_id
      dont_be_so_smart
      redirect_to :root and return false
    end

    @user = @invoice.user
    @invoices_status = @user.get_invoices_status
    @page_title = _('Invoice') + ': ' + @invoice.number
    @page_icon = 'view.png'
  end

  def invoice_delete
    inv = Invoice.includes([:user, :tax]).where(:id => params[:id]).first
    if !inv
      dont_be_so_smart
      redirect_to :root and return false
    end
    inv_num = inv.number

    if inv.destroy
      flash[:status] = _('Invoice_deleted') + ': ' + inv_num
    else
      flash_errors_for(_('Invoice_not_deleted'), inv_num)
    end
    redirect_to(action: :invoices) && (return false)
  end

  # ==========PDF==========

  def generate_invoice_pdf
    invoice = Invoice.includes([:tax, :user, :invoicedetails]).where({:id => params[:id]}).first

    unless invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to :root and return false
    end

    idetails = invoice.invoicedetails
    user = invoice.user
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[0] == 2)

    if not_authorized_generate_pdf_or_csv(user, status) == 1
      redirect_to :root and return false
    end

    type = (user.postpaid.to_i == 1 or invoice.user.owner_id != 0) ? 'postpaid' : 'prepaid'

    dc , ex = manage_exchange_rates(invoice)


    pdf, arr_t = invoice.
        generate_simple_pdf(current_user,
                            dc, ex,
                            nice_invoice_number_digits(type),
                            session[:change_decimal],
                            session[:global_decimal],
                            params[:test].to_i == 1)

    filename = invoice.filename(type, 'pdf')

    if params[:email_or_not]
      return pdf.render
    else
      if params[:test].to_i == 1
        pdf.render
        text = 'Ok'
        text += "\n" + invoice.to_yaml if invoice
        text += "\n" + idetails.to_yaml if idetails
        text += "\n" + type
        text += "\n" + filename
        text += "\n" + arr_t.to_yaml if arr_t
        render text: text
      else
        send_data pdf.render, filename: filename, type: 'application/pdf'
      end
    end
  end

  def generate_invoice_detailed_pdf
    invoice = Invoice.where(:id => params[:id]).includes([:tax, :user]).first

    unless invoice
      if params[:action] == 'generate_invoice_detailed_pdf'
        flash[:notice] = _('Invoice_not_found')
        redirect_to :root and return false
      else
        raise 'Invoice_not_found'
      end
    end

    user = invoice.user
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[2] == 8)

    if not_authorized_generate_pdf_or_csv(user, status) == 1
      redirect_to :root and return false
    end

    type = ((user.postpaid.to_i == 1) || (invoice.user.owner_id != 0)) ? 'postpaid' : 'prepaid'

    # Hide from prepaid manual payments
    if (type == 'prepaid') &&
        (invoice.invoicedetails.first.try(:name).to_s == 'Manual Payment')

      flash[:notice] = _('Dont_be_so_smart')
      redirect_to :root and return false
    end

    dc, ex = manage_exchange_rates(invoice)
    show_avg_rate = 1

    pdf, arr_t = invoice.generate_invoice_detailed_pdf(current_user, dc, ex, nice_invoice_number_digits(type), session[:change_decimal], session[:global_decimal], show_avg_rate, params[:test].to_i == 1)

    if params[:email_or_not]
      return pdf.render
    else
      filename = invoice.filename(type, 'pdf','Invoice_detailed')
      if params[:test].to_i == 1
        pdf.render
        text = 'Ok'
        text += "\n" + type
        text += "\n" + filename
        text += "\n" + "currency => #{dc}"
        text += "\n" + "avg_rate => #{arr_t.to_yaml}" if arr_t
        render :text => text
      else
        send_data pdf.render, :filename => filename, :type => 'application/pdf'
      end
    end
  end

  def add_space (space)
    space = space.to_i
    sp = ''
    space.times do
      sp += ' '
    end
    sp
  end

  def generate_invoice_by_cid_pdf
    invoice = Invoice.where(:id => params[:id]).includes([:tax, :user]).first

    unless invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to :root and return false
    end

    user = invoice.user
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[4] == 32)

    if not_authorized_generate_pdf_or_csv(user, status) == 1
      redirect_to :root and return false
    end

    type = (user.postpaid.to_i == 1 || invoice.user.owner_id != 0) ? 'postpaid' : 'prepaid'

    # Hide from prepaid manual payments
    if type == 'prepaid' && invoice.invoicedetails.first.try(:name).to_s == 'Manual Payment'
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to :root and return false
    end

    dc, ex = manage_exchange_rates(invoice)

    pdf, arr_t = invoice.generate_invoice_by_cid_pdf(current_user, dc, ex, nice_invoice_number_digits(type), session[:change_decimal], session[:global_decimal], params[:test].to_i == 1)

    if params[:email_or_not]
      return pdf.render
    else
      filename = invoice.filename(type, 'pdf','Invoice_by_cid')
      if params[:test].to_i == 1
        pdf.render
        text = 'Ok'
        text += "\n" + "#{arr_t.inspect}" if arr_t
        text += "\n" + type
        text += "\n" + filename
        render :text => text
      else
        send_data pdf.render, :filename => filename, :type => 'application/pdf'
      end
    end

  end

  def generate_test_pdf
    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")

    # ---------- Company details ----------

    pdf.text(session[:company], {:left => 40, :size => 23})
    pdf.text(Confline.get_value("Invoice_Address1"), {:left => 40, :size => 12})
    pdf.text(Confline.get_value("Invoice_Address2"), {:left => 40, :size => 12})
    pdf.text(Confline.get_value("Invoice_Address3"), {:left => 40, :size => 12})
    pdf.text(Confline.get_value("Invoice_Address4"), {:left => 40, :size => 12})

    # ----------- Invoice details ----------

    pdf.fill_color('DCDCDC')
    pdf.draw_text(_('INVOICE'), {:at => [330, 700], :size => 26})
    pdf.fill_color('000000')
    pdf.draw_text(_('Date') + ': ' + 'invoice.issue_date.to_s', {:at => [330, 685], :size => 12})
    pdf.draw_text(_('Invoice_number') + ': ' + 'invoice.number.to_s', {:at => [330, 675], :size => 12})

    pdf.image(Actual_Dir+"/public/images/rails.png")
    pdf.text("Test Text : ąčęėįšųūž_йцукенгшщз")
    send_data pdf.render, :filename => "test.pdf", :type => 'application/pdf'
  end


  #================================ end of PDF ========================================================================

  def generate_invoice_csv
    invoice = Invoice.includes([:tax, :user]).where(:id => params[:id]).first

    unless invoice
      flash[:notice] = _('Invoice_was_not_found')
      redirect_to :root and return false
    end

    user = invoice.user
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[1] == 4)

    if not_authorized_generate_pdf_or_csv(user, status) == 1
      redirect_to :root and return false
    end

    sep, dec = user.csv_params
    nice_number_hash  = {:change_decimal => session[:change_decimal], :global_decimal => session[:global_decimal]}

    dc, ex = manage_exchange_rates(invoice)

    csv_string = ["number#{sep}user_id#{sep}period_start#{sep}period_end#{sep}issue_date#{sep}price (#{dc})#{sep}price_with_tax (#{dc})#{sep}accounting_number"]
    csv_string << "#{invoice.number.to_s}#{sep}" +
        "#{nice_user(user)}#{sep}" +
        "#{nice_date(invoice.period_start, 0)}#{sep}" +
        "#{nice_date(invoice.period_end, 0)}#{sep}" +
        "#{nice_date(invoice.issue_date)}#{sep}" +
        "#{invoice.nice_invoice_number(invoice.converted_price(ex), nice_number_hash).to_s.gsub(".", dec).to_s}#{sep}" +
        "#{invoice.nice_invoice_number(invoice.converted_price_with_vat(ex), nice_number_hash).to_s.gsub(".", dec).to_s}#{sep}" +
        "#{user.accounting_number}"

    #  my_debug csv_string
    prepaid, prep = invoice_type(invoice, user)

    filename = invoice.filename(prep, 'csv', nil, dc)

    if params[:email_or_not]
      return csv_string.join("\n")
    else
      if params[:test].to_i == 1
        render :text => (["Filename: #{filename}"] + csv_string).join("\n")
      else
        send_data(csv_string.join("\n"), :type => 'text/csv; charset=utf-8; header=present', :filename => filename)
      end
    end
  end

  def generate_invoice_detailed_csv
    invoice = Invoice.includes([:tax, :user]).where(:id => params[:id]).first

    unless invoice
      flash[:notice] = _('Invoice_was_not_found')
      redirect_to :root and return false
    end

    idetails = invoice.invoicedetails
    first_idetail = idetails.first
    user = invoice.user
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[3] == 16)

    if not_authorized_generate_pdf_or_csv(user, status) == 1
      redirect_to :root and return false
    end

    # Hide from prepaid manual payments
    if invoice.invoice_type.downcase == 'prepaid' and first_idetail and first_idetail.name == 'Manual Payment'
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to :root and return false
    end

    dc, ex = manage_exchange_rates(invoice)

    sep, dec = user.csv_params

    owner = invoice.user.owner_id
    prepaid = (invoice.invoice_type.to_s == 'prepaid' and owner == 0) ? 'Prepaid_' : ''

    up, rp, pp = user.get_price_calculation_sqls
    billsec_cond = Confline.get_value("Invoice_user_billsec_show", owner).to_i == 1 ? 'user_billsec' : 'billsec'
    user_price = SqlExport.replace_price(up, {:ex => ex})
    reseller_price = SqlExport.replace_price(rp, {:ex => ex})
    did_sql_price = SqlExport.replace_price('calls.did_price', {:ex => ex, :reference => 'did_price'})
    did_inc_sql_price = SqlExport.replace_price('calls.did_inc_price', {:ex => ex, :reference => 'did_inc_price'})
    #did_sql_price = SqlExport.replace_price('calls.did_price', 'did_price')
    selfcost = SqlExport.replace_price(pp, {:ex => ex, :reference => 'selfcost'})
    user_rate = SqlExport.replace_price('calls.user_rate', {:ex => ex, :reference => 'user_rate'})
    min_type = (Confline.get_value("#{prepaid}Invoice_Show_Time_in_Minutes", owner).to_i == 1) ? 1 : 0
    csv_string = []

    sub = 0
    idetails.each { |id|
      if id.invdet_type > 0 or id.name == _('Did_owner_cost') or id.name == _('SMS')
        sub = 1
      end
    }

    if idetails
      if sub.to_i == 1
        csv_string << "services#{sep}price"
      end

      idetails.each { |id|
        #MorLog.my_debug(id.to_yaml)
        @iprice = id.price if id.price
        if id.invdet_type > 0
          if id.quantity
            qt = id.quantity
            tp = qt * id.converted_price(ex) if id.price
          else
            qt = ''
            tp = id.converted_price(ex)
          end
          csv_string << "#{nice_inv_name(id.name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
        elsif id.name == _('Did_owner_cost') or id.name == _('SMS')
          qt = id.quantity
          tp = id.converted_price(ex) if id.price
          csv_string << "#{nice_inv_name(id.name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
        end
      }
    end

    csv_string << _('Minimal_Charge_for_Calls') + " (#{dc})" + sep + nice_number(user.converted_minimal_charge(ex).to_d) if user.minimal_charge_enabled?

    show_zero_calls = user.invoice_zero_calls.to_i
    if show_zero_calls == 0
      zero_calls_sql = " AND #{up} > 0 "
    else
      zero_calls_sql = ''
    end

    sql = "SELECT #{user_rate}, destinationgroups.id, destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', destinationgroups.desttype as 'dg_type',  COUNT(*) as 'calls', SUM(#{billsec_cond}) as 'billsec', #{selfcost}, SUM(#{user_price}) as 'price', dids.did as 'to_did' " +
        "FROM calls "+
        "LEFT JOIN dids on calls.did_id = dids.id AND dids.did = calls.dst "+
        "LEFT JOIN devices ON (calls.src_device_id = devices.id)
        LEFT JOIN destinations ON (destinations.prefix = calls.prefix)  "+
        "LEFT JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.left_join_reseler_providers_to_calls_sql}"+
        "WHERE calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' " +
        " AND devices.user_id = '#{user.id}' AND calls.card_id = 0  #{zero_calls_sql}" +
        "GROUP BY destinationgroups.id, to_did, calls.user_rate "+
        "ORDER BY destinationgroups.name ASC, destinationgroups.desttype ASC"

    if user.usertype == 'reseller'
      reseller_select = "SELECT calls.dst,  COUNT(*) as 'count_calls', SUM(#{billsec_cond}) as 'sum_billsec', #{selfcost}, SUM(#{reseller_price}) as 'price', #{user_rate}  " +
          "FROM calls "+
          "#{SqlExport.left_join_reseler_providers_to_calls_sql} LEFT JOIN destinations ON (destinations.prefix = calls.prefix) LEFT JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) "+
          "WHERE calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' " +
          " AND (calls.reseller_id = '#{user.id}' ) #{zero_calls_sql}" +
          "GROUP BY destinationgroups.id, calls.user_rate "+
          "ORDER BY destinationgroups.name ASC, destinationgroups.desttype ASC"
    end

    res = ActiveRecord::Base.connection.select_all(sql)
    if user.usertype == 'reseller'
      result_on_reseller_select = ActiveRecord::Base.connection.select_all(reseller_select)
    end

    if res != []
      csv_string << "number#{sep}accounting_number#{sep}country#{sep}type#{sep}rate#{sep}calls#{sep}billsec#{sep}price (#{dc})"
    end

    res.each { |result|

      country = (not result['to_did'].to_s.blank?) ? _('Calls_To_Dids') : result['dg_name']
      type = result['dg_type']
      calls = result['calls']
      billsec = result['billsec']
      rate = result['user_rate']
      price = result['price']
      csv_string << "#{invoice.number.to_s}#{sep}#{user.accounting_number.to_s.blank? ? ' ' : user.accounting_number.to_s}#{sep}#{country}#{sep}#{type}#{sep}#{rate}#{sep}#{calls}#{sep}#{billsec}#{sep}#{nice_number(price).to_s.gsub(".", dec).to_s}"
    }

    params[:email_or_not] ? req_user = user : req_user = current_user

    if user.usertype == 'reseller' and result_on_reseller_select
      csv_string << "\n" + _('Calls_from_users') + ":"
      csv_string << "#{_('DID')}#{sep}#{_('Calls')}#{sep}#{_('Total_time')}#{sep}#{_('Price')}(#{dc})"
      result_on_reseller_select.each { |result|
        csv_string << "#{hide_dst_for_user(req_user, "csv", result["dst"].to_s)}#{sep}#{result["count_calls"].to_s}#{sep}#{invoice_nice_time(result["sum_billsec"], min_type)}#{sep}#{nice_number(result['price']).to_s.gsub(".", dec).to_s}"
      }
    end

    prepaid, prep = invoice_type(invoice, user)

    filename = invoice.filename(prep, 'csv', nil, dc)
    if params[:email_or_not]
      return csv_string.join("\n")
    else
      if params[:test].to_i == 1
        render :text => (["Filename: #{filename}"] + csv_string).join("\n")
      else
        send_data(csv_string.join("\n"), :type => 'text/csv; charset=utf-8; header=present', :filename => filename)
      end
    end
  end

  def generate_invoice_destinations_csv
    invoice = Invoice.where(:id => params[:id]).includes([:tax, :user]).first

    unless invoice
      flash[:notice] = _('Invoice_was_not_found')
      redirect_to :root and return false
    end

    idetails = invoice.invoicedetails
    first_idetail = idetails.first
    user = invoice.user
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[5] == 64)

    if not_authorized_generate_pdf_or_csv(user, status) == 1
      redirect_to :root and return false
    end

    # Hide from prepaid manual payments
    if invoice.invoice_type.downcase == 'prepaid' and first_idetail and first_idetail.name == 'Manual Payment'
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to :root and return false
    end

    dc, ex = manage_exchange_rates(invoice)

    sep, dec = user.csv_params
    owner = invoice.user.owner_id
    prepaid = (invoice.invoice_type.to_s == 'prepaid' and owner == 0) ? 'Prepaid_' : ''

    billsec_cond = Confline.get_value("Invoice_user_billsec_show", owner).to_i == 1 ? 'user_billsec' : 'billsec'
    up, rp, pp = user.get_price_calculation_sqls
    user_price = SqlExport.replace_price(up, {:ex => ex})

    csv_string = ["Invoice NO.:#{sep} #{invoice.number.to_s}"]

    csv_string << ''
    csv_string << "Invoice Date:#{sep} #{nice_date(invoice.period_start, 0)} - #{nice_date(invoice.period_end, 0)}"
    csv_string << ''
    csv_string << "Due Date:#{sep} #{nice_date(invoice.issue_date, 0)}"
    csv_string << ''
    csv_string << ''

    sub = 0
    idetails.each { |id|
      if id.name != 'Calls' and id.name != _('Calls_To_Dids')
        sub = 1
      end
    }


    if idetails

      if sub.to_i == 1
        csv_string << "services#{sep}price\n"
      end

      idetails.each { |id|
        if id.name != 'Calls' #and id.name != _('Calls_To_Dids')

          @iprice = id.price
          if id.invdet_type > 0
            if id.quantity
              qt = id.quantity
              tp = qt * id.converted_price(ex) if id.converted_price(ex)
            else
              qt = ''
              tp = id.converted_price(ex)
            end
            csv_string << "#{nice_inv_name(id.name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
          elsif id.name == _('Did_owner_cost')
            qt = id.quantity
            tp = id.converted_price(ex) if id.converted_price(ex)
            csv_string << "#{nice_inv_name(id.name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
          elsif id.name == _('Calls_To_Dids')
            qt = id.quantity
            tp = id.converted_price(ex)
            csv_string << "#{nice_inv_name(id.name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
          elsif id.name == _('SMS')
            qt = id.quantity
            tp = id.converted_price(ex)
            csv_string << "#{nice_inv_name(id.name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
          end
        end
      }
    end
    csv_string << ''

    csv_string << _('Minimal_Charge_for_Calls') + " (#{dc})" + sep + nice_number(user.converted_minimal_charge(ex).to_d) if user.minimal_charge_enabled?

    csv_string << ''


    show_zero_calls = user.invoice_zero_calls.to_i
    if show_zero_calls == 0
      zero_calls_sql = " AND #{up} > 0 "
    else
      zero_calls_sql = ''
    end


    sql= "SELECT destinations.id, destinations.prefix as 'prefix', dir.name as 'country', destinations.name as 'dg_name', destinations.subcode as 'dg_type', MAX(#{SqlExport.replace_price('calls.user_rate', {:ex => ex})}) as 'rate', sum(IF(DISPOSITION='ANSWERED',1,0)) AS 'answered', Count(*) as 'all_calls', SUM(IF(DISPOSITION='ANSWERED',calls.#{billsec_cond},0)) as 'billsec', SUM(IF(DISPOSITION='ANSWERED',#{SqlExport.replace_price(pp, {:ex => ex})},0)) as 'selfcost', SUM(IF(DISPOSITION='ANSWERED',#{user_price},0)) as 'price'  FROM calls
JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id)
LEFT JOIN destinations ON (destinations.prefix = calls.prefix)
    LEFT JOIN directions as dir ON (destinations.direction_code = dir.code)
#{SqlExport.left_join_reseler_providers_to_calls_sql}
    where calls.card_id = 0 AND devices.user_id = '#{user.id}' and calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' #{zero_calls_sql} AND LENGTH(calls.prefix) > 0
    group by destinations.id, calls.user_rate ORDER BY destinations.direction_code ASC, destinations.id ASC"

    # my_debug sql
    res = ActiveRecord::Base.connection.select_all(sql)

    if res != []
      csv_string << "country#{sep}rate#{sep}ASR %#{sep}calls#{sep}ACD#{sep}billsec#{sep}Sum"
    end
    res.each { |result|
      id = result['id'].to_s
      country = result['country'].to_s
      type = result['dg_type'].to_s
      rate = result['rate'].to_s
      calls = result['answered'].to_s
      prefix = result['prefix'].to_s
      billsec = result['billsec'].to_s
      if result['answered'].to_s.to_i > 0
        asr = (result['answered'].to_d / result['all_calls'].to_d) * 100
        acd = (result['billsec'].to_d / result['answered'].to_d).to_d
      else
        asr = 0
        acd = 0
      end
      price = result['price'].to_s
      if result['answered'].to_s.to_i > 0
        if idetails
          csv_string << "#{country.to_s + ' ' + type.to_s + ' ' + prefix.to_s }#{sep}#{rate.to_s.gsub(".", dec).to_s}#{sep}#{nice_number(asr).to_s.gsub(".", dec).to_s}#{sep}#{calls.to_i}#{sep}#{nice_number(acd).to_s.gsub(".", dec).to_s}#{sep}#{billsec.to_i}#{sep}#{nice_number(price).to_s.gsub(".", dec).to_s}"
        else
          csv_string << "#{country + ' ' + type.to_s + ' ' + prefix.to_s }#{sep}#{rate.to_s.gsub(".", dec).to_s}#{sep}#{nice_number(asr).to_s.gsub(".", dec).to_s}#{sep}#{calls.to_i}#{sep}#{nice_number(acd).to_s.gsub(".", dec).to_s}#{sep}#{billsec.to_i}#{sep}#{nice_number(price).to_s.gsub(".", dec).to_s}"
        end
      end
    }
    prepaid, prep = invoice_type(invoice, user)

    filename = invoice.filename(prep, 'csv', nil, dc)

    if  params[:email_or_not]
      return csv_string.join("\n")
    else
      if params[:test].to_i == 1
        render :text => (["Filename: #{filename}"] + csv_string).join("\n")
      else
        send_data(csv_string.join("\n"), :type => 'text/csv; charset=utf-8; header=present', :filename => filename)
      end
    end
  end

  def generate_invoice_by_cid_csv
    invoice = Invoice.where(:id => params[:id]).includes([:tax, :user]).first

    unless invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to :root and return false
    end

    # Hide from prepaid manual payments
    if invoice.invoice_type.downcase == 'prepaid'  && invoice.invoicedetails.first.try(:name).to_s == 'Manual Payment'
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to :root and return false
    end

    dc = current_user.currency.name
    user = invoice.user
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[6] == 128)

    if not_authorized_generate_pdf_or_csv(user, status) == 1
      redirect_to :root and return false
    end

    dc, ex = manage_exchange_rates(invoice)

    sep, dec = user.csv_params

    up, rp, pp = user.get_price_calculation_sqls
    zero_calls_sql = user.invoice_zero_calls_sql
    user_price = SqlExport.replace_price(up, {:ex => ex})
    csv_s = []
    # remove cards conditions, calls.did_inc_price conditions
    # sql = "SELECT calls.src, SUM(#{user_price}) as 'price', COUNT(calls.id) AS calls_size FROM calls JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE devices.user_id = #{user.id} AND calls.card_id = 0 AND calls.did_inc_price > 0 AND calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' AND calls.disposition = 'ANSWERED' AND billsec > 0 #{zero_calls_sql} GROUP BY calls.src;"
    sql = "SELECT calls.src,
                  SUM(#{user_price}) as 'price',
                  COUNT(calls.id) AS calls_size,
                  CONCAT(devices.device_type, '/', devices.extension, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(devices.callerid, '<', -1), '>', 1), ')') AS nice_src_device
           FROM calls
           JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) #{SqlExport.left_join_reseler_providers_to_calls_sql}
           WHERE calls.card_id = 0 AND devices.user_id = #{user.id} AND calls.calldate
                 BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59'
                 AND calls.disposition = 'ANSWERED' AND billsec > 0 #{zero_calls_sql} GROUP BY calls.src;"

    cids = Call.find_by_sql(sql)

    if cids != []
      csv_s<< "CallerID/Device details#{sep}price(#{dc})#{sep}calls#{sep}"

      cids.each { |ci|
        csv_s << "#{ci.src} / #{ci.nice_src_device}" + sep.to_s + ci.price.to_d.to_s.gsub(".", dec).to_s + sep + ci.calls_size.to_i.to_s
      }
    end

    csv_string = csv_s.join("\n")
    prepaid, prep = invoice_type(invoice, user)

    filename = invoice.filename(prep , 'csv', nil, dc)
    if  params[:email_or_not]
      return csv_string
    else
      if params[:test].to_i == 1
        render :text => "Filename: #{filename}" + csv_string
      else
        send_data(csv_string, :type => 'text/csv; charset=utf-8; header=present', :filename => filename)
      end
    end
  end

  def change_session_flag
    session[:invoices_is_generating] = 0
    redirect_to :root
  end

  def invoices_recalculation
    @username = params[:s_user] || ''
    @user_id = params[:s_user_id] || -2
    @page_title = _('Recalculate_invoices')
    @page_icon = 'application_go.png'
    @type = params[:type] || 'postpaid'
    @post = 1
    @pre = 0
  end

  def invoices_recalculation_status
    @page_title = _('Recalculate_invoices_status')
    @page_icon = 'application_go.png'

    change_date

    unless params[:invoice]
      dont_be_so_smart
      redirect_to :root and return false
    end
    type = params[:invoice][:type]
    type = 'postpaid' if !(['postpaid', 'prepaid', 'user'].include?(type))

    cond = Confline.get_value("Invoice_allow_recalculate_after_send").to_i == 1 ? '' : ' AND sent_manually = 0 AND sent_email = 0 '
    if type == 'user'
      @invoices = Invoice.includes([:user]).where(["paid = 0 #{cond} AND user_id = ? AND period_start >= ? AND period_end <= ? AND users.owner_id = ?", params[:s_user_id], session_from_date, session_till_date, correct_owner_id])
    else
      @invoices = Invoice.includes([:user]).where(["paid = 0 #{cond} AND invoice_type = ? AND period_start >= ? AND period_end <= ? AND users.owner_id = ?", type, session_from_date, session_till_date, correct_owner_id])
    end

    @period_start = session_from_date
    @period_end = session_till_date

    if @invoices and @invoices.size.to_i > 0
      @recalculated_number_of_invoices = 0
      @invoices.each { |invoice|
        if !invoice.paid?
          regenerate_invoice_price(invoice)
          @recalculated_number_of_invoices+=1
        end
      }
      flash[:status] = _('Invoices_recalculated') + ': ' + @recalculated_number_of_invoices.to_s
      redirect_to :action => :invoices and return false
    else
      flash[:notice] = _('No_invoice_found_to_recalculate')
      redirect_to action: :invoices_recalculation, s_user: params[:s_user], s_user_id: params[:s_user_id], type: type and return false
    end

  end

  def financial_statements
    @page_title = _('Financial_statements')
    @page_icon = 'view.png'

    @show_currency_selector = 1
    @currency = session[:show_currency]

    params[:clear] ? change_date_to_present : change_date
    @issue_from_date = Date.parse(session_from_date)
    @issue_till_date = Date.parse(session_till_date)

    session_options = session[:accounting_statement_options]
    @valid_status_values = ['paid', 'unpaid', 'all']
    @user_id = financial_statements_user_id(session_options)
    @status = financial_statements_status(session_options)
    @options = {:s_user_id => @user_id, s_user: params[:s_user], :status => @status}


    @show_search = true

    if admin? or accountant?
      owner_id = 0
    else
      owner_id = current_user_id
    end
    ordinary_user = (current_user.usertype == 'user')
    credit_notes = convert_to_user_currency(CreditNote.financial_statements(owner_id, @user_id, @status, @issue_from_date, @issue_till_date, ordinary_user))
    if @status != 'unpaid'
      @paid_credit_note = get_financial_statement(credit_notes, 'paid')
    end
    if @status != 'paid'
      @unpaid_credit_note = get_financial_statement(credit_notes, 'unpaid')
    end

    # invoces do not have price with vat calculated so this method returns information
    # abount paid and unpaid invoices, we just have to convert currency FROM USER
    # CURRENCY TO USER'S SELECTED CURRENCY
    currency_name = current_user.currency.name
    @paid_invoice, @unpaid_invoice = Invoice.financial_statements(owner_id, @user_id, @status, @issue_from_date, @issue_till_date, ordinary_user)
    @paid_invoice.price = @paid_invoice.price.to_d * count_exchange_rate(currency_name, session[:show_currency])
    @paid_invoice.price_with_vat = @paid_invoice.price_with_vat.to_d * count_exchange_rate(currency_name, session[:show_currency])
    @unpaid_invoice.price = @unpaid_invoice.price.to_d * count_exchange_rate(currency_name, session[:show_currency])
    @unpaid_invoice.price_with_vat = @unpaid_invoice.price_with_vat.to_d * count_exchange_rate(currency_name, session[:show_currency])

    # there is no need to convert to user currency because method does it by itself
    @paid_payment, @unpaid_payment = Payment.financial_statements(owner_id, @user_id, @status, @issue_from_date, @issue_till_date, ordinary_user, session[:show_currency])

    # TODO rename to session options
    session[:accounting_statement_options] = @options
  end

  def not_authorized_generate_pdf_or_csv(user, status)
    err = 1
      # its user and he has permission to generate this pdf/csv
    if !(((user.id == session[:user_id]) && status) ||
      # its users owner
      (user.owner_id == session[:user_id]) ||
      # its accountant and pdf/csv belongs to admins user
      (accountant? && (user.owner_id == 0)))
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')

      if user.id != session[:user_id]
        flash[:notice] = _('Invoice_not_found')
      end
    else
      err = 0
    end

    return err
  end

  private


  # Based on what params user selected or if they were not passed based on params saved in session
  # return user_id, that should be filtered for financial statements. if user passed clear as param
  # return nil

  # *Params*
  # +session_options+ hash including :user_id, might be nil

  # *Return*
  # +user_id+ integer or nil
  def financial_statements_user_id(session_options)
    if current_user.usertype == 'user'
      user_id = current_user_id
    elsif params[:s_user_id] and not params[:clear]
      user_id = params[:s_user_id] || 'all'
      user_id = -1 if params[:s_user].present? && params[:s_user_id].to_i == -2
    elsif session_options and session_options[:s_user_id] and not params[:clear]
      user_id = session_options[:s_user_id]
    else
      user_id = nil
    end
    user_id
  end

=begin
  Based on what params user selected or if they were not passed based params saved in session
  return status, that should be filtered for financial statements.

  *Params*
  +session_options+ hash including :status, might be nil

  *Returns*
  +status+ - string, one of valid_status_values, by default 'all'
=end
  def financial_statements_status(session_options)
    if @valid_status_values.include? params[:status] and not params[:clear]
      status = params[:status]
    elsif session_options and @valid_status_values.include? session_options[:status] and not params[:clear]
      status = session_options[:status]
    else
      status = 'all'
    end
  end

=begin
  convert prices in statements from default system currency to
  currency that is set in session

  *Params*
  +statement+ iterable of financial stement data(they rices should be in system currency)

  *Returns*
  +statement+ same object that was passed only it's prices recalculated in user selected currency
=end
  def convert_to_user_currency(statements)
    exchange_rate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])
    statements.each { |statement|
      statement.price = statement.price.to_d * exchange_rate
      statement.price_with_vat = statement.price_with_vat.to_d * exchange_rate
    }
    return statements
  end

=begin
  financial data returned by invoice, credit notes or payments may lack some information,
  this method's purpose is to retrieve information from part of financial statement(let's
  say financial stetement is devided in three parts: credit note, invoice and payments) about
  paid/unpaid financial data. if there is no such data return default, default meaning that
  there is no paid/unpaid part, so it's count and price is 0.
  TODO should rename valiable names, cause they dont make much sense. maybe event method name
  should be renamed
  Note that price and price including taxes will be converted from default system currency to
  user selected

  *Params*
  +statement+ - part of financial statement
  +status+ - whatever valid status might have the statement

  *Returns*
  +paid/unpaid_statement+ if there is such statement that satisfies condition(status) returns it,
   else returns default statement.
=end
  def get_financial_statement(statements, status)
    statements.each { |statement|
      if statement.status == status
        return statement
      end
    }
    #Return default financial data if required stetement was not found
    Struct.new('We', :count, :price, :price_with_vat, :status)
    return Struct::We.new(0, 0, 0, status)
  end

=begin
  Only one who may not have permissions to view financial statements
  is accountant. If he does not have 'can see finances', 'invoices manage'
  and 'manage payments' permissions to read he cannot view financial statements.
  In any other case everyone can view treyr user's invoices, credit notes and payments.
=end
  def can_view_financial_statements?
    if accountant? and (not current_user.accountant_allow_read('can_see_finances') or not current_user.accountant_allow_read('payments_manage') or not current_user.acoutnant_alllow_read('invoices_manage'))
      return false
    else
      return true
    end
  end

  def financial_statements_filter
    if not can_view_financial_statement?
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def subscription_period(sub, period_start, period_end)
    activation_start = sub.activation_start
    activation_end = sub.activation_end

    if activation_start < period_start
      use_start = period_start
    else
      use_start = activation_start
    end
    # till which day used?
    if activation_end.blank? or activation_end > period_end
      use_end = period_end
    else
      use_end = activation_end
    end
    return use_start.to_date, use_end.to_date
  end

  def call_details_for_user(user, period_start_with_time, period_end_with_time, use_index = 0)
    MorLog.my_debug("\nChecking user with id: #{user.id}, name: #{nice_user(user)}, type: #{user.usertype}", 1)

    use_index = 0
    MorLog.my_debug("Search with index ? : #{use_index}", 1)
    # --- Outgoing calls ---

    # find own outgoing (made by this user) calls stats (count and sum price)
    outgoing_calls,
    outgoing_calls_price = user.own_outgoing_calls_stats_in_period(period_start_with_time,
                                                                   period_end_with_time,
                                                                   use_index)
    MorLog.my_debug("  Outgoing calls: #{outgoing_calls}, for price: #{outgoing_calls_price}", 1)

    # find own outgoing (made by this user) calls stats (count and sum price) of calls to dids
    outgoing_calls_to_dids,
    outgoing_calls_price_to_dids = user.own_outgoing_calls_stats_to_dids_in_period(period_start_with_time,
                                                                                   period_end_with_time,
                                                                                   use_index)
    MorLog.my_debug("  Outgoing calls to dids: #{outgoing_calls_to_dids}, for price: #{outgoing_calls_price_to_dids}", 1)

    # find users outgoing (made by this resellers users) calls stats (count and sum price)
    if user.is_reseller?
      outgoing_calls_by_users,
      outgoing_calls_by_users_price,
      incoming_calls_by_users,
      incoming_calls_by_users_price = user.users_outgoing_calls_stats_in_period(period_start_with_time,
                                                                                period_end_with_time,
                                                                                use_index)
      MorLog.my_debug("  Outgoing calls by users: #{outgoing_calls_by_users}, for price: #{outgoing_calls_by_users_price}", 1)
      MorLog.my_debug("  Incoming calls by users: #{outgoing_calls_by_users}, for price: #{outgoing_calls_by_users_price}", 1)
    else
      outgoing_calls_by_users = 0
      outgoing_calls_by_users_price = 0
      incoming_calls_by_users = 0
      incoming_calls_by_users_price = 0
    end

    # --- Incoming calls ---

    incoming_received_calls,
    incoming_received_calls_price = user.incoming_received_calls_stats_in_period(period_start_with_time,
                                                                                 period_end_with_time,
                                                                                 use_index)
    MorLog.my_debug("  Incoming RECEIVED calls: #{incoming_received_calls}, for price: #{incoming_received_calls_price}", 1)

    incoming_made_calls,
    incoming_made_calls_price = user.incoming_made_calls_stats_in_period(period_start_with_time,
                                                                         period_end_with_time,
                                                                         use_index)
    MorLog.my_debug("  Incoming MADE calls: #{incoming_made_calls}, for price: #{incoming_made_calls_price}", 1)

    return incoming_received_calls, incoming_received_calls_price, incoming_made_calls, incoming_made_calls_price, outgoing_calls_price, outgoing_calls_by_users_price, outgoing_calls, outgoing_calls_price, outgoing_calls_by_users, incoming_calls_by_users, incoming_calls_by_users_price, outgoing_calls_to_dids, outgoing_calls_price_to_dids
  end

  def regenerate_invoice_price(invoice)

    user = invoice.user
    show_zero_calls = user.invoice_zero_calls.to_i.equal?(1) ? true : false
    invoice.invoicedetails.destroy_all # we'll add new details

    nc = nice_invoice_number_digits(invoice.invoice_type)

    period_start_with_time, period_end_with_time = invoice.period_start.to_time, invoice.period_end.to_time.change(:hour => 23, :min => 59, :sec => 59, :usec => 999999.999)
    period_start = invoice.period_start.to_time
    period_end = invoice.period_end.to_time.change(:hour => 23, :min => 59, :sec => 59, :usec => 999999.999)


    ind_ex = ActiveRecord::Base.connection.select_all("SHOW INDEX FROM calls")

    use_index = 0
    ind_ex.to_yaml
    ind_ex.each { |ie| use_index = 1; use_index if ie[:key_name].to_s == 'calldate' } if ind_ex

    incoming_received_calls, incoming_received_calls_price, incoming_made_calls, incoming_made_calls_price, outgoing_calls_price, outgoing_calls_by_users_price, outgoing_calls, outgoing_calls_price, outgoing_calls_by_users, incoming_calls_by_users, incoming_calls_by_users_price, outgoing_calls_to_dids, outgoing_calls_price_to_dids = call_details_for_user(user, period_start_with_time.strftime("%Y-%m-%d %H:%M:%S"), period_end_with_time.strftime("%Y-%m-%d %H:%M:%S"), use_index)

    # find subscriptions for user in period
    subscriptions = user.subscriptions_in_period(period_start_with_time, period_end_with_time, 'invoices')
    total_subscriptions = 0
    total_subscriptions = subscriptions.size if subscriptions
    MorLog.my_debug("  Total subscriptions this period: #{total_subscriptions}")

    # find sms for user in period
    total_sms, total_sms_price = SmsMessage.user_sms_in_period(period_start_with_time, period_end_with_time, user)

    # -- Minimal charge -----
    # Minimal charge is counted for whole month(s), but only for postpaid users. To get a
    # better understang of what is a 'whole month' look at month_difference method
    minimal_charge_amount = 0
    if user.postpaid?
      if user.add_on_minimal_charge? period_end
        if user.minimal_charge_start_at < period_start
          month_diff = ApplicationController.month_difference(period_start, period_end)
        else
          month_diff = ApplicationController.month_difference(user.minimal_charge_start_at, period_end)
        end
        minimal_charge_amount = month_diff * user.minimal_charge
      end
    end

    # check if we should generate invoice
    if (outgoing_calls_price > 0) or
        (outgoing_calls_by_users_price + incoming_calls_by_users_price > 0) or
        (incoming_received_calls_price > 0) or
        (incoming_made_calls_price > 0) or
        (total_subscriptions > 0) or
        (minimal_charge_amount > 0) or
        show_zero_calls
      MorLog.my_debug("    Generating invoice....")

      tax = user.get_tax.dup
      tax.save
      price = 0

      # --- add own outgoing calls ---
      if (show_zero_calls or (outgoing_calls_price > 0)) and outgoing_calls > 0
        invoice.invoicedetails.create(:name => _('Calls'), :price => invoice.nice_invoice_number(outgoing_calls_price.to_d, {:nc=>nc, :apply_rounding=>true}), :quantity => outgoing_calls, :invdet_type => 0)
        price += invoice.nice_invoice_number(outgoing_calls_price.to_d, {:nc=>nc, :apply_rounding=>true}).to_d
      end

      if (show_zero_calls or (outgoing_calls_to_dids > 0)) and outgoing_calls_to_dids > 0
        invoice.invoicedetails.create(:name => _('Calls_To_Dids'), :price => invoice.nice_invoice_number(outgoing_calls_price_to_dids.to_d, {:nc=>nc, :apply_rounding=>true}), :quantity => outgoing_calls_to_dids, :invdet_type => 0)
        price += invoice.nice_invoice_number(outgoing_calls_price_to_dids.to_d, {:nc=>nc, :apply_rounding=>true}).to_d
      end

      # --- add resellers users outgoing calls ---
      if (show_zero_calls or (outgoing_calls_by_users_price > 0)) and outgoing_calls_by_users > 0
        invoice.invoicedetails.create(:name => _('Calls_from_users'), :price => invoice.nice_invoice_number(outgoing_calls_by_users_price.to_d, {:nc=>nc, :apply_rounding=>true}), :quantity => outgoing_calls_by_users, :invdet_type => 0)
        price += invoice.nice_invoice_number(outgoing_calls_by_users_price.to_d, {:nc=>nc, :apply_rounding=>true}).to_d
      end

      # --- add own received incoming calls ---
      if ['admin', 'accountant', 'reseller'].include?(session[:usertype])
        if (incoming_received_calls_price > 0)
          invoice.invoicedetails.create(:name => _('Did_owner_cost'), :price => incoming_received_calls_price.to_d, :quantity => incoming_received_calls, :invdet_type => 0)
          price += incoming_received_calls_price.to_d
        elsif (incoming_calls_by_users_price > 0)
          invoice.invoicedetails.create(:name => _('Did_owner_cost'), :price => incoming_calls_by_users_price.to_d, :quantity => incoming_calls_by_users, :invdet_type => 0)
          price += incoming_calls_by_users_price.to_d
        end
      end

      if total_sms.to_i > 0
        invoice.invoicedetails.create(:name => _('SMS'), :price => invoice.nice_invoice_number(total_sms_price.to_d, {nc: nc, apply_rounding: true}), :quantity => total_sms, :invdet_type => 0)
        price += invoice.nice_invoice_number(total_sms_price.to_d, {nc: nc, apply_rounding: true}).to_d
      end

      #      # --- add own made incoming calls ---
      #      if (incoming_made_calls_price > 0)
      #        invoice.invoicedetails.create(:name => _('Incoming_made_calls'), :price => incoming_made_calls_price.to_d, :quantity => incoming_made_calls, :invdet_type => 0)
      #        price += incoming_made_calls_price.to_d
      #      end

      if user.postpaid?
        # if minimal charge is set for the user. and for this period
        # calculated price is less than minimal charge, then we should recalculate price
        if price < minimal_charge_amount
          price = minimal_charge_amount
        end
      end

      MorLog.my_debug("    Invoice price without subscriptions: #{price.to_s}", 1)

      # nasty hack for Balticom to recalculate invoices/balance - DO NOT USE!!!
      # user.balance -= price
      # user.save

      # --- add subscriptions ---

      subscriptions.each { |sub|

        service = sub.service
        count_subscription = 0

        if service.servicetype == 'flat_rate'
          if sub.no_expire == 1
            if ((period_start.localtime.to_date)..(period_end.localtime.to_date)) === sub.activation_start.to_date
              invd_price = service.read_attribute(:price)
              count_subscription = 1
            end
          else
            start_date, end_date = subscription_period(sub, period_start_with_time, period_end_with_time)
            invd_price = service.read_attribute(:price) * (months_between(start_date.to_date, end_date.to_date)+1)
            count_subscription = 1
          end
        end

        if service.servicetype == 'one_time_fee'
          # one-time-fee subscription only counts once for full price
          if (sub.activation_start >= period_start_with_time and sub.activation_start <= period_end_with_time)
            invd_price = service.read_attribute(:price)
            count_subscription = 1
          end

        end

        if service.servicetype == 'periodic_fee'
          count_subscription = 1

          # from which day used?
          if sub.activation_start < period_start_with_time
            use_start = period_start_with_time
          else
            use_start = sub.activation_start
          end
          # till which day used?
          if sub.activation_end.blank? or sub.activation_end > period_end_with_time
            use_end = period_end_with_time
          else
            use_end = sub.activation_end
          end
          start_date = use_start.to_date
          end_date = use_end.to_date
          days_used = use_end.to_date - use_start.to_date

          if service.periodtype == 'day'
            invd_price = service.read_attribute(:price) * (days_used.to_i + 1)
          elsif service.periodtype == 'month'
            if start_date.month == end_date.month and start_date.year == end_date.year
              total_days = start_date.to_time.end_of_month.day.to_i
              invd_price = service.read_attribute(:price) / total_days * (days_used.to_i + 1)
            else
              invd_price = 0
              if months_between(start_date, end_date) > 1
                # jei daugiau nei 1 menuo. Tarpe yra sveiku menesiu kuriem nereikia papildomai skaiciuoti intervalu
                invd_price += (months_between(start_date, end_date)-1) * service.read_attribute(:price)
              end
              # suskaiciuojam pirmo menesio pabaigos ir antro menesio pradzios datas
              last_day_of_month = start_date.to_time.end_of_month.to_date
              last_day_of_month_on_end_date = end_date.to_time.end_of_month.to_date
              if (start_date.day - end_date.day) == 1
                invd_price += service.read_attribute(:price)
              else
                invd_price += service.read_attribute(:price)/last_day_of_month.day * (last_day_of_month - start_date+1).to_i
                invd_price += service.read_attribute(:price)/last_day_of_month_on_end_date.day * (end_date.day)
              end
            end
          end
        end

        # my_debug("    Invoice Subscriptions price: #{invd_price.to_s}")

        if count_subscription == 1
          invoice.invoicedetails.create(:name => service.name.to_s + " - " + sub.memo.to_s, :price => invoice.nice_invoice_number(invd_price.to_d, {:nc=>nc, :apply_rounding=>true}), :quantity => "1")
          price += invoice.nice_invoice_number(invd_price.to_d, {:nc=>nc, :apply_rounding=>true}).to_d
        end
      }
      invoice.invoice_precision=nc
      invoice.price = invoice.nice_invoice_number(price.to_d, {:nc=>nc, :apply_rounding=>true})
      invoice = invoice.generate_taxes_for_invoice(nice_invoice_number_digits(invoice.invoice_type), 1)
      MorLog.my_debug(" Recalculated Invoice number: #{invoice.number}", 1)
      currency = user.currency
      if currency.present?
        invoice.invoice_exchange_rate = currency.exchange_rate
        invoice.invoice_currency = currency.name
      end
      invoice.save
    end
  end

  def find_invoice
    @invoice = Invoice.where(:id => params[:id]).first

    unless @invoice
      flash[:notice] = _('Invoice_was_not_found')
      redirect_to :controller => :callc, :action => :invoices
    end
  end

  def invoices_order_by(params, options)
    order_by_param_options = nil
    order_by = case params[:order_by].to_s
      when 'user'
        "users.first_name"
      when "number"
        order_by_param_options =  ", number"
        "LENGTH(invoices.number)"
      when "LENGTH(invoices.number)"
        order_by_param_options =  ", number"
        "LENGTH(invoices.number)"
      when 'invoice_type'
        "invoices.invoice_type"
      when 'period_start'
        "invoices.period_start"
      when 'period_end'
        "invoices.period_end"
      when 'issue_date'
        "invoices.issue_date"
      when 'sent_email'
        "invoices.sent_email"
      when 'sent_manually'
        "invoices.sent_manually"
      when 'paid'
        "invoices.paid"
      when "paid_date"
        "invoices.paid_date"
      when 'price'
        "invoices.price"
      else
        options[:order_by] ? options[:order_by] : "users.first_name"
    end

    without = order_by
    order_by = "users.first_name " + (options[:order_desc] == 1 ? 'DESC' : "ASC") + ", users.last_name" if order_by.to_s == "users.first_name"
    order_by += options[:order_desc].to_i == 1 ? ' DESC' : ' ASC'
    if !order_by_param_options.blank?
      order_by += order_by_param_options
      order_by += options[:order_desc].to_i == 1 ? ' DESC' : ' ASC'
    end
    return without, order_by
  end

  def invoice_type(invoice, user)
    if invoice.invoice_type.to_s == 'prepaid' and user.owner_id == 0
      return 'Prepaid_', 'prepaid'
    else
      return '', 'postpaid'
    end
  end

  def manage_exchange_rates(invoice)
    invoice_currency = invoice.invoice_currency
    dc = params[:email_or_not] ? invoice.user.currency.name : session[:show_currency]
    ex = invoice.exchange_rate(session[:default_currency], dc, current_user)

    dc = invoice_currency if (invoice.user_id == current_user.id.to_i) && invoice_currency.present?
    return dc, ex
  end
end
