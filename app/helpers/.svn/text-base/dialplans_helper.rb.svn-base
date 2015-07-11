# -*- encoding : utf-8 -*-
module DialplansHelper
  def show_check(dp)
    return (
      dp.tell_time or dp.tell_hour or dp.tell_sec
      )
  end

  def show_cross(dp)
    return (
      !dp.tell_time and !dp.tell_hour and !dp.tell_sec
      )
  end
end
