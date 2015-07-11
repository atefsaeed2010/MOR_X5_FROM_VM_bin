# -*- encoding : utf-8 -*-
class M2Invoice < ActiveRecord::Base

  extend UniversalHelpers

  attr_accessible :id, :number, :user_id, :status, :status_changed, :created_at, :updated_at, :issue_date, :period_start,
                  :period_end, :due_date, :timezone, :client_name, :client_details1, :client_details2, :client_details3,
                  :client_details4, :client_details5, :client_details6, :currency, :currency_exchange_rate, :total_amount,
                  :total_amount_with_taxes, :comment, :mailed_to_user, :notified_admin, :notified_manager, :nice_user,
                  :exchanged_total_amount, :exchanged_total_amount_with_taxes

  has_many :m2_invoice_lines

  def validates_dates_from_update(params)
    if !params[:issue_date_system_tz].blank?
      if params[:issue_date_system_tz] < period_end
        errors.add(:m2_invoice, _('issue_date_must_be_later_than_period_end'))
      end

      if params[:due_date_system_tz] < params[:issue_date_system_tz]
        errors.add(:m2_invoice, _('date_due_must_be_later_than_issue_date'))
      end
    end

    return errors.size > 0 ? false : true
  end

  def self.order_by(options, fpage, items_per_page)
    order_by, order_desc = [options[:order_by], options[:order_desc]]
    order_string = ''

    if not order_by.blank? and not order_desc.blank?
      order_string << "#{order_by} #{order_desc.to_i.zero? ? 'ASC' : 'DESC'}" if M2Invoice.accessible_attributes.member?(order_by)
    end

    selection = M2Invoice.order(order_string)
    selection = options[:csv].to_i.zero? ? selection.limit("#{fpage}, #{items_per_page}").all : selection.all
  end

  def self.filter(options, show_currency)
    where, min_amount, max_amount = self.where_conditions(options, show_currency)
    clear_search = !where.blank?

    if [min_amount, max_amount].any? {|var| (/^(?!0\d)\d*(\.\d+)?$/ !~ var and var.present?)}
      return M2Invoice.none, clear_search
    end

    options_exchange_rate = options[:exchange_rate].to_d
    show_currency_upcase = show_currency.upcase
    selection = M2Invoice.select('m2_invoices.*,' + SqlExport.nice_user_sql).
                          select("total_amount * IF((UPPER(m2_invoices.currency) = '#{show_currency_upcase}'),(m2_invoices.currency_exchange_rate),(#{options_exchange_rate})) AS exchanged_total_amount").
                          select("total_amount_with_taxes * IF((UPPER(m2_invoices.currency) = '#{show_currency_upcase}'),(m2_invoices.currency_exchange_rate),(#{options_exchange_rate})) AS exchanged_total_amount_with_taxes").
                          joins('LEFT JOIN users ON users.id = m2_invoices.user_id').
                          where(where.join(' AND '))

    return selection, clear_search
  end

  def nice_total_amount_with_tax
    "#{nice_currency} #{Application.nice_value(total_amount_with_taxes / currency_exchange_rate)}"
  end

  def nice_total_amount
    "#{nice_currency} #{Application.nice_value(total_amount / currency_exchange_rate)}"
  end

  def exchange_rate
    currency_exchange_rate
  end

  def nice_currency
    currency.to_s.upcase
  end

  private

  def self.where_conditions(options, show_currency)
    nice_user, number, period_start, period_end, issue_date, status, min_amount, max_amount, currency = options[:s_nice_user],
                                                                                                        options[:s_number],
                                                                                                        options[:s_period_start],
                                                                                                        options[:s_period_end],
                                                                                                        options[:s_issue_date],
                                                                                                        options[:s_status],
                                                                                                        options[:s_min_amount],
                                                                                                        options[:s_max_amount],
                                                                                                        options[:s_currency]
    options_exchange_rate = options[:exchange_rate].to_d
    show_currency_upcase = show_currency.upcase
    where = []
    where << "(users.username LIKE '#{nice_user}' or users.first_name LIKE '%#{nice_user}%' or users.last_name LIKE '%#{nice_user}%')" if nice_user.present?
    where << "number LIKE '#{number}'" if number.present?
    where << "period_start BETWEEN '#{period_start} 00:00:00' AND '#{period_start} 23:59:59'" if period_start.present?
    where << "period_end BETWEEN '#{period_end} 00:00:00' AND '#{period_end} 23:59:59'" if period_end.present?
    where << "issue_date BETWEEN '#{issue_date}' AND '#{(issue_date.to_time + 1.days).to_s}'" if issue_date.present?
    where << "status LIKE '#{status}'" if status.present?
    where << "(total_amount * IF((UPPER(m2_invoices.currency) = '#{show_currency_upcase}'),(m2_invoices.currency_exchange_rate),(#{options_exchange_rate}))) >= #{min_amount}" if min_amount.present?
    where << "(total_amount * IF((UPPER(m2_invoices.currency) = '#{show_currency_upcase}'),(m2_invoices.currency_exchange_rate),(#{options_exchange_rate}))) <= #{max_amount}" if max_amount.present?
    where << "currency LIKE '#{currency}'" if currency.present?

    return where, min_amount, max_amount
  end
end

