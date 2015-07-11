#!/usr/bin/env ruby

=begin
require 'rubygems'
require 'pathname'
require 'active_record'
require 'mysql2'

ActiveRecord::Base.configurations = YAML::load(IO.read('/home/mor/config/database.yml'))
ActiveRecord::Base.establish_connection('production')
=end

ENV['RAILS_ENV'] = ARGV.first || ENV['RAILS_ENV'] || 'production'
require File.expand_path(File.dirname(__FILE__) + "/../../config/environment")

campaigns = SmsCampaign.where("status = \"enabled\" and start_time < ? and stop_time > ?", Time.now, Time.now)

puts "Found #{campaigns.size} campaigns\n"

campaigns.each { |campaign|

  user = User.find(:first, :conditions => ["id=?", campaign.user_id])

  adactions = campaign.sms_adactions.where(:priority => 1).limit(1)

  numbers = campaign.sms_adnumbers.where(:status => "new")

  params = Hash.new

 # Reactivate this code when going live
numbers.each { |number|
  number.status = "executed"
  number.save
  }

  numbers.each { |number|

    # get daytype and localization settings
    day = Time.now
    if campaign.owner.usertype == 'reseller'
      usable_location = 'A.location_id = locations.id AND A.location_id != 1'
    else
      if campaign.device.location
        usable_location = 'A.location_id = locations.id'
      else
        usable_location = 'A.location_id = locations.id OR A.location_id = 1'
      end
    end
    sql = "SELECT  A.*, (SELECT IF((SELECT daytype FROM days WHERE date = '#{day}') IS NULL,
(SELECT IF(WEEKDAY('#{day}') = 5 OR WEEKDAY('#{day}') = 6, 'FD', 'WD')),
(SELECT daytype FROM days WHERE date = '#{day}')))   as 'dt' FROM devices
JOIN locations ON (locations.id = devices.location_id)
LEFT JOIN (SELECT * FROM locationrules WHERE  enabled = 1 AND lr_type = 'dst' AND LENGTH('#{number.number}')
BETWEEN minlen AND maxlen AND (SUBSTRING('#{number.number}',1,LENGTH(cut)) = cut OR LENGTH(cut) = 0 OR ISNULL(cut))
ORDER BY LENGTH(cut) DESC ) AS A ON ( #{usable_location}) WHERE devices.id = #{campaign.device.id}"
    #my_debug "1"
    res = ActiveRecord::Base.connection.select_one(sql)
    @daytype = res['dt']
    @loc_add = res['add']
    @loc_cut = res['cut']
    @loc_rule = res['name']
    @loc_lcr_id = res['lcr_id']
    @loc_tariff_id = res['tariff_id']
    @loc_device_id = res['device_id']

    loc_dst = Location.nice_locilization(@loc_cut, @loc_add, number.number)

    adactions.each { |adaction|

      puts number.number
      puts loc_dst
      puts adaction.data2
      puts user.sms_lcr.name
      user.sms_tariff

      sms = SmsMessage.new
      sms.sending_date = Time.now
      sms.user_id = user.id
      sms.reseller_id = user.owner_id
      sms.number = number.number
      sms.save

      number.executed_time = Time.now
      number.completed_time = ""

      begin
        sms.sms_send(user, user.sms_tariff, loc_dst, user.sms_lcr, adaction.data2.to_i, adaction.data, {:src => campaign.callerid.to_s, :unicode => adaction.data3.to_s})
      rescue Errno::ECONNREFUSED => e
        sms.status_code = "009"
        puts e
      rescue => e
        sms.status_code = "001"
        puts e
      ensure
        sms.save
      end

      if sms.sms_status_code == "sent"
        number.status = "completed"
        number.completed_time = Time.now
      end
      }

      number.save

    }
  }

