class ServerLoadstat < ActiveRecord::Base
  attr_accessible :id, :server_id, :datetime, :hdd_util, :cpu_general_load, :cpu_mysql_load, :cpu_ruby_load, :cpu_asterisk_load, :cpu_loadstats1

  belongs_to :server

  def csv_line(*arr)
    output = datetime.strftime('%H:%M').to_s
    arr.each do |stat|
      output << ";#{self[stat.intern]}" if true#self.attributes.has_key? stat.intern
    end
    return output
  end

end
