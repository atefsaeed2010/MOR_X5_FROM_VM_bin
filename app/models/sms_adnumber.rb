# -*- encoding : utf-8 -*-
class SmsAdnumber < ActiveRecord::Base

  attr_protected

  belongs_to :sms_campaign
  has_many :ivr_action_logs
end
