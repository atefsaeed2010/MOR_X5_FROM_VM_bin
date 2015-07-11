# -*- encoding : utf-8 -*-
class SmsRate < ActiveRecord::Base
  attr_protected

  belongs_to :sms_tariff
  has_many :sms_ratedetails, -> { order("start_time ASC") }

  def destination
    destination = Destination.where("prefix='#{self.prefix}'").first
  end
end
