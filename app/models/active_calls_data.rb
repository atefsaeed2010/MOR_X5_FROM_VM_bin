class ActiveCallsData < ActiveRecord::Base
  attr_accessible :id, :time, :count

  def self.find_by_day(time)
    if time.class.eql? ActiveSupport::TimeWithZone
      interval_from = time.beginning_of_day.localtime
      interval_to = time.end_of_day.localtime
      select('time, count').where("time BETWEEN '#{interval_from}' AND '#{interval_to}'").all
    end
  end

  def self.find_from_timestamp(timestamp)
    interval_from = timestamp.localtime
    select('time, count').where("time > '#{interval_from}'").all
  end
end