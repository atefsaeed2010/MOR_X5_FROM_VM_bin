# -*- encoding : utf-8 -*-
class SmsAdaction < ActiveRecord::Base
  belongs_to :sms_campaign

  attr_protected


  def file_name
    data.to_s.split(".").first
  end

  def update_action(params)
      if self.action == "SEND"
      self.data = params[:SMS_message].to_s
      self.data = "" if self.data.nil?
      self.data2 = params[:sms_counter].to_s
      self.data3 = params[:sms_unicode].to_s
    end
  end

  def destroy_action
    if self.action == "PLAY"
      path, final_path = self.campaign.final_path
      Audio.rm_sound_file("#{final_path}/#{self.file_name}.wav")
    end
    self.destroy
  end

end

