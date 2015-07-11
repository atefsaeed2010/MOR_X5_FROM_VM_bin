class LcrTimeperiod < ActiveRecord::Base

  belongs_to	:main_lcr, :class_name => 'Lcr' # LcrTimeperiod.find(id).main_lcr returns main lcr
  belongs_to	:lcr  				# LcrTimeperiod.find(id).lcr returns change lcr

  before_save	:check_dates, :lcr_present

  attr_accessible :main_lcr_id, :name

  # A: Validating period pairing.
  def check_dates
    parser = lambda { |key| [2,0].include? [self["start_#{key}"],self["end_#{key}"]].select(&:blank?).size }
    set = ['month', 'day', 'weekday']

    if set.map(&parser).include?(false)
      errors.add(:lcr_timeperiod, _("Invalid_Date_period"))
      return false
    else
      return true
    end
  end

  def lcr_present
    if self.lcr_id.blank?
      errors.add(:lcr_timeperiod, _("LCR_must_be_selected_for_activated_Time_Period"))
      return false
    end
  end

end
