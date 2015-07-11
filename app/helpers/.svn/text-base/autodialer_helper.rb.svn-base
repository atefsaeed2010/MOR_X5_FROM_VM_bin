# -*- encoding : utf-8 -*-
module AutodialerHelper
  def nice_time_in_user_tz(time)
    hours, minutes, seconds = time.hour, time.min, time.sec
    time = time_in_user_tz(hours, minutes, seconds)

    time.strftime('%H:%M:%S')
  end

  def time_in_user_tz(hours, minutes, seconds='00')
    time_str = [hours, minutes, seconds].join(':')

    time = Time.parse(time_str).in_time_zone(user_tz)
    time
  end
end
