# -*- encoding : utf-8 -*-
class AlertContact < ActiveRecord::Base
  has_many :alert_contact_groups

  validates :name, presence: { message: _('contact_name_must_be_provided') }
  validates(:max_emails_per_day,
    presence: true,
    numericality: { message: _('max_emails_day_must_be_numerical') }
  )
  validates(:max_emails_per_hour,
    presence: true,
    numericality: { message: _('max_emails_hour_must_be_numerical') }
  )
  validates(:max_sms_per_hour,
    presence: true,
    numericality: { message: _('max_sms_hour_must_be_numerical') }
  )
  validates(:max_sms_per_day,
    presence: true,
    numericality: { message: _('max_sms_day_must_be_numerical') }
  )
  validates(:email,
    format: { :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, message: _('invalid_email') }
  )

  before_save -> { name.try(:strip!) }
  before_destroy :check_groups

  private

  def check_groups
    unless alert_contact_groups.count.zero?
      errors.add(:goups, _('contact_is_used_in_groups')) and return false
    end
  end


end
