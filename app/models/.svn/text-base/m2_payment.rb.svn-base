# -*- encoding : utf-8 -*-
class M2Payment < ActiveRecord::Base

  PAYMENT_TO_PROVIDER = 1

  attr_accessible :id, :user_id, :comment, :date, :amount, :amount_with_tax, :currency_id, :exchange_rate, :payment_destination

  belongs_to :user
  belongs_to :currency

  after_create {
    add_action('payment_created')
    update_user_balance
  }
  after_destroy {add_action('payment_deleted')}

  validates :amount, numericality: {
      message: _('amount_must_be_numerical'),
      if: lambda { amount.present? }
  }
  validates :amount_with_tax,
            numericality: {message: _('amount_with_tax_must_be_numerical'),
                           if: lambda { amount_with_tax.present? }},
            presence: {
                message: _('amount_or_amount_with_tax_must_be_present'),
                unless: lambda { amount.present? }
  }
  validate :amounts_equal_to_zero?

  def self.new_by_attributes(attributes)
    default_attributes = {
        date: Time.now,
        amount: nil,
        amount_with_tax: nil
    }

    attributes = default_attributes.merge(attributes)
    m2_payment = M2Payment.new(attributes)

    if m2_payment.valid?
      m2_payment.apply_taxes
      if m2_payment.payment_destination == PAYMENT_TO_PROVIDER
        m2_payment.invert_amounts
      end
    end

    m2_payment
  end

  def self.order_by(options)
    order_by, order_desc = [options[:order_by], options[:order_desc]]

    [options[:s_amount_min], options[:s_amount_max]].each do |amount|
      amount.to_s.try(:sub!, /[\,\.\;]/, ".").try(:strip!)
    end

    search_where, search_where_date, invalid_search = M2Payment.search_options(options)

    clear_search = !search_where.blank?

    if !invalid_search
      order_string = ''

      if not order_by.blank? and not order_desc.blank? and M2Payment.accessible_attributes.member?(order_by)
        order_string << "#{order_by} #{order_desc.to_i.zero? ? 'ASC' : 'DESC'}"
      end

      selection_all = M2Payment.order(order_string).
                                where(search_where.join(" AND ")).
                                where(search_where_date).all
    end

    return  selection_all, clear_search, invalid_search
  end

  def self.search_options(options)
    user_id, amount_min, amount_max, currency_id, date_from, date_till, not_default_date = options[:s_user_id], options[:s_amount_min],
                                                                                           options[:s_amount_max], options[:s_currency_id],
                                                                                           options[:s_date_from], options[:s_date_till],
                                                                                           options[:not_default_date]
    search_where = []
    search_where << "user_id = #{user_id}" if user_id.present?
    search_where << "amount >= '#{amount_min}'" if amount_min.present?
    search_where << "amount <= '#{amount_max}'" if amount_max.present?
    search_where << "currency_id = #{currency_id}" if currency_id.present?

    if not_default_date
      search_where << "date BETWEEN '#{date_from}' AND '#{date_till}'"
    else
      search_where_date = "date BETWEEN '#{date_from}' AND '#{date_till}'"
    end

    invalid_search = !M2Payment.amounts_are_numeric(amount_min, amount_max)

    return search_where, search_where_date, invalid_search
  end

  def self.currency_by_id(currency_id)
    currency = Currency.where(:id => currency_id).first
    return currency.name.to_s
  end

  def payment_destination=(value)
    @payment_destination = value
  end

  def payment_destination
    @payment_destination.to_i
  end

  def invert_amounts
    self.amount = 0 - amount
    self.amount_with_tax = 0 - amount_with_tax
  end

  def apply_taxes
    user_tax = user.get_tax
    if self.amount.to_d != 0
      new_amount_with_tax = user_tax.apply_tax(amount)
      new_amount_with_tax = amount if new_amount_with_tax.zero?
      self.amount_with_tax = new_amount_with_tax
    else
      new_amount = user_tax.count_amount_without_tax(amount_with_tax)
      new_amount = amount_with_tax if new_amount.zero?
      self.amount = new_amount
    end
  end

  def update_user_balance
    user.update_balance(amount.to_d / exchange_rate.to_d)
  end


  def amount_with_tax_default_currency
    amount_with_tax.to_d / exchange_rate.to_d
  end

  def amount_default_currency
    amount.to_d / exchange_rate.to_d
  end

  private

  def add_action(action)
    Action.add_action_hash(User.current, {:action => action, :data => self.user_id, :data2 => self.amount, :data3 => M2Payment.currency_by_id(self.currency_id.to_i), :target_id => self.id, :target_type => 'Payment'})
  end


  def self.amounts_are_numeric(amount_min, amount_max)
    is_numeric = /^-?[\d]+(\.[\d]+){0,1}$/
    return (
      (is_numeric.match(amount_min) or amount_min.blank?) and (is_numeric.match(amount_max) or amount_max.blank?)
      )
  end

  def amounts_equal_to_zero?
    if errors.blank?
      if amount.present? and amount == 0
        errors.add(:amount, _('amount_cannot_be_zero'))
      elsif amount_with_tax.present? and amount_with_tax == 0
        errors.add(:amount_with_tax, _('amount_with_tax_cannot_be_zero'))
      end
    end
  end
end