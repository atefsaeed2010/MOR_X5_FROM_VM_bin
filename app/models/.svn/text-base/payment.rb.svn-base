# -*- encoding : utf-8 -*-
class Payment < ActiveRecord::Base
  attr_protected

  belongs_to :user, -> { includes([:tax]) }
  belongs_to :provider
  has_many :cc_invoices

  after_create { |record| Action.add_action_hash(User.current, {:action => record.paymenttype.to_s == 'manual' ? 'manual_payment_created' : 'card_payment_created', :data => record.user_id, :data2 => record.amount, :data3 => record.currency, :target_id => record.id, :target_type => 'Payment'}) if record.paymenttype.to_s == 'manual' or record.paymenttype.to_s == 'Card' }

  after_destroy { |record| Action.add_action_hash(User.current, {:action=>'manual_payment_deleted', :data=>record.user_id, :data2=>record.amount, :data3=>record.currency, :target_id=>record.id, :target_type=>'Payment'}) if record.paymenttype.to_s == 'manual' }


  def invoice
    Invoice.where(["invoices.payment_id = ?", self.id]).first
  end

  def voucher
    Voucher.includes([:tax]).where(["vouchers.payment_id = ?", self.id]).first
  end

  def count_exchange_rate(curr1, curr2)
    if curr1 != curr2
      return Currency.count_exchange_rate(curr1, curr2)
    else
      return 1
    end
  end

  def cards
    Card.where(["id = ?", self.user_id]).order("#{self.number}").all
  end

  def payment_amount
    user = self.user
    pa = self.amount
    if self.paymenttype == "manual" and user
      pa = self.tax ? self.amount.to_d - self.tax.to_d : user.get_tax.count_amount_without_tax(self.amount.to_d)
    end
    pa = self.gross if ["webmoney", "cyberplat", "linkpoint", "voucher", "ouroboros", "subscription", "paypal", "paypal_fee"].include?(self.paymenttype.to_s)
    pa = self.amount if ["invoice"].include?(self.paymenttype.to_s)
    pa
  end

  def payment_amount_with_vat(nice_number_digits)
    if self.tax && !["webmoney", "cyberplat", "linkpoint", "voucher", "ouroboros", "subscription", "invoice", "paypal", 'manual'].include?(self.paymenttype)
      return self.amount.to_f + self.tax.to_f
    else
      if self.paymenttype == "invoice" and self.invoice
        return self.invoice.price_with_tax
      else
        return self.amount
      end
    end
  end

  def amount_to_system_currency
    self.amount * Currency.count_exchange_rate(self.currency, Currency.get_default)
  end

  def Payment.create_cards_action(order)

    if not payment = Payment.where(["transaction_id = ?", order.transaction_id]).first
      payment = Payment.new
    end
    payment.shipped_at = order.shipped_at
    payment.completed = order.completed
    payment.paymenttype = 'paypal'
    payment.currency = order.currency
    payment.fee = order.fee
    payment.amount = order.amount
    payment.gross = order.gross.to_d
    payment.transaction_id = order.transaction_id
    payment.first_name = order.first_name
    payment.last_name = order.last_name
    payment.payer_email = order.payer_email
    payment.residence_country = order.residence_country
    payment.payer_status = order.payer_status
    payment.tax = order.tax
    payment.date_added = Time.now if not payment.date_added
    payment.save
    payment
  end

  def Payment.subscription_payment(user, amount)
    amount = amount.to_d * -1
    if amount != 0
      taxw = user.get_tax
      currency = Currency.get_default
      payment = Payment.new(
          :paymenttype => "subscription",
          :amount => user.get_tax.apply_tax(amount),
          :shipped_at => Time.now,
          :date_added => Time.now,
          :completed => 1,
          :gross => amount,
          :tax => user.get_tax.count_tax_amount(amount),
          :user_id => user.id,
          :first_name => user.first_name,
          :last_name => user.last_name,
          :owner_id => user.owner_id)
      payment.currency = currency.name if currency
      payment.email = user.address.email if user.address
      return payment.save
    else
      return false
    end
  end

  def Payment.add_for_card(card, amount, currency = nil, owner_id = nil, description='')
    Payment.add_global({:paymenttype=>'Card', :tax => card.cardgroup.get_tax.count_tax_amount(amount), :currency => currency ? currency : card.cardgroup.tell_balance_in_currency, :user_id=>card.id, :card=>1, :amount=>amount, :owner_id => owner_id ? owner_id : card.cardgroup.owner_id, :description=>description})
  end

  def Payment.add_global(details= {})
    Payment.create({:shipped_at=>Time.now, :date_added=>Time.now, :completed=>1,:currency=>Currency.get_default}.merge(details))
  end

  def Payment.create_for_user(user, params = {})
    user = User.where(["users.id = ?", user]).first if user.class == Fixnum
    if user
      return Payment.new({
                             :user_id => user.id,
                             :first_name => user.first_name,
                             :last_name => user.last_name,
                             :date_added => Time.now(),
                             :owner_id => user.owner.id
                         }.merge(params))
    else
      return false
    end
  end

  def paypal_refund_payment(notify, user)
    # create new reverse payment
    MorLog.my_debug('Paypal reverse', true)
    refund_payment = self.dup
    refund_payment.fee = notify.fee.to_d
    refund_payment.amount = notify.gross.to_d
    refund_payment.gross = notify.gross.to_d - notify.tax.to_d
    refund_payment.tax = notify.tax.to_d
    refund_payment.currency = notify.currency.to_s
    refund_payment.transaction_id = notify.transaction_id.to_s
    refund_payment.first_name = notify.first_name.to_s
    refund_payment.last_name = notify.last_name.to_s
    refund_payment.payer_email = notify.payer_email.to_s
    refund_payment.residence_country = notify.residence_country.to_s
    refund_payment.payer_status = notify.payer_status.to_s
    refund_payment.date_added = Time.now
    refund_payment.pending_reason = notify.pending_reason.to_s
    refund_payment.pending_reason = "Denied" if notify.status == "Denied"
    refund_payment.pending_reason = "Reversed" if notify.reversed?
    refund_payment.paymenttype = "paypal_reversed"
    refund_payment.save
    if completed.to_i == 0
      # payment_1 is not addet to user balance , preverse_paymnet is not subtracted
      MorLog.my_debug("Payment #{refund_payment.id} is not reversed, becouse Paypal payment #{id} is not completed ", true)
      Action.add_action_hash(user, {:action => "Paypal Reverse Failed", :data => "Payment #{id} is not confirmed by admin", :data2 => id, :data3 => refund_payment.id})
    else
      # payment_1 is addet to user balance , subtracte reverse amount
      refund_payment.completed = 1
      user.balance += sprintf("%.2f", refund_payment.gross * Currency.count_exchange_rate(refund_payment.currency, Currency.find(1).name)).to_d
      if refund_payment.fee.to_d != 0.0 and Confline.get_value("PayPal_User_Pays_Transfer_Fee", 0).to_i == 1
        user.balance -= sprintf("%.2f", refund_payment.fee * Currency.count_exchange_rate(refund_payment.currency, Currency.find(1).name)).to_d
        fee_payment = refund_payment.dup
        fee_payment.paymenttype = "paypal_reversed_fee"
        fee_payment.fee = 0
        fee_payment.shipped_at = Time.now
        fee_payment.tax = 0
        fee_payment.completed = 1
        fee_payment.pending_reason = "Completed"
        fee_payment.amount = refund_payment.fee*-1
        fee_payment.gross = refund_payment.fee*-1
        fee_payment.save
        Action.add_action_hash(user, {:action => "Paypal Reverse", :data => "Payment #{id} is reversed, #{refund_payment.gross}", :data2 => id, :data3 => refund_payment.id})
      end
      user.save
      refund_payment.save
    end
  end

