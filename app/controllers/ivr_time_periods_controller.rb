# -*- encoding : utf-8 -*-
class IvrTimePeriodsController < ApplicationController

  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize

  before_filter :find_ivr_time_periods, :only => [:destroy, :edit, :update]
  before_filter :check_reseller
  before_filter :check_pbx_addon


  def index
    @page_title = _('IVR_Timeperiods')
    @page_icon = "play.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/IVR_system#Time_Periods"

    # order
    session[:ivr_timeperiods_order_by_options] ? @options = session[:ivr_timeperiods_order_by_options] : @options = {}

    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])

    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (@options[:order_by] ?  @options[:order_by]  : @options[:order_by] = 'name')
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] ? @options[:order_desc] : @options[:order_desc] = 0)

    order_by = IvrTimeperiod.ivr_timeperiods_order_by(params, @options)

    # page params
    @ivr_timeperiods_size = current_user.ivr_timeperiods.count
    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @total_pages = (@ivr_timeperiods_size.to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    @page = @options[:page]
    @fpage = ((@options[:page] -1) * session[:items_per_page]).to_i

    @ivr_timeperiod =  current_user.ivr_timeperiods.order(order_by).limit("#{@fpage}, #{session[:items_per_page].to_i}").all


    session[:ivr_timeperiods_order_by_options] = @options
  end

  def new
    @page_title = _('New_IVR_Timeperiod')
    @page_icon = "add.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/IVR_system#Time_Periods"
  end

  def create
    @page_title = _('New_IVR_Timeperiod')
    @page_icon = "add.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/IVR_system#Time_Periods"
    @period = IvrTimeperiod.new(params[:period])
    @period.update_by(params)

    if params[:period][:name] and params[:period][:name].size > 0
      if @period.save
        flash[:status] = _("Timeperiod_Created")
      else
        flash[:notice] = _("Error_While_Creating_Timeperiod")
      end
    else
      flash[:notice] = _("Cannot_Create_Timeperdiod_Without_Name")
      render(:action => :new) and return false
    end
    redirect_to :action => :index
  end

  def destroy
    if !current_user.dialplans.where(["dptype = 'ivr' and (data1= ? or data3 = ? or data5 = ?)", @period.id, @period.id, @period.id]).first
      @period.destroy
      flash[:status] = _("IVR_Timeperiod_Deleted")
    else
      flash[:notice] = _("IVR_Timeperiod_Is_In_Use")
    end
    redirect_to :action => :index
  end

  def edit

    @page_title = _('Edit_IVR_Timeperiod')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/IVR_system#Time_Periods"

    @start_date = {}
    @end_date = {}

    @start_date["month"] = @period.start_month
    @start_date["day"] = @period.start_day
    @end_date["month"]=@period.end_month
    @end_date["day"]=@period.end_day
  end

  def update
    @period.update_by(params)
    if params[:period] and !params[:period][:name].blank?
      if @period.save
        flash[:status] = _("Timeperiod_Updated")
		critical_update(@period)
        redirect_to :action => :index
      else
        flash[:notice] = _("Error_While_Creating_Timeperiod")
		render :edit
      end
    else
      flash[:notice] = _("Cannot_Create_Timeperdiod_Without_Name")
      render :edit
    end

  end

  private

  def find_ivr_time_periods
    @period = current_user.ivr_timeperiods.where(["id = ?", params[:id]]).first
    unless @period
      flash[:notice] = _('IVR_Timeperiod_Not_Found')
      redirect_to :action => :index and return false
    end
  end

=begin
  Is called when some value is changed and there is need to regenerate coresponding extlines.
  +object+ - IvrAction, IvrBlock, IvrExtension, IvrTimeperiod and of those objects are accepted as params. Finds IvrBlock and regenerates Extlines for this block.
=end

  def critical_update(object)

    plans = current_user.dialplans.where(["dptype = 'ivr' and (data1 = ? or data3 = ? or data5 = ?)", object.id, object.id, object.id])
    for plan in plans do
      plan.regenerate_ivr_dialplan
    end

  end

  def check_reseller
    if reseller? and current_user.own_providers.to_i == 0
      dont_be_so_smart
      redirect_to :root
    end
  end

  def check_pbx_addon
    if !pbx_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :root and return false
    end
  end

end
