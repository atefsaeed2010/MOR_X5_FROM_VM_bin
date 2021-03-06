# -*- encoding : utf-8 -*-
class Extline < ActiveRecord::Base
  attr_accessible :id ,:context ,:exten ,:priority ,:app ,:appdata ,:device_id

  attr_protected

  #creating extension by parameters
  def self.mcreate(context, priority, app, appdata, extension, device_id)

    sep = ','
    if appdata == "$[$[\"${DIALSTATUS}\" = \"CHANUNAVAIL\"]|$[\"${DIALSTATUS}\" = \"CONGESTION\"]]?301"
      # do not touch this line, here | means OR operator
      rappdata = appdata
    else
      rappdata = appdata.to_s.gsub('|', ',')
    end

    ext = self.new(:context => context, :exten => extension, :priority => priority, :app => app, :appdata => rappdata, :device_id => device_id)
    ext.save
    ext
  end

  def self.update_timeout(timeout_response, timeout_digit)
    if (1..60).include?(timeout_response.to_i) and (1..60).include?(timeout_digit.to_i)
      cond = "exten = ? AND context = ? AND priority IN (2, 3) AND appdata like ?"
      Extline.update_all({:appdata => "TIMEOUT(response)=#{timeout_response.to_i}"},
                         [cond, '_X.', "mor", 'TIMEOUT(response)%'])
      Extline.update_all({:appdata => "TIMEOUT(digit)=#{timeout_digit.to_i}"},
                         [cond, '_X.', "mor", 'TIMEOUT(digit)%'])
    else
      return false
    end
  end
end
