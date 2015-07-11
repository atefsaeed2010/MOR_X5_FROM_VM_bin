# -*- encoding : utf-8 -*-
class Card < ActiveRecord::Base
  include ApplicationHelper

  attr_protected

  belongs_to :cardgroup

  has_many :calls, -> { order("calldate DESC") }
  has_many :activecalls
  has_many :cclineitems
  belongs_to :user
  validates_numericality_of :number, :message => _('card_number_must_be_numerical')
  validates_uniqueness_of :number, :allow_nil => true, :scope => :cardgroup_id
  validates_presence_of :pin, :message => _('Card_pin_is_blank')
  validates_uniqueness_of :pin, :allow_nil => true, :message => _('PIN_is_already_taken')
  validates_uniqueness_of :callerid, :if => :validate_caller_id, :message => _('Callerid_must_be_unique')

  before_save :validate_pin_length, :validate_number_length, :validate_min_balance
  before_create :card_before_create

  scope :with_pin_length, ->(length) { where(['length(pin) = :pin_length', pin_length: length]) }

  before_destroy :has_payment?

  def validate_caller_id
    callerid and !callerid.to_s.blank?
  end

  def validate_number_length
    if self.number and self.number.length != self.cardgroup.number_length.to_i
      errors.add(:number, _('Bad_number_length_should_be') + ": " + self.cardgroup.number_length.to_s)
      false
    else
      true
    end
  end

  def validate_pin_length
    if self.pin and self.pin.length != self.cardgroup.pin_length
      errors.add(:pin, _('Bad_pin_length_should_be') + ": " + self.cardgroup.pin_length.to_s)
      false
    else
      true
    end
  end

  def validate_min_balance
    if self.min_balance.to_d < 0.to_d
      errors.add(:min_balance, _('Bad_minimal_balance'))
      false
    else
      true
    end
  end

  # A: Fast adaptive delete
  def Card.delete_from_sql(options={})
    cards_deleted = 0
    @chunks =[]
    @scope  = (options[:start_num].to_i..options[:end_num].to_i)
    case @scope.count
      when (0..999999) 		# ZAP/Adaptive delete if below default limit
        limit = @scope.count
      else
        limit = 1000000		# For Huge batches
    end
    @scope.each_slice(limit) { |slice| @chunks << [slice.first, slice.last] }
    @chunks.each do |leading, trailing|
      query = "DELETE FROM cards USING cards LEFT JOIN payments ON (payments.user_id = cards.id and paymenttype='Card') WHERE payments.id IS NULL AND cards.number BETWEEN #{leading} AND #{trailing}"
      rows_affected = ActiveRecord::Base.connection.delete(query)
      cards_deleted += rows_affected
    end
    query = "SELECT COUNT(*)
               FROM  (SELECT cards.id
                      FROM cards
                      LEFT JOIN payments ON (payments.user_id = cards.id and paymenttype='Card')
                      WHERE (payments.id IS NOT NULL) AND
                             cards.number BETWEEN #{options[:start_num]} AND #{options[:end_num]}
                      GROUP BY cards.id) tmp"
    cards_not_deleted = ActiveRecord::Base.connection.select_value(query).to_i
    return    cards_deleted, cards_not_deleted
  end

  def Card.delete_and_hide_from_sql(options={})
    cards_deleted, cards_not_deleted = Card.delete_from_sql(options)
    if cards_not_deleted.to_i > 0
      cards_hidden = Card.hide_from_sql(options.merge!({:force=>true}))
    end
    return  cards_deleted, cards_hidden
  end

  def Card.hide_from_sql(options={})
    cards_hidden = 0
    if options[:force]
      query = "UPDATE cards SET callerid = NULL, number = CONCAT('DELETED_#{Time.now.to_i}_', number), pin = CONCAT('DELETED_#{Time.now.to_i}_', pin), hidden = 1 WHERE cards.cardgroup_id = #{options[:cardgroup_id]} AND cards.number BETWEEN '#{options[:start_num]}' AND '#{options[:end_num]}' LIMIT 10000;"
      begin
        rows_affected = ActiveRecord::Base.connection.update(query)
        cards_hidden += rows_affected
      end while rows_affected > 0
    else
      query = "UPDATE cards SET callerid = NULL, number = CONCAT('DELETED_#{Time.now.to_i}_', number), pin = CONCAT('DELETED_#{Time.now.to_i}_', pin), hidden = 1
               FROM cards
               JOIN (SELECT cards.id
                     FROM cards
                     LEFT JOIN payments ON (payments.user_id = cards.id and paymenttype='Card')
                     LEFT JOIN activecalls ON (activecalls.card_id = cards.id)
                     WHERE (activecalls.id IS NOT NULL OR
                           cards.call_count != 0 OR
                           payments.id IS NOT NULL) AND
                           cards.cardgroup_id = #{options[:cardgroup_id]} AND
                           cards.number BETWEEN #{options[:start_num]} AND #{options[:end_num]}
                     GROUP BY cards.id
                     LIMIT 10000) tmp USING(id)"
      begin
        rows_affected = ActiveRecord::Base.connection.update(query)
        cards_hidden += rows_affected
      end while rows_affected > 0
    end

    return  cards_hidden
  end


  def self.search(user_id, conditions, options)
    cond, vars = [], []
    user = User.where(id: user_id).first
    if user and user.usertype == "user"
      cond << ['user_id = ?']; vars << user_id
    else
      cond << ['owner_id = ?']; vars << user_id
    end

    unless conditions['s_number'].empty?
      cond << "number LIKE ?"
      vars << "#{conditions['s_number']}"
    end

    unless conditions['s_pin'].empty?
      cond << "pin LIKE ?"
      vars << "#{conditions['s_pin']}"
    end

    unless conditions['s_caller_id'].empty?
      cond << "callerid LIKE ?"
      vars << "#{conditions['s_caller_id']}"
    end

    unless conditions['s_balance_min'].empty?
      cond << "balance >= ?"
      vars << conditions['s_balance_min'].to_d
    end

    unless conditions['s_balance_max'].empty?
      cond << "balance <= ?"
      vars << conditions['s_balance_max'].to_d
    end

    if conditions['s_sold'] == "yes"
      cond << "sold = 1"
    elsif conditions['s_sold'] == "no"
      cond << "sold = 0"
    else
      cond << "(sold = 1 OR sold = 0)"
    end

    if conditions['s_active'] == "yes"
      cond << "active = 1"
    elsif conditions['s_active'] == "no"
      cond << "active= 0"
    end

    if conditions['trial']
      cond << "cardgroup_id = #{Cardgroup.first.id}"
    end

    return where([cond.join(" AND "), *vars]).order("number ASC").limit("#{options[:page] * options[:per_page]}, #{options[:per_page]}").all,
        where([cond.join(" AND "), *vars]).count
  end

  def card_before_create
    card_f = Card.select("cards.*, cardgroups.name AS 'ccg_name'").
        joins("LEFT JOIN cardgroups ON (cards.cardgroup_id = cardgroups.id)").
        where(number: self.number.to_s).first
    if card_f
      errors.add(:number, _("Card_with_this_number_already_exists") + " : " + self.number.to_s + " (#{card_f.ccg_name}) ") if (card_f.owner_id == self.owner_id or self.owner_id == 0) and card_f.cardgroup_id != self.cardgroup_id
      return false
    end

    if self.pin.to_s.blank?
      errors.add(:pin, _("Card_pin_is_blank") + " : " + self.number.to_s)
      return false
    end
  end

  def is_not_owned_by?(user)
    user_id = user.usertype == 'accountant' ? 0 : user.id
    owner_id != user_id
  end

  def payments
    pa = nil
    pa = Payment.find(self.user_id) if self.user_id and self.user_id.to_i > 0
    pa
  end

  def has_payment?
    if Payment.where(["paymenttype = ? and user_id = ?", "Card", self.id]).first
      return false
    end
  end

  # converted attributes for user in current user currency
  def balance
    b = read_attribute(:balance)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  def raw_balance
    read_attribute(:balance)
  end

  def balance= value
    if User.current and User.current.currency
      b = (value.to_d / User.current.currency.exchange_rate.to_d).to_d
    else
      b = value
    end
    write_attribute(:balance, b)
  end

  def disable_voucher
    if cardgroup.disable_voucher == true
      voucher = Voucher.where(number: number).first
      if voucher
        voucher.use_date = Time.now
        if voucher.save
          Action.add_action_hash(User.current, {:action => 'Disable_Voucher_when_Card_is_used', :target_id => voucher.id, :target_type => 'Voucher', :data => number, :data2 => id})
        end
      end
    end
  end


  # Add some amount to card.
  # Note that after changeing balance we immediately save the card, since we dont use
  # transactions that's least what we should do. If adding amount to balance or creating
  # payment fails - we do our best to revert everything... but still without useing
  # transactions there are lot's of ways to fail.

  # *Params*
  # +amount+ amount to be added to balance and payment created in system currency

  # *Returns*
  # +boolean+ true changeing balance and creating payment succeeded, otherwise false.
  #    Note that no transactions are used, so if smth goes wrong data might be corrupted.
  def add_to_balance(amount, add_payment=true)
    self.balance += amount
    if self.save
      if add_payment
        if Payment.add_for_card(self, amount * Currency.count_exchange_rate(Currency.get_default, self.cardgroup.tell_balance_in_currency))
          return true
        else
          self.balance -= amount
          self.save
          return false
        end
      else
       Action.add_action_hash(User.current, {:action=>'Added to cards balance', :target_id=>self.id, :target_type=>"card", :data=>Email.nice_number(amount)})
       return true
      end
    else
      return false
    end
  end

  # Disable the card, to do that we need to set it as not sold
  def disable
    self.sold = false
  end

  # Sell card, obviuosly to do that we need to set appropriat setting. But
  # note that card is saved as soon as it is set as sold. Then Payment is
  # created and also saved. Thats because we do our best not to let anyone to
  # create payment without setting card as sold or vice versa. Though as you can
  # see we do not use transactions, but instead if setting as sold or creating
  # payment fails - we do our best to revert everything... but still there are
  # lot's of ways to fail.
  # If card would be allready sold exception should be raised.

  # *Returns*
  # +boolean+ true if card was set as sold and payment generated succesfully,
  #    otherwise false
  def sell(currency=nil, owner_id=nil, description='')
    if self.sold?
      errors.add(:sold, 'Cannot sell already sold card')
      return false
    else
      self.sold = true
      self.active = 1
      if self.save
        #This is jus a crapy hack to make this method work with api and gui
        if currency and owner_id
          balance = self.balance
        else
          balance = self.balance * Currency.count_exchange_rate(Currency.get_default, self.cardgroup.tell_balance_in_currency)
        end
        if Payment.add_for_card(self, balance, currency, owner_id, description)
          self.disable_voucher
          return true
        else
          self.sold = false
          self.save
          return false
        end
      else
        return false
      end
    end
  end

  def sell_from_bach(email, currency, user_id)
    if self.sold?
      errors.add(:sold, 'Cannot sell already sold card')
      return false
    else
      self.active = 1
      self.sold = true
      if self.save
        p = Payment.add_for_card(self, self.balance, currency, user_id)
        p.email = email
        if p.save
          return true
        else
          return false
        end
      else
        return false
      end
    end
  end

