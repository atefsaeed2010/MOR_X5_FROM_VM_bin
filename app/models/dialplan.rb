# -*- encoding : utf-8 -*-
class Dialplan < ActiveRecord::Base
  attr_protected

  has_one :ivr_sound_file
  has_many :dids, :class_name => 'Did', :foreign_key => 'dialplan_id'
  belongs_to :user

  before_save :dp_before_save

  def dp_before_save
    self.user_id = User.current.usertype == "accountant" ? 0 : User.current.id
  end

  def ringgroup
    Ringgroup.where(id: data1).first
  end

  #  def dids
  #    Did.find(:all, :conditions => "dialplan_id = #{self.id}")
  #  end

  def destroy_all
    if self.dptype == 'ivr'
      Extline.delete_all("exten = 'dialplan#{self.id}'")
    end
    Extline.delete_all(["exten = ?", "dp#{self.id}"])
    self.destroy
  end

  def pbxfunction

    pf = nil
    pf = Pbxfunction.find(self.data1) if self.data1 and self.data1.to_i > 0
    pf

  end

  def regenerate_ivr_dialplan()
    if self.dptype == 'ivr'
      months = %w(jan feb mar apr may jun jul aug sep oct nov dec)
      #      ivr_collection = []
      #
      #      extlines = Extline.find(:all, :conditions => "exten = 'dialplan#{self.id}'")
      #      for line in extlines do
      #        if line["app"] == "GotoIfTime" or line["app"] == "GoTo"
      #          data = line["appdata"].split("?").last.split(',').first
      #          first_ivr_block =  data.split("ivr_block")[1].to_i
      #          ivr = Ivr.find(:first, :conditions => "start_block_id = #{first_ivr_block}")
      #          for block in ivr.ivr_blocks do
      #            Extline.delete_all("context = 'ivr_block#{block.id}'")
      #          end
      #        end
      #      end
      Extline.delete_all("exten = 'dialplan#{self.id}'")

      # first debug line ---------------------
      dialplan = self
      context = "mor"
      exten = "dialplan#{dialplan.id}"
      app = "NoOp"
      appdata = "Dial Plan #{dialplan.id} reached"
      Extline.mcreate(context, "1", app, appdata, exten, "0")
      # second line ----- first IVR
      if dialplan["data2"].to_i != 0
        ivr1 = Ivr.where("id = #{dialplan["data2"].to_i}").first
        #        ivr_collection << ivr1
        app = "GotoIfTime"
        if dialplan["data1"].to_i != 0
          t = IvrTimeperiod.where("id = #{dialplan["data1"].to_i}").first
          appdata = t.start_hour.to_s+":"+t.start_minute.to_s+"-"+t.end_hour.to_s+":"+t.end_minute.to_s+"|"
          t.start_weekday == "0" ? appdata += "mon-" : appdata += t.start_weekday+"-"
          t.end_weekday == "0" ? appdata += "sun|" : appdata += t.end_weekday+"|"
          t.start_day.to_i == 0 ? appdata += "1-" : appdata += t.start_day.to_s+"-"
          t.end_day.to_i == 0 ? appdata += "31|" : appdata += t.end_day.to_s+"|"
          t.start_month.to_i == 0 ? appdata += months[0]+"-" :appdata += months[t.start_month.to_i-1]+"-"
          t.end_month.to_i == 0 ? appdata += months[11] :appdata += months[t.end_month.to_i-1]
          appdata +="?ivr_block#{ivr1.start_block_id}|s|1"
        else
          appdata = "*|*|*|*?ivr_block#{ivr1.start_block_id}|s|1"
        end
      else
        app = "NoOp"
        appdata = "First_Block_Not_Set"
      end
      Extline.mcreate(context, "2", app, appdata, exten, "0")
      # third line --------- second IVR
      if dialplan["data4"].to_i != 0
        ivr2 = Ivr.where("id = #{dialplan["data4"].to_i}").first
        #        ivr_collection << ivr2
        app = "GotoIfTime"
        if dialplan["data3"].to_i != 0
          t = IvrTimeperiod.where("id = #{dialplan["data3"].to_i}").first
          appdata = t.start_hour.to_s+":"+t.start_minute.to_s+"-"+t.end_hour.to_s+":"+t.end_minute.to_s+"|"
          t.start_weekday == "0" ? appdata += "mon-" : appdata += t.start_weekday+"-"
          t.end_weekday == "0" ? appdata += "sun|" : appdata += t.end_weekday+"|"
          t.start_day.to_i == 0 ? appdata += "1-" : appdata += t.start_day.to_s+"-"
          t.end_day.to_i == 0 ? appdata += "31|" : appdata += t.end_day.to_s+"|"
          t.start_month.to_i == 0 ? appdata += months[0]+"-" :appdata += months[t.start_month.to_i-1]+"-"
          t.end_month.to_i == 0 ? appdata += months[11] :appdata += months[t.end_month.to_i-1]
          appdata +="?ivr_block#{ivr2.start_block_id}|s|1"
        else
          appdata = "*|*|*|*?ivr_block#{ivr2.start_block_id}|s|1"
        end
      else
        app = "NoOp"
        appdata = "Second_Block_Not_Set"
      end
      Extline.mcreate(context, "3", app, appdata, exten, "0")
      # Fourth line ------------ Third IVR
      if dialplan["data6"].to_i != 0
        ivr3 = Ivr.where("id = #{dialplan["data6"].to_i}").first
        #        ivr_collection << ivr3
        app = "GotoIfTime"
        if dialplan["data5"].to_i != 0
          t = IvrTimeperiod.where("id = #{dialplan["data5"].to_i}").first
          appdata = t.start_hour.to_s+":"+t.start_minute.to_s+"-"+t.end_hour.to_s+":"+t.end_minute.to_s+"|"
          t.start_weekday == "0" ? appdata += "mon-" : appdata += t.start_weekday+"-"
          t.end_weekday == "0" ? appdata += "sun|" : appdata += t.end_weekday+"|"
          t.start_day.to_i == 0 ? appdata += "1-" : appdata += t.start_day.to_s+"-"
          t.end_day.to_i == 0 ? appdata += "31|" : appdata += t.end_day.to_s+"|"
          t.start_month.to_i == 0 ? appdata += months[0]+"-" :appdata += months[t.start_month.to_i-1]+"-"
          t.end_month.to_i == 0 ? appdata += months[11] :appdata += months[t.end_month.to_i-1]
          appdata +="?ivr_block#{ivr3.start_block_id}|s|1"
        else
          appdata = "*|*|*|*?ivr_block#{ivr3.start_block_id}|s|1"
        end
      else
        app = "NoOp"
        appdata = "Third_Block_Not_Set"
      end
      Extline.mcreate(context, "4", app, appdata, exten, "0")
      # fifth line ------- Fourth - default IVR
      if dialplan["data7"].to_i != 0
        ivr4 = Ivr.where("id = #{dialplan["data7"].to_i}").first
        #        ivr_collection << ivr4
        app = "Goto"
        appdata = "ivr_block#{ivr4.start_block_id}|s|1"
      else
        app = "NoOp"
        appdata = "Default_Block_Not_Set"
      end
      Extline.mcreate(context, "5", app, appdata, exten, "0")
      servers = Server.where(:server_type => 'asterisk').all
      servers.each { |server| server.ami_cmd("extensions reload") }
    end
  end

  def type_id=(value)
    self.data1 = value
  end

  def ext=(value)
    self.data2 = value
  end

  def currency=(value)
    self.data3 = value
  end

  def language=(value)
    self.data4 = value
  end

  def sound_file_name
    sf = IvrSoundFile.includes(:ivr_voice).where(:id => self.sound_file_id).references(:ivr_voice).first
    return (sf) ? "#{sf.ivr_voice.voice}/#{sf.path}" : ""
  end

