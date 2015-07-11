# -*- encoding : utf-8 -*-
class CallsController < ApplicationController
  include SqlExport
  include CsvImportDb

  layout "callc"
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_call, :only => [:call_info]
  before_filter :load_ok?, :only => [:aggregate, :summary]

  def index
    redirect_to :root
  end

  def active_call_soft_hangup
    server_id = params[:server_id]
    channel = params[:channel]

    if server_id.to_i > 0 and channel.to_s.length > 0
      server = Server.where(:id => server_id.to_i, :server_type => 'asterisk').first

      if server
        server.ami_cmd("channel request hangup #{channel}")
      end

    end
    MorLog.my_debug "Hangup channel: #{channel} on server: #{server_id}"
    render(:layout => 'layouts/mor_min')
  end

  # before_filter
  #   find_call
  def call_info
    @page_title = _('Call_info')
    @page_icon = 'information.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Call_Info'


    @did = nil
    @did = Did.where(["id = ?", @call.did_id.to_i]).first if @call.did_id.to_i > 0

    @user = nil
    @user = User.where(["id = ?", @call.user_id.to_i]).first if @call.user_id.to_i >= 0

    @src_device = nil
    @src_device = Device.where(["id = ?", @call.src_device_id.to_i]).first if @call.src_device_id.to_i >= 0

    @reseller = nil
    @reseller = User.where(["id = ?", @call.reseller_id.to_i]).first if @call.reseller_id.to_i > 0

    @provider = nil
    @provider = Provider.where(["providers.id = ?", @call.provider_id.to_i]).includes(:user).first if @call.provider_id.to_i > 0

    @card = nil
    @card = Card.where(["id = ?", @call.card_id.to_i]).first if @call.card_id.to_i > 0

    @call_log = @call.call_log

  end

  private

  def terminator_providers_count(terminators, terminator_id)
    count = 0
    terminators.each do |terminator|
      count = terminator.providers_size.to_i if terminator.id.to_s == terminator_id
    end
    return count
  end

  def any_terminator_providers_count(terminators)
    count = 0
    terminators.each { |terminator| count += terminator.providers_size.to_i }
    return count
  end

  def load_parties(options)
    options[:originators] = current_user.load_users
    options[:terminators] = current_user.load_terminators
    options
  end

  def find_call
    @call = Call.where(["id = ?", params[:id]]).first
    unless @call
      flash[:notice] = _("Call_not_found")
      redirect_to :root and return false
    end

    # only admin and accountant can view call info
    if current_user and !admin? and !accountant?
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to :root and return false
    end

  end

end