=begin
  Destroy single credit note associated with payment
=end
  def destroy_credit_note
    note = CreditNote.where(["payment_id = #{self.id}"]).first
    if note
      note.destroy
    end
  end

=begin
  All payments for finacial data. excluding payment that are generated for calling cards.

  *Params*
  +owner_id+ owner of users that the user is interested in, but might be nil if
     current user if ordinary user
  +user_id+ user that has invoices generated for him, might be nil if admin,
     reseller or accountatn is not interested i certain user, but interested in all his users.
     BUT IF we are generating financial statemens for ordinary users, they cannot see other users
     information and must supply theyr own id
  +status+ valid status parameter would be 'paid' 'unpaid' or 'all', might be nil
     in that case all statuses would be selected
  +from_date, till_date+ dates as strings
  +ordinary_user+ if user is of type 'user' there is no need to join users table, but user_id mus
     be specified.
  +currency_name+ since payments may be in any currency, one must specify currency name that he
     wants payment prices to be represented.

  *Returns*
  +array of MockPayment instances+
=end
  def self.financial_statements(owner_id, user_id, status, from_date, till_date, ordinary_user, currency_name)
    condition = ['payments.card = 0']
    condition << ["payments.date_added BETWEEN '#{from_date} 00:00:00' AND '#{till_date} 23:59:59'"]
    if not ordinary_user
      condition << "payments.owner_id = #{owner_id}"
    end
    condition << "user_id = #{user_id}" if user_id.present? && user_id != 'all' && user_id.to_i != -2
    if status != 'all' and ['paid', 'unpaid'].include? status
      condition << "payments.completed = #{status == 'paid' ? 1 : 0}"
    end

    return recalculate_payments(Payment.includes(:user).where(condition.join(" AND\n")).references(:user).all, currency_name)
  end

