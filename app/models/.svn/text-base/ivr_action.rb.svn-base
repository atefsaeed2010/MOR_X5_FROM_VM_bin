# -*- encoding : utf-8 -*-
class IvrAction < ActiveRecord::Base
  belongs_to :ivr_block

  attr_protected

 def clear_data_fields
    self.data1 = ''
    self.data2 = ''
    self.data3 = ''
    self.data4 = ''
    self.data5 = ''
   self.data6 = ''
  end

  def set_action_data(params)
     case params[:number]
      when '2'
        self.data2 = params[:data]
      when '3'
        self.data3 = params[:data]
      when '4'
        self.data4 = params[:data]
     when '5'
        self.data5 = params[:data]
      when '6'
        self.data6 = params[:data]
      else
        self.data1 = params[:data]
    end
  end

  def set_sound_file(user)
    if self.name == 'Playback'
      if !self.data1.blank?
        file = user.ivr_sound_files.joins("LEFT JOIN ivr_voices ON (ivr_voices.id = ivr_sound_files.ivr_voice_id)").where(["ivr_voices.voice = ?", self.data1]).first
      end
      if file
        self.data2 = file.path
      else
        self.data2 = ""
      end
    end
  end

  def set_transfer_data(user)
    if self.name == 'Transfer To'
      case self.data1
        when 'IVR'
          ivr = user.ivrs.first
          self.data2 = ivr ? ivr.start_block_id : 0
        when 'DID'
          did = user.load_dids({first: true, conditions: "status = 'active'"})
          self.data2 = did ? did.did : 0
        when 'Device'
          device = Device.find_by_sql("SELECT devices.id as id, users.first_name as first_name, users.last_name as last_name, devices.device_type as dev_type, devices.name as dev_name, devices.extension as dev_extension FROM devices LEFT JOIN users ON (devices.user_id = users.id) WHERE devices.user_id > -1 AND users.owner_id = #{user.id}")
          self.data2 = device[0] ? device[0].dev_extension : 0
        when 'Block'
          block = self.ivr_block.ivr.start_block_id
          self.data2 = block ? block : 0
      end
    end
  end

  def update_action_data(user, variables)
    case self.name
      when "Playback"
        voice = user.ivr_voices.first
        voice ? self.data1 = voice.voice : self.data1 = ""
        if !self.data1.blank?
          sound_file = user.ivr_sound_files.joins("LEFT JOIN ivr_voices ON (ivr_voices.id = ivr_sound_files.ivr_voice_id)").where(["ivr_voices.voice = ?", self.data1]).first
        end
        if sound_file
          self.data2 = sound_file ? sound_file.path.to_s : ""
        end
      when "Delay"
        self.data1 = 0
      when "Change Voice"
        self.data1 = user.ivr_voices.first ? user.ivr_voices.first.voice.to_s : ""
      when "Hangup"
        self.data1 = "Busy"
      when "Transfer To"
        self.data1 ="IVR"
        self.data2 = user.ivrs.first.id
      when "Debug"
        self.data1 = "#{self.ivr_block.name}_was_reached."
      when "Set Accountcode"
        self.data1 = user.load_users_devices({first: true, conditions: "user_id > -1", order: 'devices.id'}).id
      when "Mor"
      when "Set Variable"
       self.data1 = variables[0]
        self.data2 = "0"
      when "Change CallerID (Number)"
        self.data1 = 0
    end
  end

  def update_data_1(current_user, params)
    self.set_action_data(params)
    if self.name == 'Delay'
      self.data1 = (params[:data].to_i > 0) ? params[:data].to_i : 2
    end
    self.set_transfer_data(current_user)
    self.set_sound_file(current_user)
    if self.name == "Change CallerID (Number)"
      self.data1 = params[:data].gsub(/\"|\'/, '')
    end

  end
end
