# -*- encoding : utf-8 -*-
class Ccorder < ActiveRecord::Base
  attr_accessible :id, :amount, :currency, :ordertype, :email, :date_added, :completed
  attr_accessible :transaction_id, :shipped_at, :fee, :gross, :first_name, :last_name
  attr_accessible :payer_email, :residence_country, :payer_status, :tax, :tax_percent

  has_many :cclineitems, :dependent => :destroy
  has_many :cc_invoices, :dependent => :destroy
  validates_presence_of :ordertype

  def cards

#    sql = "SELECT cards.* FROM cards
#            JOIN cclineitems ON (cclineitems.card_id = cards.id)
#            WHERE cclineitems.ccorder_id = '#{self.id}'"
#    Card.find_by_sql(sql)
    Card.joins('JOIN cclineitems ON (cclineitems.card_id = cards.id)').where(['cclineitems.ccorder_id = ?', self.id]).all
  end

  # cleans old unspecified orders
  def Ccorder.clean_orders
    Ccorder.delete_all(["ordertype = 'unspecified' AND date_added < ?", Time.now - 12.hours])
  end

  def self.create_by(params)
    order = Ccorder.new(params[:order])
    order.ordertype = 'unspecified'
    order.date_added = Time.now
    order
  end

  def update_by_notification(notify)
    self.shipped_at = (notify.complete?) ? Time.now : nil
    self.ordertype = 'paypal'
    # @order.amount = notify.amount.to_s
    self.currency = notify.currency
    self.fee = notify.fee
    self.amount = notify.gross
    self.transaction_id = notify.transaction_id
    self.first_name = notify.first_name
    self.last_name = notify.last_name
    self.payer_email = notify.payer_email
    self.email = notify.payer_email
    self.residence_country = notify.residence_country
    self.payer_status = notify.payer_status
    self.tax = notify.tax

    if notify.complete?
      Action.create_cards_action(self)
      payment = Payment.create_cards_action(self)
      CcInvoice.invoice_from_order(self, payment)
    end
    if notify.reversed?
      Action.create_cards_action(self, 'card_payment_reversed')
      invoice = self.cc_invoice
      payment = invoice.payment if invoice
      invoice.destroy if invoice
      payment.destroy if payment
    end
  end
end
