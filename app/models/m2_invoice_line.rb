# -*- encoding : utf-8 -*-
class M2InvoiceLine < ActiveRecord::Base

  attr_accessible :id, :m2_invoice_id, :destination, :name, :rate, :calls, :total_time, :price
  belongs_to :m2_invoice

  def self.reset_destination_number
    @@destination_number = 0
  end

  def destination_number
    "#{@@destination_number += 1}."
  end

  def nice_price
    "#{m2_invoice.nice_currency} #{Application.nice_value(price / m2_invoice.currency_exchange_rate)}"
  end

  def nice_total_time
  	minutes = total_time / 60
    seconds = total_time % 60
    "#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
  end

  def exchange_rate
    currency_exchange_rate
  end

  def self.invoice_lines_order_by(options, fpage, items_per_page)
    order_by, order_desc = [options[:order_by], options[:order_desc]]
    order_string = ''

    if not order_by.blank? and not order_desc.blank?
      order_string << "#{order_by} #{order_desc.to_i.zero? ? 'ASC' : 'DESC'}" if M2InvoiceLine.accessible_attributes.member?(order_by)
    end

    selection = M2InvoiceLine.order(order_string).limit("#{fpage}, #{items_per_page}").all
  end

  def self.invoice_lines_filter(options, invoice_id)
    where = M2InvoiceLine.where_conditions(options)
    clear_search = !where.blank?
    selection = M2InvoiceLine.where(where).where(m2_invoice_id: invoice_id)

    return selection, clear_search
  end

  private

  def self.where_conditions(options)
    prefix = options[:s_prefix]
    where = prefix.present? ? "destination LIKE '#{prefix}'" : []

    return where
  end
end
