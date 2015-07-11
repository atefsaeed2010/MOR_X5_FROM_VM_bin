# -*- encoding : utf-8 -*-
class AlertSchedulePeriod <  ActiveRecord::Base
  attr_accessible :id, :alert_schedule_id, :day_type, :status, :start, :end


  attr_protected

  belongs_to :alert_schedule

  validate :start_check
  validate :end_check

  private

  def start_check
    if self.start > self.end
      errors.add(:start, nil)
    end
  end

  def end_check
    if self.end < self.start
      errors.add(:end, nil)
    end
  end

end
