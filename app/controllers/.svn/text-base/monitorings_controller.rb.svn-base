# -*- encoding : utf-8 -*-
class MonitoringsController < ApplicationController
  layout "callc"

  before_filter :access_denied, :if => lambda { session[:usertype] != 'admin' or !monitorings_addon_active? }
  before_filter :check_post_method, only: [:chanspy]


  # Enable or disable channel spying globaly. Only admin has rights to set this setting and
  # reseller if he has sufficient privileges
  def chanspy
    # checkboxes
    params['blacklist_enabled'] = params['blacklist_enabled'].to_i
    params['default_bl_rules']	= params['default_bl_rules'].to_i
    params['disable_chanspy']	= params['disable_chanspy'].to_i

    session[:ma_setting_options] = params
    value = params[:disable_chanspy].to_i

    # for validating threshold values
    # routing_thresholds = {}
    # routing_thresholds[:routing_threshold] = params['default_routing_threshold'].to_s.strip if params['default_routing_threshold']
    # routing_thresholds[:routing_threshold_2] = params['default_routing_threshold_2'].to_s.strip if params['default_routing_threshold_2']
    # routing_thresholds[:routing_threshold_3] = params['default_routing_threshold_3'].to_s.strip if params['default_routing_threshold_3']
    # blacklist_lcrs = {}
    # blacklist_lcrs[:blacklist_lcr] = params['default_blacklist_lcr'].to_i
    # blacklist_lcrs[:blacklist_lcr_2] = params['default_blacklist_lcr_2'].to_i
    # blacklist_lcrs[:blacklist_lcr_3] = params['default_blacklist_lcr_3'].to_i
    # validate_with_letters = true

    # flash[:notice], err = Application.validate_routing_threshold_values(routing_thresholds, blacklist_lcrs, validate_with_letters)

    # if err == 1
    #   redirect_to :controller => "monitorings", :action => "settings" and return false
    # end

    if params['default_src_score']
      src_score	 = Src_new_score.where(value: 'default').first
      src_score.score = params['default_src_score'].to_s.strip if src_score
      err = 1 unless src_score and src_score.save
    end

    if params['default_dst_score']
      dst_score	 = Dst_new_score.where(value: 'default').first
      dst_score.score = params['default_dst_score'].to_s.strip
      err = 1 unless dst_score.save
    end

    if params['default_ip_score']
      ip_score	 = Ip_new_score.where(value: 'default').first
      ip_score.score	 = params['default_ip_score'].to_s.strip
      err = 1 unless ip_score.save
    end

    if err.to_i.zero?
      Confline.set_value('chanspy_disabled', value, current_user.get_correct_owner_id)
      Confline.set_value('blacklist_enabled', params['blacklist_enabled'].to_i, 0)
      Confline.set_value('default_bl_rules', params['default_bl_rules'].to_i, 0)
      Confline.set_value('default_routing_threshold', params['default_routing_threshold'].to_i, 0)
      Confline.set_value('default_routing_threshold_2', params['default_routing_threshold_2'].to_i, 0)
      Confline.set_value('default_routing_threshold_3', params['default_routing_threshold_3'].to_i, 0)
      Confline.set_value('default_blacklist_lcr', params['default_blacklist_lcr'].strip, 0) if params['default_blacklist_lcr']
      Confline.set_value('default_blacklist_lcr_2', params['default_blacklist_lcr_2'].strip, 0) if params['default_blacklist_lcr_2']
      Confline.set_value('default_blacklist_lcr_3', params['default_blacklist_lcr_3'].strip, 0) if params['default_blacklist_lcr_3']

      begin
        Server.where(server_type: 'asterisk').each { |server| server.ami_cmd("mor reload") }
        flash[:status] = _('Monitorings_settings_saved')
        session[:ma_setting_options] = {}
        redirect_to :controller => "monitorings", :action => "settings" and return false
      rescue => e
        flash[:notice] = e.to_s
        redirect_to :controller => "monitorings", :action => "settings" and return false
      end
    else
      flash[:notice] = _('Score_should_be_a_natural_number')
      redirect_to :controller => "monitorings", :action => "settings" and return false
    end
  end

  def settings
    @page_title = _('Monitorings_settings')
    @page_icon = "magnifier.png"

    @options = session[:ma_setting_options] || Hash.new(nil)

    @lcrs = Lcr.where(user_id: 0)
    @blacklist_enabled	= (@options[:blacklist_enabled] ? @options[:blacklist_enabled].to_i.equal?(1) : Confline.get_value('blacklist_enabled', 0).to_i.equal?(1))
    @default_bl_rules	= (@options[:default_bl_rules] ? @options[:default_bl_rules].to_i.equal?(1) : Confline.get_value('default_bl_rules', 0).to_i.equal?(1))
    @default_routing_threshold = @options[:default_routing_threshold] ? @options[:default_routing_threshold] : Confline.get_value('default_routing_threshold', 0).to_i
    @default_routing_threshold_2 = @options[:default_routing_threshold_2] ? @options[:default_routing_threshold_2] : Confline.get_value('default_routing_threshold_2', 0).to_i
    @default_routing_threshold_3 = @options[:default_routing_threshold_3] ? @options[:default_routing_threshold_3] : Confline.get_value('default_routing_threshold_3', 0).to_i
    @selected_lcr_1	= @options[:default_blacklist_lcr] ? @options[:default_blacklist_lcr] : Confline.get_value('default_blacklist_lcr', 0).to_i
    @selected_lcr_2 = @options[:default_blacklist_lcr_2] ? @options[:default_blacklist_lcr_2] : Confline.get_value('default_blacklist_lcr_2', 0).to_i
    @selected_lcr_3 = @options[:default_blacklist_lcr_3] ? @options[:default_blacklist_lcr_3] : Confline.get_value('default_blacklist_lcr_3', 0).to_i

    @default_src = Src_new_score.where(value: 'default').first.score if Src_new_score.where(value: 'default').first
    @default_dst = Dst_new_score.where(value: 'default').first.score if Dst_new_score.where(value: 'default').first
    @default_ip = Ip_new_score.where(value: 'default').first.score if Ip_new_score.where(value: 'default').first

    @chanspy_disabled = (@options[:disable_chanspy] ? @options[:disable_chanspy].to_i.equal?(1) : Confline.chanspy_disabled?)
  end
end
