# -*- encoding : utf-8 -*-
class Activecall < ActiveRecord::Base
  attr_accessible :id, :server_id, :uniqueid, :start_time, :answer_time, :transfer_time, :src,
    :dst, :src_device_id, :dst_device_id, :channel, :dstchannel, :prefix, :provider_id, :did_id,
    :user_id, :owner_id, :localized_dst, :card_id, :user_rate, :lega_codec, :legb_codec, :pdd

  belongs_to :provider
  belongs_to :user
  belongs_to :did
  belongs_to :server

  def src_device
    Device.where(id: self.src_device_id).first
  end

  def dst_device
    Device.where(id: dst_device_id).first
  end

  def destination
    Destination.where(prefix: self.prefix).first
  end

  def duration
    Time.now.getlocal - Time.parse(answer_time.to_s)
  end

  def get_user_rate(user = nil, destination = nil)
#    user = self.user unless user
#    destination = self.destination unless destination
#
#    user_rate = nil
#    user_rate = self.user_rate
#    unless user_rate and destination
#      rate = Rate.find(:first, :include => [:ratedetails], :conditions => ["rates.tariff_id = ? AND rates.destination_id = ?", user.tariff_id, destination.id]).ratedetails[0]
#      user_rate = rate.rate.to_d
#    end
    user_rate = self.user_rate ? self.user_rate.to_d : 0.to_d
    return User.current.get_rate(user_rate)
  end

  def Activecall.count_for_user(user)
    hide_active_calls_longer_than = Confline.get_value('Hide_active_calls_longer_than', 0).to_i
    hide_active_calls_longer_than = 24 if hide_active_calls_longer_than.zero?
    if user and user.id and user.usertype
      if user.usertype == "admin" or user.usertype == 'accountant'
        return Activecall.where("(DATE_ADD(activecalls.start_time, INTERVAL #{hide_active_calls_longer_than} HOUR) > NOW())").count
      else
        if user.usertype == "reseller"
          #reseller
          user_sql = " WHERE (activecalls.user_id = #{user.id} OR dst_usr.id = #{user.id} OR  activecalls.owner_id = #{user.id} OR dst_usr.owner_id =  #{user.id}) AND (DATE_ADD(activecalls.start_time, INTERVAL #{hide_active_calls_longer_than} HOUR) > NOW()) "
        else
          #user
          user_sql = " WHERE (activecalls.user_id = #{user.id} OR dst_usr.id = #{user.id}) AND (DATE_ADD(activecalls.start_time, INTERVAL #{hide_active_calls_longer_than} HOUR) > NOW()) "
        end
        sql = "
        SELECT COUNT(*)
        FROM activecalls
        LEFT JOIN devices AS dst ON (dst.id = activecalls.dst_device_id)
        LEFT JOIN users AS dst_usr ON (dst_usr.id = dst.user_id)
        #{user_sql}"
        return ActiveRecord::Base.connection.select_value(sql)
      end
    end
    return 0
  end
end
