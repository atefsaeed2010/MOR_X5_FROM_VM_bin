# -*- encoding : utf-8 -*-
class Subscription < ActiveRecord::Base

  attr_protected

  belongs_to :user
  belongs_to :service
  has_many :flatrate_datas, :dependent => :destroy

  validate :subscription_interval_valid
  validate :subscription_start_valid

  before_save :s_before_save

  def subscription_interval_valid
    unless activation_end.blank? or activation_start <= activation_end
      errors.add(:activation_end, _('activation_start_after_activation_end'))
    end
  end

  def subscription_start_valid

    user_registered = 0
    user_registered = user.registered_at.try(:at_beginning_of_month).strftime("%Y-%m-%d %H:%M:%S").to_time.to_i if (user and user.registered_at)
    unless user_registered <= activation_start.strftime("%Y-%m-%d %H:%M:%S").to_time.to_i
      errors.add(:activation_start, _('activation_start_before_user_created'))
    end
  end

  def s_before_save
    if service.servicetype == "one_time_fee"
      self.activation_end = self.activation_start
    end
  end

  def activation_start=(value)
    value = (value.respond_to?(:strftime) ? value.strftime('%F %H:%M:%S') : value)
    write_attribute(:activation_start, value)
  end

  def activation_end=(value)
    value = (value.respond_to?(:strftime) ? value.strftime('%F %H:%M:%S') : value)
    write_attribute(:activation_end, value)
  end

  def time_left
    time = Time.now
    out = 0
    if time > activation_start and (activation_end.blank? or time < activation_end or no_expire == 1)
      year_month = time.strftime("%Y-%m")
      data = no_expire == 1 ? FlatrateData.where(subscription_id: id).last : FlatrateData.where(year_month: year_month, subscription_id: id).first
      out = data.seconds.to_i if data
      out = service.quantity.to_i * 60 - out
    end
    out
  end

  def time_left= (value)
    time = Time.now
    if service.servicetype == "one_time_fee" and time > activation_start and (activation_end.blank? or time < activation_end)
      datas = flatrate_datas(:conditions => ["year_month = ?", time.strftime("%Y-%m")])
      datas.each { |data|
        data.minutes = service.quantity.to_i - value
        data.save
      }
    end
  end

=begin
  lets try to figure out what this method is ment to do..
  When one passes period of time(start & end date), this method
  calculates intersection of period passed and its activation
  period.
  Seems like it is ment to calculate period when subscription
  was active, but only in period that one passed to this method

  For instance if we have two periods
  activation period: 1-------------------3
  period passed:            2--------------------------------4
  method will return period starting from 2 to 3.

  Note that there is a bug when periods do no intersect
  activation period: 1------2
  period passed:                3----------------------------4
  method will return period starting from 3 to 2(OMG!!)
=end
  def subscription_period(period_start, period_end)
    use_start = (activation_start < period_start ? period_start : activation_start)
    use_end = ((activation_end.blank? or (activation_end > period_end)) ? period_end : activation_end)
    return use_start.to_date, use_end.to_date
  end

  def price_for_period(period_start, period_end)
    period_start = period_start.to_s.to_time if period_start.class == String
    period_end = period_end.to_s.to_time if period_end.class == String
    if not activation_end.blank? and (activation_end < period_start or period_end < activation_start)
      return 0
    end
    total_price = 0
    case service.servicetype
      when "flat_rate"
        start_date, end_date = subscription_period(period_start, period_end)
        days_used = end_date - start_date
        if start_date.month == end_date.month and start_date.year == end_date.year
          total_price = service.price
        else
          total_price = 0
          if months_between(start_date, end_date) > 1
            # jei daugiau nei 1 menuo. Tarpe yra sveiku menesiu kuriem nereikia papildomai skaiciuoti intervalu
            total_price += (months_between(start_date, end_date)-1) * service.price
          end
          #suskaiciuojam pirmo menesio pabaigos ir antro menesio pradzios datas
          last_day_of_month = start_date.to_time.end_of_month.to_date
          last_day_of_month2 = end_date.to_time.end_of_month.to_date
          total_price += service.price
          total_price += service.price/last_day_of_month2.day * (end_date.day)
        end
      when "one_time_fee"
        if activation_start >= period_start and activation_start <= period_end
          total_price = service.price
        end
      when "periodic_fee"
        start_date, end_date = subscription_period(period_start, period_end)
        days_used = end_date - start_date
        #if periodic fee if daily month should be the same every time and
        #if condition should evaluate to true every time
        if start_date.month == end_date.month and start_date.year == end_date.year
          if self.service.periodtype == 'month'
            total_days = start_date.to_time.end_of_month.day.to_i
            total_price = service.price / total_days * (days_used.to_i+1)
          elsif self.service.periodtype == 'day'
            total_price = service.price * (days_used.to_i+1)
          end
        else
          total_price = 0
          if months_between(start_date, end_date) > 1
            # jei daugiau nei 1 menuo. Tarpe yra sveiku menesiu kuriem nereikia papildomai skaiciuoti intervalu
            total_price += (months_between(start_date, end_date)-1) * service.price
          end
          #suskaiciuojam pirmo menesio pabaigos ir antro menesio pradzios datas
          last_day_of_month = start_date.to_time.end_of_month.to_date
          last_day_of_month2 = end_date.to_time.end_of_month.to_date
          total_price += service.price/last_day_of_month.day * (last_day_of_month - start_date+1).to_i
          total_price += service.price/last_day_of_month2.day * (end_date.day)
        end
    end
    total_price
  end

  #Counts amount of money to be returned for the rest of current month
  def return_for_month_end
    amount = 0
    case service.servicetype
      when "flat_rate"
        period_start = Time.now
        period_end = Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59)
        start_date, end_date = subscription_period(period_start, period_end)
        days_used = end_date - start_date
        total_days = start_date.to_time.end_of_month.day
        service_price = (service.price.nil? ? 0 : service.price)
        amount = (service_price / total_days.to_i) * (days_used.to_i + 1)
      when "one_time_fee"
        amount = price_for_period(Time.now, Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59)).to_d
      when "periodic_fee"
        if service.periodtype == 'day'
          amount = Action.sum('data2', :conditions => ["action = 'subscription_paid' AND user_id = ? AND data >= ? AND target_id = ?", self.user_id, "#{Time.now.year}-#{Time.now.month}-#{'1'}", self.id])
        else
          amount = price_for_period(Time.now, Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59)).to_d
        end
    end
    logger.debug "Amount: #{amount}"
    return amount.to_d
  end

  def return_money_whole
    user.user_type == "prepaid" ? end_time = Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59) : end_time = Time.now.beginning_of_month
    amount = 0
    case service.servicetype
      when "one_time_fee"
        amount = service.price if end_time > activation_end
      when "flat_rate"
        amount = price_for_period(activation_start, end_time).to_d
      when "periodic_fee"
        case self.service.periodtype
          when 'day'
            amount = self.subscriptions_paid_this_month
          when 'month'
            amount = price_for_period(activation_start, end_time).to_d
        end
    end
    if amount > 0
      Payment.subscription_payment(user, amount * -1)
      user.balance += amount
      return user.save
    else
      return false
    end
  end