=begin
  'Tell time' status depends on whether to to tell time and whether to tell seconds.

  *Params*
  +tell_time+ - number specifying whether to tell time
  +tell_hours+ - number specifying wheter to tell hours
  +tell_seconds+ - number specifying wheter to tell seconds

  *Returns*
  Integer number depending on params returns 0, 1, 2, 3 or 4.
=end
  def tell_time_status(tell_time=0, tell_hours=0, tell_seconds=0)
    if tell_time.to_i == 0
      return 0
    elsif (tell_hours.to_i == 1 && tell_seconds.to_i == 1)
      return 4
    elsif tell_seconds.to_i == 1
      return 2
    elsif tell_hours.to_i == 1
      return 3
    else
      return 1
    end
  end

=begin
  *Returns*
  false or true depending on whether to tell time or not
=end
  def tell_time
    self.data3 == "1" or self.data3 == "4"
  end

=begin
  *Returns*
  false or true depending on whether to tell seconds or not
=end
  def tell_sec
    self.data3 == "2" or self.data3 == "4"
  end

  def tell_hour
    self.data3 == "3" or self.data3 == "4"
  end

  def Dialplan.change_tell_balance_value(value)
    dls = Dialplan.where('dptype = "quickforwarddids"').all
    if dls and dls.size.to_i > 0
      for d in dls
        d.data1 = value
        d.save
      end
    end
  end

  def Dialplan.change_tell_time_value(value)
    dls = Dialplan.where('dptype = "quickforwarddids"').all
    if dls and dls.size.to_i > 0
      for d in dls
        d.data2 = value
        d.save
      end
    end
  end

  def self.new_pin_auth_dp

    return if Dialplan.where(:dptype => 'authbypin').first

    dp = Dialplan.new
    dp.name = "Authenticate by PIN Dial-Plan"
    dp.dptype = "authbypin"
    dp.save

    dp_ext = "dp"+dp.id.to_s

    # dp extlines

    Extline.mcreate(Default_Context, 1, "Set", "STEP=0", dp_ext, 0)
    Extline.mcreate(Default_Context, 2, "Set", "MOR_AUTH_BY_PIN=1", dp_ext, 0)
    Extline.mcreate(Default_Context, 3, "Set", "MOR_AUTH_BY_PIN_TRY_TIMES=3", dp_ext, 0)
    Extline.mcreate(Default_Context, 4, "mor", "", dp_ext, 0)
    Extline.mcreate(Default_Context, 5, "Set", "STEP=$[${STEP}+1]", dp_ext, 0)
    Extline.mcreate(Default_Context, 6, "GotoIf", "$[$[\"${DIALSTATUS}\" != \"ANSWERED\"] && $[${STEP} < 3]]]?7:9  ", dp_ext, 0)
    Extline.mcreate(Default_Context, 7, "Playback", "mor/morcc_unreachable", dp_ext, 0)
    Extline.mcreate(Default_Context, 8, "Goto", "2", dp_ext, 0)
    Extline.mcreate(Default_Context, 9, "Hangup", "", dp_ext, 0)
  end

  def self.create_dialplan_for_pbx(pbxfunction, params, current_user)
    dialplan = Dialplan.new({:name => params[:name], :dptype => "pbxfunction", :data1 => params[:type_id], :data2 => params[:ext]})

    pf_type = pbxfunction.pf_type

    if pbxfunction and pf_type == "tell_balance"
      def_currency = Currency.find(1)
      dialplan.data3 = def_currency.name if def_currency
      dialplan.data4 = "en"
      dialplan.data5 = "user"
    end

    if pbxfunction and pf_type == "use_voucher"
      def_currency = Currency.find(1)
      dialplan.data3 = def_currency.name if def_currency
      dialplan.data4 = "en"
    end

    if pbxfunction and pf_type == "external_did"
      dialplan.data5 = current_user.id
    end

    dialplan.save
    return dialplan
  end

  def fabricate(params)
    #IVR update logic is pretty narrow, no need for a separate class.
    if dptype == 'ivr'
      self.assign_attributes(params[:dialplan])
    else
      #Creates an instance of a fabricator(a.k.a. constructor)
      fabricator = "Dialplans::#{dptype.capitalize}".constantize.new(self)

      fabricator.fabricate(params)
    end
  end
end
