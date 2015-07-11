# -*- encoding : utf-8 -*-
class Callshop < ActiveRecord::Base
  extend UniversalHelpers

  has_many :invoices, class_name: 'CsInvoice'
  has_many :unpaid_invoices, -> { where(paid: false) }, class_name: 'CsInvoice'
  has_and_belongs_to_many :users, -> { order('usergroups.position asc') },
                          join_table: 'usergroups', foreign_key: 'group_id' # should be has many through :|

  def self.table_name()
    "groups"
  end

  def free_booths_count
    # all users in callshop - unpaid (reserved or occupied) booths
    users.size - invoices.count(:conditions => ["paid_at IS NULL"])
  end

  def status
    calls = 0
    return {
        :free_booths => free_booths_count,
        :booths => users.inject([]) { |booths, user|
          created_at = (user.cs_invoices.first.try(:created_at)) ? user.cs_invoices.first.created_at.strftime("%Y-%m-%d %H:%M:%S") : nil
          booth = {:id => user.id, :element => nil, :state => user.booth_status, :number => nil, :duration => nil, :country => nil, :user_rate => nil, :local_state => false, :comment => nil, :created_at => nil, :balance => nil, :timestamp => nil}

          case booth[:state]
            when "free"
              booth
            when "reserved"
              invoice = user.cs_invoices.first
              booth.merge!({
                               :comment => invoice.comment,
                               :created_at => created_at,
                               :balance => booth_balance(user),
                               :timestamp => stamp(user),
                               :user_type => invoice.invoice_type,
                               :server => "",
                               :channel => ""
                           })
            when "occupied"
              calls += 1
              active_call = user.activecalls.first
              invoice = user.cs_invoices.first
              destination = active_call.try(:destination)


              booth.merge!(
                  {:comment => invoice.comment,
                   :created_at => created_at,
                   :balance => booth_balance(user),
                   :country => destination.try(:direction).try(:name),
                   :number => active_call.try(:dst),
                   :channel => active_call.try(:channel),
                   :user_type => invoice.invoice_type,
                   :server => active_call.try(:server_id),
                   :user_rate => active_call.try(:user_rate),
                   #The UniversalHelpers should be split and grouped into smaller ones, since currently, instance methods can't reach the helper's class methods
                   #and class methods can't reach instance methods.
                   :duration => Callshop.nice_time(active_call.try(:duration)),
                   :timestamp => stamp(user)
                  }
              )
          end

          booths.push(booth)
        },
        :active_calls => calls
    }
  end

  def self.reserve_booth(invoice, params)
    user = invoice.user
    old_invoice = user.cs_invoices.first
    unless old_invoice
      tax = user.get_tax.dup
      tax.save
      invoice.tax_id = tax.id
      invoice.balance_with_tax = params[:invoice][:balance].to_d
      invoice.save
      user_type = (params[:invoice][:invoice_type].to_s == "postpaid" ? 1 : 0)
      balance = (user_type == 1 ? 0 : params[:invoice][:balance].to_d)
      if params[:add_with_tax_new].to_i == 1 and invoice.tax
        balance = invoice.tax.count_amount_without_tax(balance).to_d
        invoice.balance_with_tax = params[:invoice][:balance].to_d
        invoice.balance = balance
        invoice.save
      else
        invoice.balance_with_tax = invoice.tax.apply_tax(balance)
        invoice.save
      end
      user.update_attributes({:balance => balance, :postpaid => user_type, :blocked => 0})
    end

    return user, old_invoice, invoice
  end

  def self.update(invoice, params)
    user = invoice.user

    if params[:increase] && (params[:increase] != 'true')
      params[:invoice][:balance] = 0 if invoice.balance - params[:invoice][:balance].to_d <= 0 # so it won't get negative
    end

    if params[:add_with_tax].to_i == 1 and invoice.tax
      params[:invoice][:balance_with_tax] = params[:invoice][:balance].to_d
      params[:invoice][:balance] = invoice.tax.count_amount_without_tax(params[:invoice][:balance]).to_d
    else
      if invoice.tax
        params[:invoice][:balance_with_tax] = invoice.tax.apply_tax(params[:invoice][:balance]).to_d
      end
    end

    invoice.update_attributes(params[:invoice])

    if params[:invoice][:balance]
      user.update_attributes({:balance => params[:invoice][:balance].to_d})
    end

    return user, invoice
  end

  def self.topup_update(invoice, params)
    user = invoice.user
    if params[:add_with_tax].to_i == 1 and invoice.tax
      params[:invoice][:balance] = round_to_cents(invoice.tax.count_amount_without_tax(params[:invoice][:balance]).to_d).to_d
    end

    if params[:increase] == "true"
      logger.debug " >> Increasing balance by #{params[:invoice][:balance]}"
      user.balance += params[:invoice][:balance]
      invoice.balance += params[:invoice][:balance]
      invoice.balance_with_tax += params[:invoice][:balance_with_tax].to_d
    else
      logger.debug " >> Decreasing balance by #{params[:invoice][:balance]}"
      user.balance -= params[:invoice][:balance]
      invoice.balance -= params[:invoice][:balance]
      invoice.balance_with_tax -= params[:invoice][:balance_with_tax].to_d
    end

    user.balance = invoice.balance = invoice.balance_with_tax = 0 if user.balance < 0
    user.save
    invoice.save

    return user, invoice
  end

  def simple_session?
    self.simple_session.to_i == 1
  end

  def nice_type
    case postpaid.to_i
    when 1
      type = 'postpaid'
    when 0
      type = 'prepaid'
    else
      type = ''
    end
  end

  private

  def stamp(booth)
    stamps = []
    booth_cs_invoices = booth.cs_invoices

    if booth_cs_invoices.any?
      invoice = booth_cs_invoices.first
      calls = booth.activecalls_since(invoice.created_at)
      if calls.size > 0
        stamps.push(calls[0].start_time.to_i)
      end
      stamps.push(invoice.updated_at.to_i)
    else
      nil
    end
    stamps.max
  end

  def booth_balance(booth)
    booth_cs_invoices = booth.cs_invoices

    if booth_cs_invoices.any?
      invoice = booth_cs_invoices.first
      invoice_call_price = invoice.call_price

      if invoice.postpaid?
        -1 * invoice_call_price
      else # prepaid
        invoice.balance - invoice_call_price
      end
    else
      nil
    end
  end
end