=begin
  Since to callculate payment price, price with taxes and to convert it to users currency
  we need every payment and can not group it so that database server would just sum up prices,
  like we did with credit notes or invoices. this is the method to do everyting:
  1. count price of payment in specified currency
  2. count price with tax in specified currency
  3. group all payments by theyr status
  4. sum it all up
  5. return information about all paid and unpaid payments.

  *Params*
  +payments+ iterable of payment instances

  *Return*
  +array of payment data+ information about paid and unpaid payments
=end
  def self.recalculate_payments(payments, currency_name)
    Struct.new('MockPayment', :count, :price, :price_with_vat, :status)
    paid = Struct::MockPayment.new(0, 0, 0, 'paid')
    unpaid = Struct::MockPayment.new(0, 0, 0, 'unpaid')
    for payment in payments
      exchange_rate = Currency.count_exchange_rate(payment.currency, currency_name)
      price = Currency.count_exchange_prices({:exrate => exchange_rate, :prices => [payment.payment_amount.to_d]})
      price_with_vat = Currency.count_exchange_prices({:exrate => exchange_rate, :prices => [payment.payment_amount_with_vat(0)]})
      if payment.completed != 0
        paid.count += 1
        paid.price += price
        paid.price_with_vat += price_with_vat
      else
        unpaid.count += 1
        unpaid.price += price
        unpaid.price_with_vat += price_with_vat
      end
    end
    return paid, unpaid
  end

  def self.unnotified_payment(payment_type)
    current_user = User.current

    initial_attributes = {
      paymenttype: payment_type,
      date_added: Time.now,
      completed: 0,
      first_name: current_user.first_name,
      last_name: current_user.last_name,
      user: current_user,
      pending_reason: 'Unnotified payment',
      owner_id: current_user.owner_id
    }

    payment = Payment.new(initial_attributes)

    yield(payment) if block_given?

    payment.save and payment
  end

  def self.linkpoint_ipn(payment, test, notify)
    if notify.complete?
      if payment
        if payment.pending_reason == 'Unnotified payment'
          if user = User.find(payment.user_id)
            success = true
            payment.shipped_at = Time.now
            payment.completed = 1
            payment.pending_reason = 'Complete payment'
            payment.transaction_id = ''
            payment.user = user
            payment.date_added = Time.now if not payment.date_added
            # payment.residence_country = notify.country
            payment.payment_hash = notify.approval_code
            payment.save
            if test == 0
              user.balance += sprintf("%.2f", (payment.gross.to_d * Currency.count_exchange_rate(payment.currency, Currency.find(1).name))).to_d
              user.save
              Application.reset_user_warning_email_sent_status(user)
            end

            MorLog.my_debug('Linkpoint: Success')
          else
            reason = _('Internal_Error_Contact_Administrator')
            MorLog.my_debug('Linkpoint: User was not found')
            MorLog.my_debug("ID : #{payment.user_id}")
          end
        else
          reason = _('Internal_Error_Contact_Administrator')
          MorLog.my_debug('Linkpoint: Payment is invalid')
          MorLog.my_debug("Payment:   #{payment.pending_reason}")
          MorLog.my_debug('Expected:  Unnotified payment')
        end
      else
        reason = _('Internal_Error_Contact_Administrator')
        MorLog.my_debug('Linkpoint: Payment was not found')
        MorLog.my_debug("ID : #{notify.transaction_id}")
      end
    else
      reason = _('Internal_Error_Contact_Administrator')
      MorLog.my_debug('Linkpoint: Transaction was not completed')
      MorLog.my_debug('Expected: APPROVED')
      MorLog.my_debug("Got:      #{notify.status}")
      if notify.status == 'DECLINED'
        payment.pending_reason = "Denied"
        reason = _('Your_Payment_Was_Denied')
      end
      if notify.status == 'FRAUD'
        payment.pending_reason = ''
        reason = _('Your_Payment_Was_Suspected_Of_Fraud')
      end
      payment.save if payment
    end

    return payment, user, reason, success
  end

  def self.paypal_ipn(notify, payment, user)
    if Confline.get_value('PayPal_Test', user.owner_id).to_i == 1
      paypal_url = Paypal::Notification.test_ipn_url
    else
      paypal_url = Paypal::Notification.ipn_url
    end

    if notify.acknowledge(paypal_url)
      MorLog.my_debug("notify acknowledged : #{payment.id}", true)
      MorLog.my_debug("found user : #{user.id}", true)

      paypal_email = Confline.get_value('PayPal_Email', user.owner_id).to_s
      # we keep original amount (which he specified in payment form) in custom field so that we could compare
      if (paypal_email.to_s.downcase.to_s.strip == notify.business.to_s.downcase.to_s.strip) &&
          (payment.amount.to_d == notify.custom.to_d)

        MorLog.my_debug("business email is valid", true)
        if notify.complete?
          payment.fee = notify.fee.to_d
          payment.amount = notify.gross.to_d
          payment.gross = notify.gross.to_d - notify.tax.to_d
          payment.tax = notify.tax.to_d
          payment.paymenttype = 'paypal'
          payment.currency = notify.currency.to_s
          payment.transaction_id = notify.transaction_id.to_s
          payment.first_name = notify.first_name.to_s
          payment.last_name = notify.last_name.to_s
          payment.payer_email = notify.payer_email.to_s
          payment.residence_country = notify.residence_country.to_s
          payment.payer_status = notify.payer_status.to_s
          payment.user = user
          payment.date_added = Time.now if not payment.date_added
          payment.pending_reason = notify.pending_reason.to_s
          payment.pending_reason = 'Denied' if notify.status == 'Denied'
          payment.pending_reason = 'Reversed' if notify.reversed?
          payment.owner_id = user.owner_id
          payment.completed = 1
          payment.save
          confirmation = Confline.get_value('PayPal_Payment_Confirmation', user.owner_id).to_s

          if (confirmation.blank?) || (confirmation == 'none') ||
              ((confirmation == 'suspicious') && (notify.payer_email.to_s == user.email))

            payment.shipped_at = (notify.complete?) ? Time.now : nil
            MorLog.my_debug("User balance before payment: #{user.balance}")
            user.balance += sprintf("%.2f", payment.gross * Currency.count_exchange_rate(payment.currency, Currency.find(1).name)).to_d
            if payment.fee.to_d != 0.0 and Confline.get_value("PayPal_User_Pays_Transfer_Fee", user.owner_id).to_i == 1
              user.balance -= sprintf("%.2f", payment.fee * Currency.count_exchange_rate(payment.currency, Currency.find(1).name)).to_d
              fee_payment = payment.dup
              fee_payment.paymenttype = 'paypal_fee'
              fee_payment.fee = 0
              fee_payment.tax = 0
              fee_payment.shipped_at = Time.now
              fee_payment.completed = 1
              fee_payment.pending_reason = 'Completed'
              fee_payment.amount = payment.fee*-1
              fee_payment.gross = payment.fee*-1
              fee_payment.save
              Action.add_action(user.id, 'PayPal', "User paid paypal fee: #{payment.fee} #{payment.currency}")
            end
            user.save
            Application.reset_user_warning_email_sent_status(user)
            MorLog.my_debug('PayPal balance')
            MorLog.my_debug("User balance after payment: #{user.balance}")
            Action.add_action(user.id, 'PayPal', "Payment completed: #{payment.amount} #{payment.currency}")
            MorLog.my_debug('transaction succesfully completed', true)
          else # confirmation is required for all payments
            payment.completed = 0
            payment.pending_reason = 'Waiting for confirmation'

            Action.add_action(user.id, 'PayPal', "Payment waiting for approval: #{payment.id} #{payment.payer_email} #{payment.amount} #{payment.currency}")
            MorLog.my_debug('transaction waiting for confirmation', true)

            if Confline.get_value('PayPal_Email_Notification', user.owner_id).to_i == 1
              email = Email.where({:name => 'payment_notification_integrations', :owner_id => user.owner_id}).first
              user = User.where(:id => user.owner_id).first

              variables = Email.email_variables(user, nil, {:payment => payment,
                                                            :payment_notification => notify,
                                                            :payment_type => 'paypal'})
              EmailsController::send_email(email, Confline.get_value('Email_from', user.id), [user], variables)
              MorLog.my_debug('confirmation email sent', true)
            end
          end
        elsif notify.reversed?
          payment.paypal_refund_payment(notify, user)
        else
          MorLog.my_debug("transaction pending: #{notify.status}", true)
        end

        payment.save
      else
        MorLog.my_debug('Hack attempt: Email is not equal as paypal account email or sum was changed by editing HTML', true)
        MorLog.my_debug("Expected: '#{paypal_email.to_s.downcase}'", true)
        MorLog.my_debug("Paypal:   '#{notify.business.to_s.downcase}'", true)
        Action.add_action(user.id, 'PayPal', "Hack attempt - Email #{notify.business.to_s.downcase} is not equal as paypal account email #{paypal_email.to_s.downcase} or sum was changed by editing HTML")
      end
    else
      MorLog.my_debug('notify NOT acknowledged', true)
    end


    return payment, user, paypal_url
  end

  def self.cyberplat_pay(params)
    enabled = Confline.get_value('Cyberplat_Enabled', user.owner_id).to_i
    user_enabled = user.cyberplat_active.to_i
    test = Confline.get_value('Cyberplat_Test', user.owner_id).to_i
    fee = Confline.get_value('Cyberplat_Transaction_Fee', user.owner_id).to_d
    cp_default_curr = Confline.get_value('Cyberplat_Default_Currency', user.owner_id)
    cp_default_curr = 'RUB' if cp_default_curr == 'RUR'
    user_curr = cp_default_curr
    user_curr = params[:user_currency] if params[:user_currency]
    language = params[:cp_language]
    disabled_message = Confline.get_value2("Cyberplat_Disabled_Info", user.owner_id)
    if enabled == 1
      if test == 1
        submit_url = 'https://payment.cyberplat.ru/cgi-bin/GetForm.cgi'
      else
        submit_url = 'https://card.cyberplat.ru/cgi-bin/GetForm.cgi'
      end

      cyberplat_result_url = Web_URL + Web_Dir + '/payments/cyberplat_result'

      user = User.includes(:tax).where(["users.id = ?", session[:user_id]]).first
      user_id = session[:user_id]

      user_amount = Confline.get_value('Cyberplat_Default_Amount', user.owner_id).to_d
      user_amount = params[:amount].to_d if params[:amount]
      user_amount = sprintf("%.2f", user_amount).to_d
      amount = sprintf("%.2f", user_amount * Currency.count_exchange_rate(user_curr, cp_default_curr)).to_d
      cp_min_amount = Confline.get_value('Cyberplat_Min_Amount', user.owner_id).to_d

      if amount < cp_min_amount
        user_amount = cp_min_amount * Currency.count_exchange_rate(cp_default_curr, user_curr)
        amount = cp_min_amount
      end
      user_vat_sum = user.get_tax.count_tax_amount(amount)

      user_amount_with_vat = user_amount + user_vat_sum
      user_fee_sum = user_amount_with_vat*(fee/100)
      user_amount_with_vat += user_fee_sum
      user_amount_with_vat = sprintf("%.2f", user_amount_with_vat).to_d
      description = session[:company] + ' balance update'


      vat_sum = sprintf("%.2f", user_vat_sum).to_d
      amount_with_vat = amount + vat_sum
      fee_sum = amount_with_vat*(fee/100)
      fee_sum = sprintf("%.2f", fee_sum).to_d
      amount_with_vat += fee_sum
      amount_with_vat = sprintf("%.2f", amount_with_vat).to_d

      payment = Payment.unnotified_payment('cyberplat') do |p|
        p.amount = amount_with_vat
        p.currency = cp_default_curr
        p.gross = amount
        p.fee = fee_sum
        p.tax = vat_sum
      end
      payment_id = payment.id
    end

    return amount, amount_with_vat, cp_default_curr, cyberplat_result_url, description, disabled_message, enabled, fee,
        fee_sum, language, payment, payment_id, submit_url, test, user, user_amount, user_amount_with_vat, user_curr,
        user_enabled, user_fee_sum, user_id, user_vat_sum, vat_sum
  end

  def self.pay_for_invoice(payment, invoice, owner_id)
    payment ||= Payment.new

    user = invoice.user
    currency = user.currency

    payment.paymenttype = 'invoice'
    payment.amount = invoice.price.to_d
    payment.currency = currency.name.to_s if currency
    payment.date_added = Time.now
    payment.shipped_at = Time.now
    payment.completed = 1
    payment.user = user
    payment.owner_id = owner_id
    payment.save and payment
  end

  def self.manual_payment_finish_for_provider(provider, params, current_user)
    amount = params[:amount].to_d * -1.to_d
    real_amount = params[:real_amount].to_d * -1.to_d
    currency = params[:p_currency]
    exchange_rate = Currency.count_exchange_rate(current_user.currency.name, currency)

    # user's default currency
    curr_amount =  amount / exchange_rate.to_d / current_user.currency.exchange_rate.to_d
    curr_real_amount =  real_amount / exchange_rate.to_d
    provider.balance +=  curr_amount
    provider.save

    usd = provider.device.user if provider.device and provider.device.user
    paym = Payment.new
    paym.paymenttype = 'manual'
    paym.amount = real_amount
    paym.currency = currency
    paym.date_added = Time.now
    paym.shipped_at = Time.now
    paym.completed = 1
    paym.user_id = usd ? usd.id : -1
    paym.provider = provider
    paym.owner_id = provider.user_id
    paym.tax = usd ? usd.get_tax.count_tax_amount(amount) : amount
    paym.description = params[:description].to_s
    paym.save
  end

  def self.manual_payment_finish_for_user(user, amount, real_amount, currency, exchange_rate,
      curr_amount, curr_real_amount, params, current_user, session)
    # logger.fatal "#{Time.now}  -  Manual Payment User saved - User:#{user.id}; balance:#{user.balance}"

    paym = Payment.new
    paym.paymenttype = 'manual'
    paym.amount = real_amount
    paym.currency = currency
    paym.date_added = Time.now
    paym.shipped_at = Time.now
    paym.completed = 1
    paym.user = user
    paym.owner_id = user.owner_id
    paym.tax = user.get_tax.count_tax_amount(amount)
    paym.description = params[:description].to_s
    paym.save
    # logger.fatal "#{Time.now}  -  Manual Payment Payment created - Payment:#{paym.id}; amount:#{paym.amount}; amount_to_add:#{real_amount}"

    invoice_amount = (curr_amount/ current_user.current.currency.exchange_rate.to_d).to_d
    invoice_amount_real = (curr_real_amount/ current_user.current.currency.exchange_rate.to_d).to_d

    nc = nice_invoice_number_digits('prepaid', session)

    # create invoice for prepaid user's manual payment if such setting activated
    if (user.postpaid == 0) && (user.generate_invoice == 1)
      number_type = Confline.get_value('Prepaid_Invoice_Number_Type').to_i
      invoice = Invoice.new
      invoice.user = user
      invoice.tax = user.tax.dup
      invoice.period_start =  Time.now
      invoice.period_end =  Time.now
      invoice.issue_date = Time.now
      invoice.paid = 1
      invoice.number = ''
      invoice.paid_date = Time.now
      invoice.invoice_type = 'prepaid'
      invoice.price = invoice.nice_invoice_number(invoice_amount.to_d, {:nc => nc, :apply_rounding => true})
      invoice.price_with_vat = invoice.nice_invoice_number(invoice_amount_real.to_d, {:nc => nc,
                                                                                      :apply_rounding => true})
      invoice.invoice_precision = nc
      currency = user.currency
      if currency
        invoice.invoice_exchange_rate = currency.exchange_rate
        invoice.invoice_currency = currency.name
      end

      invoice.number = generate_invoice_number(Confline.get_value('Prepaid_Invoice_Number_Start'),
                                               Confline.get_value('Prepaid_Invoice_Number_Length').to_i,
                                               number_type, invoice.id, Time.now, current_user)

      invoice.number_type = number_type
      invoice.save

      invdetail = Invoicedetail.new
      invdetail.invoice_id = invoice.id

      if currency.name.to_s != current_user.currency.name
        invdetail.name = _('Manual_payment') + "(#{invoice_amount.to_d * currency.exchange_rate} #{currency.name.to_s})"
      else
        invdetail.name = _('Manual_payment')
      end

      invdetail.price = invoice_amount.to_d
      invdetail.quantity = 1
      invdetail.invdet_type = 0
      invdetail.save
    else
      Action.add_action_hash(current_user, :target_id => user.id,
                             :target_type => 'user', :action => 'invoice_not_created')
    end
    Application.reset_user_warning_email_sent_status(user)
  end

  def self.generate_invoice_number(start, length, type, number, time, current_user)
    owner_id = current_user.usertype? == 'accountant' ? 0 : current_user.id
    type = 1 if type.to_i == 0

    # INV000000001 - prefixNR
    if type == 1
      ls = start.length
      cond_str = ["SUBSTRING(number,1,?) = ?", "users.owner_id = ?"]
      cond_var = [ls, start.to_s, owner_id]
      cond_str << ["number_type = 1"]
      invoice = Invoice.where([cond_str.join(" AND ")]+cond_var)
      .joins("LEFT JOIN users ON (invoices.user_id = users.id)")
      .order("CAST(SUBSTRING(number,#{ls+1},255) AS SIGNED) DESC").first

      invoice ? number = (invoice.number[ls, invoice.number.length - ls].to_i + 1) : number = 1
      zl = length - start.length - number.to_s.length
      z = ""
      1..zl.times { z += '0' }
      invnum = "#{start}#{z}#{number.to_s}"
    end

    # INV070605011 - prefixYYMMDDnr
    if type == 2
      date = time.year.to_s[-2..-1] + good_date(time.month)+good_date(time.day)
      ls = start.length + 6
      cond_str = ["SUBSTRING(number,1,?) = '#{start.to_s}#{date.to_s}' AND users.owner_id = ?"]
      cond_var = [ls, owner_id]
      cond_str << ["number_type = 2"]
      pinv = Invoice.where([cond_str.join(' AND ')]+cond_var)
      .joins("LEFT JOIN users ON (invoices.user_id = users.id)")
      .order("CAST(SUBSTRING(number,#{ls+1},255) AS SIGNED) DESC").first

      pinv ? nn = (pinv.number[ls, pinv.number.length - ls].to_i + 1) : nn = 1
      zl = length - start.length - nn.to_s.length - 6
      z = ''
      1..zl.times { z += '0' }
      invnum = "#{start}#{date}#{z}#{nn}"
    end

    return invnum
  end

  # adding 0 to day or month <10
  def self.good_date(dd)
    dd = dd.to_s
    dd = '0' + dd if dd.length < 2
    dd
  end

  def self.cyberplat_result(params, session, payment)
    user = payment.user
    enabled = (Confline.get_value('Cyberplat_Enabled', user.owner_id).to_i and user.cyberplat_active.to_i)
    test = Confline.get_value('Cyberplat_Test', user.owner_id).to_i
    cp_default_curr = Confline.get_value('Cyberplat_Default_Currency', user.owner_id)
    checker_tmp = Confline.get_value('Cyberplat_Temporary_Directory', 0)


    if payment and enabled == 1
      File.open("#{checker_tmp}/message2.txt", 'w') { |f| f.write(params[:reply]) }
      system("#{Actual_Dir}/lib/cyberplat/checker.exe -c -f #{Actual_Dir}/lib/cyberplat/checker.ini #{checker_tmp}/message2.txt > #{checker_tmp}/message3.txt")
      msg = ''
      File.open("#{checker_tmp}/message3.txt", 'r') do |infile|
        while (line = infile.gets)
          msg +=line
        end
      end
      system("rm #{checker_tmp}/message2.txt")
      system("rm #{checker_tmp}/message3.txt")
      MorLog.my_debug(msg)
      b = msg.split('&')
      z = []

      for s in b do
        k = []
        k[0] = s.split('=')[0]
        k[1] = s.split('=')[1]
        z += k
      end

      status = z[z.index('Status')+1].to_i if z.index('Status')
      transaction_id = z[z.index('TransactionID')+1].to_i if z.index('TransactionID')
      order_id = z[z.index('OrderID')+1].to_i if z.index('OrderID')
      transaction_amount = z[z.index('TransactionAmount')+1].to_d/100 if z.index('TransactionAmount')
      transaction_currency = z[z.index('TransactionCurrency')+1] if z.index('TransactionCurrency')
      error_code = z[z.index('ErrorCode')+1].to_i if z.index('ErrorCode')
      description = z[z.index('Description')+1] if z.index('Description')
      customer_title = z[z.index('CustomerTitle')+1] if z.index('CustomerTitle')
      customer_name = z[z.index('CustomerName')+1] if z.index('CustomerName')
      payment_details = z[z.index('PaymentDetails')+1] if z.index('PaymentDetails')
      transaction_date = z[z.index('TransactionDate')+1] if z.index('TransactionDate')
      auth_code = z[z.index('AuthCode')+1] if z.index('AuthCode')
      terminal = z[z.index('Terminal')+1] if z.index('Terminal')
      if status == 0
        if payment.id == order_id
          if payment.pending_reason == 'Unnotified payment'
            if payment.amount == transaction_amount
              payment.completed = 1
              payment.transaction_id = transaction_id
              payment.shipped_at = Time.now
              payment.payer_email = user.email
              payment.pending_reason = ''
              payment.save
              user.balance += sprintf("%.2f", payment.gross *
                  Currency.count_exchange_rate(payment.currency, Currency.find(1).name)).to_d

              user.save
              Application.reset_user_warning_email_sent_status(user)
              email = Email.where("name = 'cyberplat_announce' AND owner_id = #{user.owner_id}").first
              users = []
              users << user
              users << User.find(user.owner_id)
              variables = email_variables(user, nil, {:amount => transaction_amount,
                                                      :currency => transaction_currency,
                                                      :date => transaction_date, :auth_code => auth_code,
                                                      :trans_id => transaction_id, :customer_name => customer_name,
                                                      :description => payment_details}, session)

              EmailsController.send_email(email, session[:company_email], users, variables)
            else
              status = 1
              error_code = 1
              description = _('Amount_Missmatch')
              my_debug('Amount missmatch')
              my_debug('Payment amount: ' + payment.amount.to_s)
              my_debug('Transaction amount: ' + transaction_amount.to_s)
            end
          else
            status = 2
            error_code = 2
            description = _('Unknown_Payment')
            my_debug('Unnotified payment')
          end
        else
          status = 3
          error_code = 3
          description = _('Unknown_Payment_ID')
          my_debug('Unnotified payment')
          my_debug('PaymentID and orderID are not equal')
          my_debug('PaymentID' + payment.id.to_s)
          my_debug('orderID' + order_id)
        end
      else
        my_debug('Wrong status: ' + status.to_s)
      end
    else
      my_debug('Payment not enabled or not found')
    end

    return auth_code, cp_default_curr, customer_name, customer_title, description, enabled, error_code, order_id,
        payment, payment_details, status, terminal, test, transaction_amount, transaction_currency,
        transaction_date, transaction_id, user
  end

  #put value into file for debugging
  def self.my_debug(msg)
    File.open(Debug_File, 'a') { |f|
      f << msg.to_s
      f << "\n"
    }
  end

  def self.email_variables(user, device = nil, variables = {}, session)
    Email.email_variables(user, device, variables, {:nice_number_digits => session[:nice_number_digits],
                                                    :global_decimal => session[:global_decimal],
                                                    :change_decimal => session[:change_decimal]})
  end

  def self.nice_invoice_number_digits(type, session)
    if type.to_s == 'prepaid'
      session[:nice_prepaid_invoice_number_digits] ||= Confline.get_value("Prepaid_Round_finals_to_2_decimals").to_i
      if session[:nice_prepaid_invoice_number_digits].to_i == 1
        return 2
      else
        return session[:nice_number_digits]
      end
    else
      session[:nice_invoice_number_digits] ||= Confline.get_value("Round_finals_to_2_decimals").to_i
      if session[:nice_invoice_number_digits].to_i == 1
        return 2
      else
        return session[:nice_number_digits]
      end
    end
  end
end
