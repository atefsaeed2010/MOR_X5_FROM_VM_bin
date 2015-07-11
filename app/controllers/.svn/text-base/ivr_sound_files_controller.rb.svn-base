# -*- encoding : utf-8 -*-
class IvrSoundFilesController < ApplicationController

  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize

  before_filter :find_ivr_voice, :only => [:create]
  before_filter :find_ivr_sound_file, :only => [:destroy, :play_sound, :edit, :update]
  before_filter :check_reseller

  def new
    @page_title = _('New_IVR_Sound_File')
    @page_icon = "add.png"
    @id = params[:id]
  end

=begin
  Before filter variables: @voice
=end

  def create
    @sound = IvrSoundFile.new({:ivr_voice_id => params[:id], :description => params[:description]})

    notice, name = Audio.create_file(params[:file], @voice, "/var/lib/asterisk/sounds/mor/ivr_voices/")
    if notice.blank?
      @sound.path = name + '.wav'
      @sound.size = params[:file].size.to_i
      if @sound.save
        flash[:status] = _("Sound_File_Was_Uploaded")
      else
        flash_errors_for(_("File_Not_Uploaded"), @sound)
      end
    else
      flash[:notice] = notice
    end
    redirect_to :controller => :ivrvoices, :action => :edit, :id => params[:id]
  end

  #
  # @file set in before_filter (find_ivr_sound_file)
  #
  def destroy
    @voice = @file.voice

    if @file.readonly.to_i == 1
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to :controller => :ivrvoices, :action => :edit, :id => @voice.id and return false
    end

    queue = AstQueue.where("announce = #{@file.id} OR join_announcement = #{@file.id}").all
    queue_announcements = QueuePeriodicAnnouncement.where(:ivr_sound_files_id => @file.id).all
    if !IvrAction.where(["name = 'Playback' and data2 = ?", @file.path]).first and queue.blank? and queue_announcements.blank?

      @file.destroy_with_file
      flash[:status] = _("Sound_File_Deleted")
    elsif !queue.blank?
      notice = _("Sound_file_assigned_to_queues")
    elsif !queue_announcements.blank?
      notice = _("Sound_file_assigned_to_queues_announcement")
    else
      notice = _("Sound_File_Can_Not_Be_Deleted_In_Use")
    end
    unless notice.blank?
      flash[:notice] = notice
    end
    redirect_to :controller => :ivrvoices, :action => :edit, :id => @voice.id
  end

  #
  # @file set in before_filter (find_ivr_sound_file)
  #
  def play_sound
    @voice = @file.voice
    @dir = Confline.get_value("IVR_Voice_Dir")
    @title = Confline.get_value("Admin_Browser_Title")
    dst = @dir + @voice.voice+"/"+@file.path
    @dst = Web_Dir+"/ivr_voices/"+@voice.voice+"/"+@file.path
    if !File.exists?(dst)
      redirect_to :root and return false
    else
      render(:layout => "play_rec")
    end
  end

  #
  # @file set in before_filter (find_ivr_sound_file)
  #
  def edit
    @page_title = _('Edit_IVR_Sound_File')
    @page_icon = "edit.png"
  end

  #
  # @file set in before_filter (find_ivr_sound_file)
  #
  def update
    if !IvrAction.where(["name = 'Playback' and data1 = ?", @file.path]).first
      @file.description = params[:description]
      @file.save
      flash[:status] = _("Sound_File_Updated")
    else
      flash_errors_for(_("Sound_File_Was_Not_Updated"), @file)
    end

    redirect_to :controller => :ivrvoices, :action => :edit, :id => @file.ivr_voice_id
  end

  private

  def find_ivr_voice
    @voice = current_user.ivr_voices.where(["id = ?", params[:id]]).first
    unless @voice
      flash[:notice] = _("Ivr_Voice_Was_Not_Found")
      redirect_to :root
    end
  end

  def find_ivr_sound_file
    @file = current_user.ivr_sound_files.where(["id = ?", params[:id]]).first

    unless @file
      flash[:notice] = _("Ivr_Sound_File_Was_Not_Found")
      redirect_to :root
    end
  end

  def check_reseller
    if reseller? and current_user.own_providers.to_i == 0
      dont_be_so_smart
      redirect_to :root
    end
  end

end
