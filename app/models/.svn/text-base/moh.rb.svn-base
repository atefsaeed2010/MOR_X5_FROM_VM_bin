# -*- encoding : utf-8 -*-
class Moh < ActiveRecord::Base

  def asterisk_moh_reload
    exceptions = []
    servers = Server.where(:active => 1, :core => 1, :server_type => 'asterisk').all
    servers.each do |server|
      begin
        server.ami_cmd('moh reload')
      rescue => e
        exceptions << e
      end
    end
    exceptions
  end

end