=begin
  Check whether the card is sold or not. Before thinking about selling the card
  should check whether it is not sold at this moment, cause no one can sell already
  sold card.

  *Returns*
  +boolean+ true if card is sold, false otherwise
=end
  def sold?
    (self.sold == 1)
  end

  def set_unique_pin
    begin
      pin = random_number(self.cardgroup.pin_length)
    end while Card.where(pin: pin).first
    self.pin = pin
  end

  def set_unique_number
    begin
      number = random_number(self.cardgroup.number_length)
    end while Card.where(number: number, cardgroup_id: self.cardgroup_id).first
    self.number = number
  end

  def balance_with_vat
     self.cardgroup.get_tax.count_tax_amount(self.balance) + balance
  end

  # Hide the card so that no one could see it and set pin and caller id to nil, so that new cards
  # with these parameters could be created. Card can be hidden and no one should be able to unhide it.
  def hide
    Action.add_action_hash(User.current, {:action=>'Card hidden permanently', :target_id=>self.id, :target_type=>"card", :data=>self.callerid, :data2=>self.pin, :data3=>self.number})
    Card.delete_and_hide_from_sql({:cardgroup_id => self.cardgroup_id, :start_num => self.number, :end_num => self.number})
    #self.write_attribute(:pin, "DELETED_#{Time.now.to_i}_" + self.pin.to_s)
    #self.write_attribute(:callerid, nil)
    #self.write_attribute(:number, "DELETED_#{Time.now.to_i}_" + self.number.to_s)
    #self.write_attribute(:hidden, 1)
    #self.save(:validate => false)
  end

  def self.conditions_of_the_list(options, card_group)
    cond, var = ["cards.cardgroup_id = #{card_group.id}"], []
    cond << "cards.hidden = 0"
    ["number", 'name', 'pin', 'callerid', 'batch_number'].each do |col|
      add_contition_and_param_like(options["s_#{col}".to_sym], options["s_#{col}".intern], "cards.#{col} LIKE ?", cond, var)
    end

    add_integer_contition_and_param(options[:s_balance_min], options[:s_balance_min], "cards.balance >= ?", cond, var)
    add_integer_contition_and_param(options[:s_balance_max], options[:s_balance_max], "cards.balance <= ?", cond, var)

    add_contition_and_param_not_all(options[:s_language], options[:s_language], "cards.language = ?", cond, var)
    add_integer_contition_and_param_not_negative(options[:s_user_id], options[:s_user_id], "cards.user_id = ?", cond, var) if options[:s_user].present?

    cond << "cards.sold = 1" if options[:s_sold].to_s == "yes"
    cond << "cards.sold = 0" if options[:s_sold].to_s == "no"
    return cond, var
  end

  def self.find_calling_cards_for_list(option, card_group, cc_active)
    cond, var = conditions_of_the_list(option, card_group)
    searched = cond.size > 2

    conditions = [cond.join(" AND ")] + var
    cards = self.
              select('cards.*, CONCAT(users.first_name, users.last_name) AS distributor').
              where(conditions).joins('LEFT JOIN users ON users.id = cards.user_id')
    cards = self.from(cards.limit(10).as('cards')) unless cc_active

    cards_all = self.count(:all, :conditions => conditions)
    cards_all = 10 if !cc_active and cards_all > 10

    cards_first_used = self.where("first_use != ''").count(:conditions => conditions)

    return cards, cards_all, searched, cards_first_used
  end

  def self.conditions_of_user_list(options, card_group, current_user)
    cond = ["cards.user_id = #{current_user.id}"]; var =[]

    ["number", 'name', 'pin', 'batch_number'].each { |col|
      add_contition_and_param_like(options["s_#{col}".to_sym], options["s_#{col}".intern], "#{col} LIKE ?", cond, var) }

    add_integer_contition_and_param(options[:s_balance_min], options[:s_balance_min], "cards.balance >= ?", cond, var)
    add_integer_contition_and_param(options[:s_balance_max], options[:s_balance_max], "cards.balance <= ?", cond, var)

    add_contition_and_param_not_all(options[:s_language], options[:s_language], "cards.language = ?", cond, var)
    unless @first_use_check
      cond << "active = 1" if options[:s_active] == "yes"
      cond << "active = 0" if options[:s_active] == "no"
    end
    cond << "cardgroup_id = #{card_group.id}"
    return cond, var
  end

  def self.find_calling_cards_for_user_list(options, card_group, cc_active, current_user)
    cond, var = conditions_of_user_list(options, card_group, current_user)

    searched = (cond.size > 1)

    cards_all = self.count(:conditions => [cond.join(" AND ")] +var)

    cards = self.where([cond.join(" AND ")] +var)

    cond << "first_use != ''"
    cards_first_used = self.count(:conditions => [cond.join(" AND ")] +var)

    return cards, cards_all, searched, cards_first_used
  end

  def to_csv_line(can_see_finances, showing_pin, dec)
    csv_line = ['"'+self.number.to_s+'"']
    csv_line << '"'+self.pin.to_s+'"' if showing_pin
    if can_see_finances
      csv_line << self.balance.to_s.gsub(".", dec)
      csv_line << self.sold
     end
    csv_line << (self.first_use ? nice_date_time(self.first_use) : "")
    csv_line << (self.daily_charge_paid_till ? nice_date(self.daily_charge_paid_till) : "")
    return csv_line
  end

  def update_daily_charge_paid_till(params, current_user)
        # taking only date from daily_charge_paid_till to create new datetime from it ant time
    # that was passed from edit action (to avoid time changing while updating in different TZ)
    daily_charge_paid_till_date = self.daily_charge_paid_till.strftime("%Y-%m-%d ")
    daily_charge_paid_till_time = params[:daily_charge_paid_till_time].blank? ? "00:00:00" : params[:daily_charge_paid_till_time]
    self.daily_charge_paid_till = DateTime.strptime("#{daily_charge_paid_till_date} #{daily_charge_paid_till_time} #{Time.zone.name}", "%Y-%m-%d %H:%M:%S %Z")
    # daily_charge_paid_till are saved in DB converted from GUI timezone into DB timezone
    self.daily_charge_paid_till = current_user.system_time(self.daily_charge_paid_till)
  end

  private

  # Don't think that card shoudl be responsible for generating random
  # number but.. This is a method to generate card's random pin and number
  # that can consist only of numbers.

  # *Returns*
  # +string+ of numbers only, with length as specified
  def random_number(length)
    number = ''
     length.times{
      number << rand(10).to_s
    }
    return number
  end

  def self.add_contition_and_param_like(value, search_value, search_string, conditions, condition_params)
    if !value.blank?
      conditions << search_string
      condition_params << search_value.to_s
    end
  end

  def self.add_integer_contition_and_param(value, search_value, search_string, conditions, condition_params)
    if !value.blank?
      conditions << search_string
      condition_params << quote(search_value.to_s.gsub(',', '.'))
    end
  end

  def self.add_integer_contition_and_param_not_negative(value, search_value, search_string, conditions, condition_params)
    if !value.blank? && (value.to_i != -1)
      conditions << search_string
      condition_params << quote(search_value.to_s.gsub(',', '.'))
    end
  end

  def self.add_contition_and_param_not_all(value, search_value, search_string, conditions, condition_params)
    if value.to_s != _('All')
      conditions << search_string
      condition_params << search_value
    end
  end

  def self.quote(str)
    str.class == String ? ActiveRecord::Base.connection.quote_string(str) : str
  end

  def self.existing_pins(length_of_pin)
    where(['length(pin) = :pin_length', pin_length: length_of_pin]).pluck(:pin)
  end
end