=begin
  Counts amount that was paid during current month.
  Note that amount is in system currency and beggining of month is in system timezone

  *Returns*
  +amount+ amount(float) that was paid diring current month for this subscription, might be 0.
=end
  def subscriptions_paid_this_month
    actions = Action.select('SUM(data2) AS amount').where("action = 'subscription_paid' AND target_id = #{self.id} AND date > '#{Time.now.beginning_of_month.to_s(:db)}'").first
    return actions.amount.to_d
  end

  def return_money_month
    amount = 0
    user = self.user
    amount = self.return_for_month_end if user and user.user_type.to_s == "prepaid"
    if amount > 0
      Payment.subscription_payment(user, amount * -1)
      user.balance += amount.to_d
      return user.save
    else
      return false
    end
  end

  def disable
    self.activation_end = Time.now.to_s(:db)
    self.time_left = 0 if service.servicetype == "flat_rate"
  end

  def self.get_activation_year
    this_year = Time.now.year
    min_end   = Subscription.minimum(:activation_end).try(:year) || this_year
    min_start = Subscription.minimum(:activation_start).try(:year) || this_year
    max_end   = Subscription.maximum(:activation_end).try(:year) || this_year
    max_start = Subscription.maximum(:activation_start).try(:year) || this_year
    return min_end, min_start, max_end, max_start
  end

  def update_by(user_id, params)
    self.user_id = user_id
    self.no_expire = params['no_expire'].to_i
    self.added = self.added.change(:sec => 0)
    service = Service.where(["id = ?", self.service_id.to_i]).first
    if service.servicetype == "flat_rate"
      self.activation_start = self.activation_start.beginning_of_month.change(:hour => 0, :min => 0, :sec => 0)
      self.activation_end = self.activation_end.end_of_month.change(:hour => 23, :min => 59, :sec => 59) unless params['until_canceled'].to_i == 1
    end
  end

  def self.get_subscription(id)
    notice = ''
    sub = Subscription.includes(:user, :service).where(["subscriptions.id = ?", id]).first
    if !sub
      notice = _('Subscription_not_found')
    elsif !sub.user
      notice = _('User_not_found')
    elsif !sub.service
      notice = _('Service_not_found')
    end
    return sub, notice
  end

  def delete_by_option(option, user_id)
    status = ''
    case option.to_s
    when "delete"
      Action.add_action_hash(user_id, {:action => 'Subscription_deleted', :target_id => self.id, :target_type => "Subscription", :data => self.user_id, :data2 => self.service_id})
      status = _('Subscription_deleted')
    when "disable"
      Action.add_action_hash(user_id, {:action => 'Subscription_disabled', :target_id => self.id, :target_type => "Subscription", :data => self.user_id, :data2 => self.service_id})
      self.disable
      self.save
      status = _('Subscription_disabled')
    when "return_money_whole"
      Action.add_action_hash(user_id, {:action => 'Subscription_deleted_and_return_money_whole', :target_id => self.id, :target_type => "Subscription", :data => self.user_id, :data2 => self.service_id})
      self.return_money_whole
      status = _('Subscription_deleted_and_money_returned')
    when "return_money_month"
      Action.add_action_hash(user_id, {:action => 'Subscription_deleted_and_return_money_month', :target_id => self.id, :target_type => "Subscription", :data => self.user_id, :data2 => self.service_id})
      self.return_money_month
      status = _('Subscription_deleted_and_money_returned')
    end
  end

  private

  def months_between(date1, date2)
    years = date2.year - date1.year
    months = years * 12
    months += date2.month - date1.month
    months
  end
end
