# -*- encoding : utf-8 -*-
class Adaction < ActiveRecord::Base
  belongs_to :campaign

  attr_protected

  def file_name
    data.to_s.split(".")[0]
  end

  def update_action(params, user)
  	notice = ''
    action = self.action

    if action == 'WAIT'
      self.data = params[:wait_time].to_i
      self.data = 1 if self.data < 1
    end

    if action == 'IVR'
      ivr = params[:ivr]

      if user.ivrs(ivr)
        self.data = ivr
      else
        notice = 'dont_be_so_smart'
      end
    end

    if action == 'PLAY'
      notice, name = Audio.create_file(params[:file], self.campaign, "/var/lib/asterisk/sounds/mor/ad/")

      if notice.blank?
        self.data = name
      end
    end

    return notice
  end

  def destroy_action
  	if self.action == "PLAY"
      path, final_path = self.campaign.final_path
      Audio.rm_sound_file("#{final_path}/#{self.file_name}.wav")
    end

    self.destroy
  end
end
