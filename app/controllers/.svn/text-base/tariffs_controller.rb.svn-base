# -*- encoding : utf-8 -*-
class TariffsController < ApplicationController

  require 'csv'
  # include PdfGen
  include UniversalHelpers
  #require 'rubygems'
  layout "callc"

  before_filter :check_post_method, :only => [:destroy, :create, :update, :rate_destroy, :ratedetail_update, :ratedetail_destroy, :ratedetail_create, :artg_destroy, :user_rate_update, :user_rate_delete, :user_rates_update, :user_rate_destroy, :day_destroy, :day_update, :update_tariff_for_users]
  before_filter :check_localization
  before_filter :authorize, :except => [:destinations_csv]
  before_filter :check_if_can_see_finances, :only => [:new, :create, :list, :edit, :update, :destroy, :rates_list, :import_csv, :delete_all_rates, :make_user_tariff, :make_user_tariff_wholesale]
  before_filter :find_user_from_session, :only => [:generate_personal_rates_csv, :generate_personal_rates_pdf, :generate_personal_wholesale_rates_pdf, :generate_personal_wholesale_rates_csv, :user_rates, :user_rates_detailed, :common_use_prov_rates]
  before_filter :find_user_tariff, :only => [:generate_personal_rates_csv, :generate_personal_rates_pdf, :generate_personal_wholesale_rates_pdf, :generate_personal_wholesale_rates_csv, :user_rates, :user_rates_detailed]
  before_filter :find_tariff_whith_currency, :only => [:find_tariff_whith_currency, :generate_providers_rates_csv, :generate_user_rates_pdf, :generate_user_rates_csv]
  before_filter :find_tariff_from_id, :only => [:check_tariff_time, :rate_new_by_direction, :edit, :update, :destroy, :tariffs_list, :rates_list, :rate_new_quick, :rate_try_to_add, :rate_new, :rate_new_by_direction_add, :delete_all_rates, :user_rates_list, :user_arates_full, :user_rates_update, :make_user_tariff, :make_user_tariff_wholesale, :make_user_tariff_status, :make_user_tariff_status_wholesale, :ghost_percent_edit, :ghost_percent_update]
  after_filter :csv_import_cleanup, only: [:import_csv2]

  before_filter { |c|
    view = [:index, :list, :rates_list, :user_rates_list, :user_arates_full, :user_arates, :day_setup]
    edit = [:new, :create, :edit, :update, :destroy, :user_rate_update, :user_rates_update, :user_ard_time_edit, :ard_manage, :day_add, :day_edit, :day_update, :ghost_percent_edit, :ghost_percent_update]
    allow_read, allow_edit = c.check_read_write_permission(view, edit, {:role => "accountant", :right => :acc_tariff_manage, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  def index
    redirect_to :action => :list and return false
  end

  def list
    user = User.where(:id => correct_owner_id).first
    unless user
      flash[:notice]=_('User_was_not_found')
      redirect_to :root and return false
    end

    @allow_manage, @allow_read = accountant_permissions
    @page_title = _('Tariffs')
    @page_icon = 'view.png'
    #@tariff_pages, @tariffs = paginate :tariffs, :per_page => 10
    if params[:s_prefix]
      @s_prefix = params[:s_prefix].gsub(/[^0-9%]/, '')
      dest = Destination.where("prefix LIKE ?", @s_prefix.to_s).all
    end
    @des_id = []
    @des_id_d = []
    if dest and dest.size.to_i > 0
      dest.each { |d| @des_id << d.id }
      dest.each { |d| @des_id_d << d.destinationgroup_id }
      cond = " AND rates.destination_id IN (#{@des_id.join(',')})"
      con = " AND rates.destinationgroup_id IN (#{@des_id_d.join(',')}) "
      @search = 1
      incl =  [:rates]
    else
      con = ''
      cond = ''
      incl = ''
    end

    user_id = user.id

    @prov_tariffs = Tariff.where("purpose = 'provider' AND owner_id = '#{user_id}' #{cond}").includes(incl).order("name ASC").group('tariffs.id').all
    @user_tariffs = Tariff.where("purpose = 'user' AND owner_id = '#{user_id}' #{con}").includes(incl).order("name ASC").group('tariffs.id').all
    @user_wholesale_tariffs = Tariff.where("purpose = 'user_wholesale' AND owner_id = '#{user_id}' #{cond}").includes(incl).order("name ASC").group('tariffs.id').all
    @user_wholesale_enabled = (Confline.get_value("User_Wholesale_Enabled") == "1")

    @show_currency_selector =1
    @tr = []
    tariffs_rates = Tariff.select('tariffs.id, COUNT(rates.id) as rsize').where("(purpose = 'provider' or purpose = 'user_wholesale' ) AND owner_id = '#{user_id}'").joins('LEFT JOIN rates ON (rates.tariff_id = tariffs.id)').order("name ASC").group('tariffs.id').all
    tariffs_rates.each { |t| @tr[t.id] = t.rsize.to_i }
    #deleting not necessary session vars - just in case after crashed csv rate import
    session[:file] = nil
    session[:status_array] = nil
    session[:update_rate_array] = nil
    session[:short_prefix_array] = nil
    session[:bad_lines_array] = nil
    session[:bad_lines_status_array] = nil
    session[:manual_connection_fee] = nil
    session[:manual_increment] = nil
    session[:manual_min_time] = nil
  end

  def new
    @page_title = _('Tariff_new')
    @page_icon = 'add.png'
    @tariff = Tariff.new
    @currs = Currency.get_active
    @user_wholesale_enabled = (confline('User_Wholesale_Enabled') == '1')
  end

  def create
    @page_title = _('Tariff_new')
    @page_icon = 'add.png'
    @tariff = Tariff.new(params[:tariff])
    @currs = Currency.get_active
    @user_wholesale_enabled = (confline('User_Wholesale_Enabled') == '1')

    @tariff.owner_id = correct_owner_id
    if @tariff.save
      flash[:status] = _('Tariff_was_successfully_created')
      redirect_to :action => 'list'
    else
      #KRISTINA: fix error layout on create
      flash_errors_for(_('Tariff_Was_Not_Created'), @tariff)
      #flash[:notice] = _('Tariff_Was_Not_Created')
      render :new
    end
  end

  # before_filter : tariff(find_taririff_from_id)
  def edit
    check_user_for_tariff(@tariff.id)
    @page_icon = 'edit.png'
    @page_title = _('Tariff_edit') #+": "+ @tariff.name
    @no_edit_purpose = true
    @currs = Currency.get_active
    @user_wholesale_enabled = (confline('User_Wholesale_Enabled') == '1')
  end

  # before_filter : tariff(find_taririff_from_id)
  def update
    a=check_user_for_tariff(@tariff.id)
    return false if !a
    @page_icon = 'edit.png'
    @currs = Currency.get_active

    if @tariff.update_attributes(params[:tariff])
      flash[:status] = _('Tariff_was_successfully_updated')
      @tariff.updated
      redirect_to :action => 'list', :id => @tariff
    else
      flash_errors_for(_('Tariff_Was_Not_Updated'), @tariff)
      render :edit
    end
  end

  # before_filter : tariff(find_taririff_from_id)
  def destroy
    a=check_user_for_tariff(@tariff.id)
    return false if !a

    destroy, notice = @tariff.able_to_delete?
    if destroy
      @tariff.delete_all_rates
      @tariff.destroy
      #my_debug tariff.providers.count
      flash[:status] = _('Tariff_deleted')
    else
      flash[:notice] = notice
    end
    redirect_to action: 'list'
  end

  # ================== TARIFFS LIST =====================

  # before_filter : tariff(find_taririff_from_id)
  def tariffs_list
    check_user_for_tariff(@tariff.id)
    @page_title = _('Tariff_list')
    @page_icon = 'view.png'
    @user = User.where(:tariff_id => @tariff.id).all
    @cardgroup = Cardgroup.where(:tariff_id => @tariff.id).all
  end


  # =============== RATES FOR PROVIDER ==================

  # before_filter : tariff(find_taririff_from_id)
  def rates_list
    tariff_id = @tariff.id.to_i
    return false unless check_user_for_tariff(tariff_id)
    current_user_id = current_user.id.to_i

    @allow_manage, @allow_read = accountant_permissions
    @page_title = _('Rates_for_tariff') #+": " + @tariff.name
    @can_edit = true
    @effective_from_active = ((admin? || reseller?) && ['provider', 'user_wholesale'].include?(@tariff.purpose.to_s))

    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user_id and CommonUseProvider.where(:reseller_id => current_user_id, :tariff_id => tariff_id).first
      @can_edit = false
    end

    @directions_first_letters = Rate.select('directions.name').where("rates.tariff_id = #{tariff_id}").joins("JOIN destinations ON destinations.id = rates.destination_id JOIN directions ON (directions.code = destinations.direction_code)").order("directions.name ASC").group("SUBSTRING(directions.name,1,1)").all

    @directions_first_letters.map! { |rate| rate.name[0..0] }
    @st = (params[:st] ? params[:st].upcase : @directions_first_letters[0])
    @st ||= 'A'
    @st = nil if params[:s_prefix].present?

    @directions = Direction.
        select("directions.*, COUNT(destinations.id) AS 'dest_count', COUNT(rates.id) AS 'rate_count'").
        where(["directions.name LIKE ?", @st.to_s + "%"]).
        joins("LEFT JOIN destinations ON (destinations.direction_code = directions.code) LEFT JOIN rates ON (rates.destination_id = destinations.id AND tariff_id = #{tariff_id})").
        order("name ASC").
        group("directions.id").
        all
    @page = params[:page] ? params[:page].to_i : 1
    record_offset = (@page - 1) * session[:items_per_page].to_i

    if params[:s_prefix]
      @s_prefix = params[:s_prefix].gsub(/[^0-9%]/, '')
      @des_id = Destination.select(:id).where(["prefix LIKE ?", @s_prefix.to_s]).all.map {|destination| destination.id}
    end

    join = "LEFT JOIN (SELECT tariff_id, destination_id, IFNULL(MAX(effective_from), 0) AS max_effective_from from rates WHERE (effective_from < now() OR effective_from IS NULL) AND rates.tariff_id = #{tariff_id} GROUP BY tariff_id,destination_id) rates2 ON rates2.tariff_id = rates.tariff_id AND rates.destination_id = rates2.destination_id" if @effective_from_active
    rate_details_join = "LEFT JOIN ratedetails ON ratedetails.rate_id = rates.id"
    select = "rates.*"
    if @effective_from_active
      select << ", IF(IFNULL(rates.effective_from, 0) = rates2.max_effective_from, 1, 0) AS active"
      effective_from_order = ", rates.effective_from DESC"
    end

    if @s_prefix
      unless @des_id.empty?
        @search = 1
        condition = ["rates.tariff_id = ? AND rates.destination_id IN (#{@des_id.join(',')})", tariff_id]
        rate_count = Rate.joins(rate_details_join).where(condition).count
        @rates = Rate.select(select).joins(join).joins(rate_details_join).where(condition).group("rates.id").offset(record_offset).limit(session[:items_per_page].to_i).all
      else
        @rates = []
      end
    else
      condition = ["rates.tariff_id=? AND directions.name like ?", tariff_id, @st+"%"]
      includes = [{:destination => :direction}, :tariff]
      rate_count = Rate.joins(rate_details_join).joins(includes).where(condition).count
      @rates = Rate.select(select).joins(join).joins(rate_details_join).joins(includes).where(condition).group("rates.id").order("directions.name ASC, destinations.prefix ASC#{effective_from_order}").offset(record_offset).limit(session[:items_per_page].to_i).all
    end

    @total_pages = (rate_count.to_f / session[:items_per_page].to_f).ceil
    @letter_select_header_id = tariff_id
    @page_select_header_id = tariff_id
  end

 #Checks if prefix is available and has no set rates.
 #post data - prefix that needs to be checked.
  def check_prefix_availability
    @prefix = (params.keys.select { |parameter| parameter =~ /[0-9]+/ })[0]
    #wft was that? request.raw_post request.query_string??
    #@prefix = request.raw_post || request.query_string
    #@prefix = @prefix.gsub(/=/, "")
    @tariff = params[:tariff_id]
    @destination = Destination.select("directions.name as 'dir_name', directions.code as 'dir_code', destinations.prefix AS 'des_prefix', destinations.name as 'des_name', destinations.subcode AS 'des_subcode', rates.id AS 'rate_id'").
                               joins("LEFT JOIN directions ON (destinations.direction_code = directions.code) LEFT JOIN (SELECT * FROM rates WHERE tariff_id = #{@tariff.to_i}) AS rates ON (rates.destination_id = destinations.id)").
                               where(["prefix = ?", @prefix]).
                               first
    render :layout => false
  end

=begin rdoc
 Quickly adds new rate of desired price for tariff.

 *Params*:

 +id+ - Tariff id.
 +prefix+ - String with prefix
 +price+ - String with rate price
 +st+ - Direction's first letter for correct pagination
 +page+ - number of the page user should be returned to

 *Flash*:

 +Rate_already_set+ - if rate is already set
 +Prefix_was_not_found+ - desired rate was not found so it cannot be set
 +Rate_was_added+ - if rate was created successfully
 +Rate_was_not_added+ - if rate was not created successfully

 *Redirect*

 +rates_list+
=end

  # before_filter : tariff(find_taririff_from_id)
  def rate_new_quick
    params[:page].to_i > 0 ? @page = params[:page].to_i : @page = 1
    @prefix = params[:prefix]
    @price = params[:price]
    if Rate.joins("LEFT JOIN destinations ON (destinations.id = rates.destination_id)").
            where(["rates.tariff_id =? AND destinations.prefix = ?", @tariff.id, @prefix]).first
      flash[:notice] = _("Rate_already_set")
      redirect_to(:action => :rates_list, :id => @tariff.id, :st => params[:st], :page => @page) and return false
    end
    @destination = Destination.where(["prefix = ?", @prefix]).first
    if @destination
      if @tariff.add_new_rate(@destination.id, @price, params[:increment_s], params[:min_time], params[:connection_fee], params[:ghost_percent])
        flash[:status] = _("Rate_was_added")
      else
        flash[:notice] = _("Rate_was_not_added")
      end
    else
      flash[:notice] = _('Prefix_was_not_found')
    end
    redirect_to(:action => :rates_list, :id => @tariff.id, :st => params[:st], :page => @page) and return false
  end

=begin rdoc
 Shows list of free destinations for 1 direction. User can set rates for destinations.

 *Params*:

 +id+ - Tariff id
 +dir_id+ Direction id
 +st+ - Direction's first letter for correct pagination
 +page+ - list page number
=end
  # before_filter : tariff(find_taririff_from_id)
  def rate_new_by_direction
    params[:page].to_i > 0 ? @page = params[:page].to_i : @page = 1
    @st = params[:st]
    @direction = Direction.where(['id = ?', params[:dir_id]]).first
    unless @direction
      flash[:notice]=_('Direction_was_not_found')
      redirect_to :action => :list and return false
    end
    @destinations = @tariff.free_destinations_by_direction(@direction)
    #    MorLog.my_debug(@destinations)
    @total_items = @destinations.size
    @total_pages = (@total_items.to_d / session[:items_per_page].to_d).ceil
    istart = (@page-1)*session[:items_per_page]
    iend = (@page)*session[:items_per_page]-1
    #    MorLog.my_debug(istart)
    #    MorLog.my_debug(iend)
    @destinations = @destinations[istart..iend]
    @page_select_options = {
        :id => @tariff.id,
        :dir_id => @direction.id,
        :st => @st
    }
    @page_title = _('Rates_for_tariff') +" "+ _("Direction")+ ": " + @direction.name
    @page_icon = "money.png"
    #    MorLog.my_debug(@destinations)
  end

=begin rdoc

=end
  # before_filter : tariff(find_taririff_from_id)
  def rate_new_by_direction_add
    @st = params[:st]
    @direction = Direction.where(['id = ?', params[:dir_id]]).first
    unless @direction
      flash[:notice]=_('Direction_was_not_found')
      redirect_to :action => :list and return false
    end
    @destinations = @tariff.free_destinations_by_direction(@direction)
    @destinations.each { |dest|
      destination_id = dest.id
      if params["dest_#{destination_id}"] and params["dest_#{destination_id}"].to_s.length > 0
        @tariff.add_new_rate(destination_id, params["dest_#{destination_id}"], 1, 0,0, params[('gh_'+destination_id.to_s).intern])
      end
    }
    flash[:status] = _('Rates_updated')
    redirect_to :action => 'rate_new_by_direction', :id => params[:id], :st => params[:st], :dir_id => @direction.id
  end

  # before_filter : tariff(find_taririff_from_id)
  def rate_new
    tariff_id = @tariff.id
    check_user_for_tariff(tariff_id)

    if @tariff.purpose == 'user'
      flash[:notice] = _('Tariff_type_error')
      redirect_to :action => :list and return false
    end

    @page_title = _('Add_new_rate_to_tariff') # +": " + @tariff.name
    @page_icon = "add.png"

    # st - from which letter starts rate's direction (usualy country)
    @st = "A"
    @st = params[:st].upcase if params[:st]
    @page = (params[:page] || 1).to_i
    offset = (@page -1) * session[:items_per_page].to_i

    @dests, total_records = @tariff.free_destinations_by_st(@st, session[:items_per_page], offset)
    @total_pages = (total_records.to_f / session[:items_per_page].to_f).ceil

    @letter_select_header_id = tariff_id
    @page_select_header_id = tariff_id
  end

  # before_filter : tariff(find_taririff_from_id)
  def ghost_percent_edit
    a=check_user_for_tariff(@tariff.id)
    return false if !a
    @page_title = _('Ghost_percent')
    @rate = Rate.where({:id => params[:rate_id]}).first
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    @destination = @rate.destination
  end

  # before_filter : tariff(find_taririff_from_id)
  def ghost_percent_update
    a=check_user_for_tariff(@tariff.id)
    return false if !a
    @rate = Rate.where({:id => params[:rate_id]}).first
    if @rate
      @rate.update_ghost_percent(params[:rate][:ghost_min_perc])
    end

    flash[:status] = _('Rate_updated')
    @rate.tariff_updated
    redirect_to :action => :ghost_percent_edit, :id => @tariff.id, :rate_id => params[:rate_id]
  end

  # before_filter : tariff(find_taririff_from_id)
  def rate_try_to_add
    a=check_user_for_tariff(@tariff.id)
    return false if !a

    if @tariff.purpose == 'user'
      flash[:notice] = _('Tariff_type_error')
      redirect_to :controller => :tariffs, :action => :list and return false
    end

    # st - from which letter starts rate's direction (usualy country)
    st = params[:st].try(:upcase) || 'A'

    @tariff.free_destinations_by_st(st).each do |dest|
      #add only rates which are entered
      destination_id = dest.id.to_s
      destination = params[(destination_id).intern]
      if destination.to_s.length > 0
        @tariff.add_new_rate(destination_id, destination, 1, 0,0, params[('gh_'+destination_id).intern])
      end
    end

    flash[:status] = _('Rates_updated')
    redirect_to :action => 'rates_list', :id => params[:id], :st => st
    #    render :action => 'debug'
  end


  def rate_destroy
    rate = Rate.where(["id = ?", params[:id]]).first
    unless rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    if rate
      a=check_user_for_tariff(rate.tariff_id)
      return false if !a

      st = rate.destination.direction.name[0, 1]
      rate.destroy_everything
    end

    flash[:status] = _('Rate_deleted')
    redirect_to :action => 'rates_list', :id => params[:tariff], :st => st
  end

  # =============== RATE DETAILS ==============

  def rate_details
    @rate = Rate.where(:id => params[:id]).first
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end

    rated = Ratedetail.where(:rate_id => params[:id]).first

    if !rated
      rd = Ratedetail.new(
        start_time: '00:00:00',
        end_time: '23:59:59',
        rate: 0,
        connection_fee: 0,
        rate_id: params[:id].to_i,
        increment_s: 0,
        min_time: 0,
        daytype: 'WD'
      )
      rd.save
    end

    check_user_for_tariff(@rate.tariff_id)
    @allow_manage, @allow_read = accountant_permissions
    @page_title = _('Rate_details')
    @rate_details = @rate.ratedetails

    if @rate_details[0] and @rate_details[0].daytype == ""
      @wdfd = true
    else
      @wdfd = false

      @WDrdetails = []
      @FDrdetails = []
      @rate_details.each do |rate_detail|
        @WDrdetails << rate_detail if rate_detail.daytype == "WD"
        @FDrdetails << rate_detail if rate_detail.daytype == "FD"
      end

    end

    @tariff = @rate.tariff
    @destination = @rate.destination
    #every rate should have destination assigned, but since it is common to have
    #broken relational itegrity, we should check whether destination is not nil
    unless @destination
      flash[:notice] = _('Rate_does_not_have_destination_assigned')
      redirect_to :root
    end
    @can_edit = true

    current_user_id = current_user.id.to_i
    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user_id and CommonUseProvider.where(["reseller_id = ? AND tariff_id = ?", current_user_id, @tariff.id]).first
      @can_edit = false
    end
  end

  def ratedetails_manage
    @rate = Rate.where(:id => params[:id]).first
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end

    a=check_user_for_tariff(@rate.tariff_id)
    return false if !a

    rdetails = @rate.ratedetails

    rdaction = params[:rdaction]

    if rdaction == "COMB_WD"
      rdetails.each { |rate_detail| rate_detail.combine_work_days }
      status = _('Rate_details_combined')
    end

    if rdaction == "COMB_FD"
      rdetails.each { |rate_detail| rate_detail.combine_free_days }
      status = _('Rate_details_combined')
    end

    if rdaction == "SPLIT"
      rdetails.each { |rate_detail| rate_detail.split }
      status = _('Rate_details_split')
    end

    if status.present?
      flash[:status] = status
      @rate.tariff_updated
    end

    redirect_to :action => 'rate_details', :id => @rate.id
  end


  def ratedetail_edit
    @ratedetail = Ratedetail.where(:id => params[:id]).first
    unless @ratedetail
      flash[:notice]=_('Ratedetail_was_not_found')
      redirect_to :action => :list and return false
    end
    @page_title = _('Rate_details_edit')
    @page_icon = "edit.png"

    rate = Rate.where(:id => @ratedetail.rate_id).first
    unless rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    check_user_for_tariff(rate.tariff_id)

    rdetails = rate.ratedetails_by_daytype(@ratedetail.daytype)

    @tariff = rate.tariff
    @destination = rate.destination
    @etedit = (rdetails[(rdetails.size - 1)] == @ratedetail)

    #my_debug @etedit

  end


  def ratedetail_update
    @ratedetail = Ratedetail.where(:id => params[:id]).first
    unless @ratedetail
      flash[:notice]=_('Ratedetail_was_not_found')
      redirect_to :action => :list and return false
    end
    rd = @ratedetail

    rate = Rate.where(:id => @ratedetail.rate_id).first
    unless rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end

    a = check_user_for_tariff(rate.tariff_id)
    return false if !a

    rdetails = rate.ratedetails_by_daytype(@ratedetail.daytype)

    if (params[:ratedetail] and params[:ratedetail][:end_time]) and ((nice_time2(rd.start_time) > params[:ratedetail][:end_time]) or (params[:ratedetail][:end_time] > "23:59:59"))
      flash[:notice] = _('Bad_time')
      redirect_to :action => 'rate_details', :id => @ratedetail.rate_id and return false
    end


    if @ratedetail.update_attributes(params[:ratedetail])

      # we need to create new rd to cover all day
      if (nice_time2(@ratedetail.end_time) != '23:59:59') and ((rdetails[(rdetails.size - 1)] == @ratedetail))
        st = @ratedetail.end_time.blank? ? '00:00:00' : @ratedetail.end_time + 1.second

        attributes = rd.attributes.merge(start_time: st.to_s, end_time: '23:59:59')
        nrd = Ratedetail.new(attributes)
        nrd.save
      end

      rate.tariff_updated

      flash[:status] = _('Rate_details_was_successfully_updated')
      redirect_to :action => 'rate_details', :id => @ratedetail.rate_id
    else
      render :ratedetail_edit
    end
  end

  def ratedetail_new
    @rate = Rate.where(:id => params[:id]).first
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    @page_title = _('Ratedetail_new')
    @page_icon = 'add.png'
    @ratedetail = Ratedetail.new(
      start_time: '00:00:00',
      end_time: '23:59:59'
    )
  end

  def ratedetail_create
    @rate = Rate.where(:id => params[:id]).first
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    @ratedetail = Ratedetail.new(params[:ratedetail])
    @ratedetail.rate = @rate
    if @ratedetail.save
      flash[:status] = _('Rate_detail_was_successfully_created')
      redirect_to :action => 'rate_details', :id => @ratedetail.rate_id
    else
      render :ratedetail_new
    end
  end

  def ratedetail_destroy
    @rate = Rate.where(:id => params[:rate]).first
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    a = check_user_for_tariff(@rate.tariff_id)
    return false if !a

    rd = Ratedetail.where(:id => params[:id]).first
    unless rd
      flash[:notice]=_('Ratedetail_was_not_found')
      redirect_to :action => :list and return false
    end
    rdetails = @rate.ratedetails_by_daytype(rd.daytype)


    if rdetails.size > 1

      #update previous rd
      et = nice_time2(rd.start_time - 1.second)
      daytype = rd.daytype
      prd = Ratedetail.where(["rate_id = ? AND end_time = ? AND daytype = ?", @rate.id, et, daytype]).first
      if prd
        prd.end_time = "23:59:59"
        prd.save
      end
      rd.destroy
      flash[:status] = _('Rate_detail_was_successfully_deleted')
    else
      flash[:notice] = _('Cant_delete_last_rate_detail')
    end

    redirect_to :action => 'rate_details', :id => params[:rate]
  end


  # ======== XLS IMPORT =================
  def import_xls
    @step = 1
    @step = params[:step].to_i if params[:step]

    step_names = [_('File_upload'),
                  _('Column_assignment'),
                  _('Column_confirmation'),
                  _('Analysis'),
                  _('Creating_destinations'),
                  _('Updating_rates'),
                  _('Creating_new_rates')]
    @step_name = step_names[@step - 1]

    @page_title = (_('Import_XLS') + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + _('Step') + ": " + @step.to_s + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + @step_name).html_safe
    @page_icon = 'excel.png';

    @tariff = Tariff.where(:id => params[:id]).first
    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to :action => :list and return false
    end
    a = check_user_for_tariff(@tariff.id)
    return false if !a

    if @step == 2
      if params[:file] or session[:file]
        if params[:file]
          @file = params[:file]
          session[:file] = params[:file].read if @file.size > 0
        else
          @file = session[:file]
        end
        session[:file_size] = @file.size
        if session[:file_size].to_i == 0
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "import_xls", :id => @tariff.id, :step => "1" and return false
        end

        file_name = '/tmp/temp_excel.xls'
        f = File.open(file_name, "wb")
        f.write(session[:file])
        f.close
        workbook = Excel.new(file_name)
        i=0
        session[:pagecount] = 0
        pages = []
        page = []
        #        MorLog.my_debug(workbook.info)
        last_sheet, count = count_data_sheets(workbook)
        if count == 1
          #          MorLog.my_debug("single")
          #          MorLog.my_debug(last_sheet.class)
          #          MorLog.my_debug(find_prefix_column(workbook, last_sheet))

        end

        #        MorLog.my_debug("++")

        flash[:status] = _('File_uploaded')
      end
    end
  end

  def find_prefix_column(workbook, sheet)
    workbook.default_sheet = sheet
    size = workbook.last_row
    midle = size/2
    midle.upto(size) do |index|
      workbook.row(index)
    end
  end

  def count_data_sheets(workbook)
    count = 0
    for sheet in workbook.sheets do
      workbook.default_sheet = sheet
      if workbook.last_row.to_i > 0 and workbook.last_column.to_i > 1
        count += 1
        last = sheet
      end
    end
    return sheet, count
  end

  # ======== CSV IMPORT =================
  def import_csv
    redirect_to :action => :import_csv2, :id => params[:id] and return false
  end

  def import_csv2
    @sep, @dec = Application.nice_action_session_csv(params, session, correct_owner_id)
    store_location

    params[:step] ? @step = params[:step].to_i : @step = 0
    @step = 0 unless (0..8).include?(@step.to_i)

    if (@step == 5) and reseller?
      @step = 6
    end

    @step_name = _('File_upload')
    @step_name = _('Column_assignment') if @step == 2
    @step_name = _('Column_confirmation') if @step == 3
    @step_name = _('Analysis') if @step == 4
    @step_name = _('Creating_destinations') if @step == 5
    @step_name = _('Updating_rates') if @step == 6
    @step_name = _('Creating_new_rates') if @step == 7
    @step_name = _('deleting_rates') if @step == 8


    if reseller?
      step = @step == 6 ? 5 : @step
      step = 6 if @step > 6
    else
      step = @step
    end
    @page_title = (_('Import_CSV') + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + _('Step') + ": " + step.to_s + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + @step_name).html_safe
    @page_icon = 'excel.png';
    @help_link = "http://wiki.kolmisoft.com/index.php/Rate_import_from_CSV";

    @tariff = Tariff.where(["id = ?", params[:id]]).first
    tariff_id = @tariff.id
    unless @tariff
      flash[:notice] = _("Tariff_Was_Not_Found")
      redirect_to :action => :list and return false
    end

    a = check_user_for_tariff(tariff_id)
    return false if !a

    @effective_from_active = ((admin? || reseller?) && ['provider', 'user_wholesale'].include?(@tariff.purpose.to_s))

    if @step == 0
      my_debug_time "**********import_csv2************************"
      my_debug_time "step 0"
      session["tariff_name_csv_#{tariff_id}".to_sym] = nil
      session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
      session[:import_csv_tariffs_import_csv_options] = nil
    end

    if @step == 1
      my_debug_time "step 1"
      session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
      session["tariff_name_csv_#{tariff_id}".to_sym] = nil
      if params[:file]
        @file = params[:file]
        if  @file.size > 0
          if !@file.respond_to?(:original_filename) or !@file.respond_to?(:read) or !@file.respond_to?(:rewind)
            flash[:notice] = _('Please_select_file')
            redirect_to :action => "import_csv2", :id => tariff_id, :step => "0" and return false
          end
          if get_file_ext(@file.original_filename, "csv") == false
            @file.original_filename
            flash[:notice] = _('Please_select_CSV_file')
            redirect_to :action => "import_csv2", :id => tariff_id, :step => "0" and return false
          end
          @file.rewind
          file = @file.read.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
          session[:file_size] = file.size
          session["temp_tariff_name_csv_#{tariff_id}".to_sym] = @tariff.save_file(file)
          flash[:status] = _('File_downloaded')
          redirect_to :action => "import_csv2", :id => tariff_id, :step => "2" and return false
        else
          session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "import_csv2", :id => tariff_id, :step => "0" and return false
        end
      else
        session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "import_csv2", :id => tariff_id, :step => "0" and return false
      end
    end


    if @step == 2
      my_debug_time "step 2"
      my_debug_time "use : #{session["temp_tariff_name_csv_#{tariff_id}".to_sym]}"
      if session["temp_tariff_name_csv_#{tariff_id}".to_sym]
        file = @tariff.head_of_file("/tmp/#{session["temp_tariff_name_csv_#{tariff_id}".to_sym]}.csv", 20).join("").to_s
        session[:file] = file
        a = check_csv_file_seperators(file, 2, 2)
        if a
          @fl = @tariff.head_of_file("/tmp/#{session["temp_tariff_name_csv_#{tariff_id}".to_sym]}.csv", 1).join("").to_s.split(@sep)
          begin
            session["tariff_name_csv_#{tariff_id}".to_sym] = @tariff.load_csv_into_db(session["temp_tariff_name_csv_#{tariff_id}".to_sym], @sep, @dec, @fl)

            # drop columns from temp table that are not allowed to be imported
            ["State", "LATA", "Class", "OCN"].each do |column_to_drop|
              unless @fl.index("#{column_to_drop}").nil?
                ActiveRecord::Base.connection.execute("ALTER TABLE #{session["tariff_name_csv_#{tariff_id}".to_sym]} " +
                                                      "DROP col_#{@fl.index("#{column_to_drop}")};")
              end
            end

            session[:file_lines] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{session["tariff_name_csv_#{tariff_id}".to_sym]}")
          rescue => e
            MorLog.log_exception(e, Time.now.to_i, params[:controller], params[:action])
            session[:import_csv_tariffs_import_csv_options] = {}
            session[:import_csv_tariffs_import_csv_options][:sep] = @sep
            session[:import_csv_tariffs_import_csv_options][:dec] = @dec
            begin
              session[:file] = File.open("/tmp/#{session["temp_tariff_name_csv_#{tariff_id}".to_sym]}.csv", "rb").read
            rescue => e
              MorLog.log_exception(e, Time.now.to_i, params[:controller], params[:action])
              flash[:notice] = _('Please_upload_file')
              redirect_to :action => "import_csv2", :id => tariff_id, :step => "1" and return false
            end
            Tariff.clean_after_import(session["temp_tariff_name_csv_#{tariff_id}".to_sym])
            session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
            flash[:notice] = _('MySQL_permission_problem_contact_Kolmisoft_to_solve_it')
            redirect_to :action => "import_csv2", :id => tariff_id, :step => "2" and return false
          end
          flash[:status] = _('File_uploaded') if !flash[:notice]
        end
      else
        session["tariff_name_csv_#{tariff_id}".to_sym] = nil
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "import_csv2", :id => tariff_id, :step => "1" and return false
      end
      @rate_type, flash[:notice_2] = @tariff.check_types_periods(params)
    end

    if  @step > 2
      unless ActiveRecord::Base.connection.tables.include?(session["temp_tariff_name_csv_#{tariff_id}".to_sym]) and session[:file]
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "import_csv2", :id => tariff_id, :step => "0" and return false
      end

      if session["tariff_name_csv_#{tariff_id}".to_sym] and session[:file]

        if @step == 3
          my_debug_time "step 3"

          if params[:prefix_id] and params[:rate_id] and params[:prefix_id].to_i >= 0 and params[:rate_id].to_i >= 0
            @optins = {}
            @optins[:imp_prefix] = params[:prefix_id].to_i
            @optins[:imp_rate] = params[:rate_id].to_i

            if @effective_from_active and params[:effective_from].to_i >= 0
              @optins[:imp_effective_from] = params[:effective_from].to_i
              @optins[:current_user_tz] = Time.zone.now.formatted_offset
              date_format = params[:effective_from_date_format] + ' %H:%i:%s'
              @optins[:date_format] = date_format.blank? ? "%Y-%m-%d %H:%i:%s" : date_format
            end

            @optins[:imp_subcode] = params[:subcode].to_i
            @optins[:imp_increment_s] = params[:increment_id].to_i
            @optins[:imp_min_time] = params[:min_time_id].to_i
            @optins[:imp_ghost_percent] = params[:ghost_percent_id].to_i
            @optins[:imp_cc] = params[:country_code_id].to_i

            @optins[:imp_city] = params[:city_id].to_i

            @optins[:imp_country] = params[:country_id].to_i
            @optins[:imp_connection_fee] = params[:connection_fee_id].to_i
            @optins[:imp_date_day_type] = params[:rate_day_type].to_s

            @rate_type, flash[:notice_2] = @tariff.check_types_periods(params)
            ##5808 not cheking any more
            #unless flash[:notice_2].blank?
            #  flash[:notice] = _('Tariff_import_incorrect_time').html_safe
            #  flash[:notice] += '<br /> * '.html_safe + _('Please_select_period_without_collisions').html_safe
            #  redirect_to :action => "import_csv", :id => @tariff.id, :step => "2" and return false
            #end

            @optins[:imp_time_from_type] = params[:time_from][:hour].to_s + ":" + params[:time_from][:minute].to_s + ":" + params[:time_from][:second].to_s if params[:time_from]
            @optins[:imp_time_till_type] = params[:time_till][:hour].to_s + ":" + params[:time_till][:minute].to_s + ":" + params[:time_till][:second].to_s if params[:time_till]
            @optins[:imp_update_dest_names] = params[:update_dest_names].to_i if admin?
            @optins[:imp_update_subcodes] = params[:update_subcodes].to_i if admin?
            @optins[:imp_update_destination_groups] = params[:update_destination_groups].to_i if admin?
            @optins[:imp_delete_unimported_prefix_rates] = params[:delete_unimported_prefix_rates].to_i if admin?

            if admin? and params[:update_dest_names].to_i == 1
              if params[:destination_id] and params[:destination_id].to_i >=0
                @optins[:imp_dst] = params[:destination_id].to_i

                # Saving old Destination names before import
            		check_destination_names = "select count(original_destination_name) as notnull from " + session["tariff_name_csv_#{tariff_id}".to_sym].to_s + " where original_destination_name is not NULL"

                if (ActiveRecord::Base.connection.select(check_destination_names).first["notnull"].to_i rescue 0) == 0
            	          sql = "UPDATE " + session["tariff_name_csv_#{tariff_id}".to_sym].to_s + " JOIN destinations ON (replace(col_1, '\\r', '') = destinations.prefix) SET original_destination_name = destinations.name WHERE ned_update IN (1, 2, 3, 4)"
            		  ActiveRecord::Base.connection.execute(sql)
            		end
              else
                flash[:notice] = _('Please_Select_Columns_destination')
                redirect_to :action => "import_csv2", :id => tariff_id, :step => "2" and return false
              end
            else
              @optins[:imp_dst] = params[:destination_id].to_i
            end
            @optins[:imp_update_directions] = params[:update_directions].to_i if admin?
            #priority over csv

            @optins[:manual_connection_fee] = ""
            @optins[:manual_increment] = ""
            @optins[:manual_min_time] = ""

            @optins[:manual_connection_fee] = params[:manual_connection_fee] if params[:manual_connection_fee]
            @optins[:manual_increment] = params[:manual_increment] if params[:manual_increment]
            @optins[:manual_min_time] = params[:manual_min_time] if params[:manual_min_time]
            @optins[:manual_ghost_percent] = params[:manual_ghost_percent] if params[:manual_ghost_percent]

            @optins[:sep] = @sep
            @optins[:dec] = @dec
            @optins[:file]= session[:file]
            @optins[:file_size] = session[:file_size]
            @optins[:file_lines] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{session["tariff_name_csv_#{tariff_id}".to_sym]}")
            session["tariff_import_csv2_#{tariff_id}".to_sym] = @optins
            flash[:status] = _('Columns_assigned')
          else
            flash[:notice] = _('Please_Select_Columns')
            redirect_to :action => "import_csv2", :id => tariff_id, :step => "2" and return false
          end
        end

        if session["tariff_import_csv2_#{tariff_id}".to_sym] and session["tariff_import_csv2_#{tariff_id}".to_sym][:imp_prefix] and session["tariff_import_csv2_#{tariff_id}".to_sym][:imp_rate]
          #check how many destinations and should we create new ones?
          if @step == 4
            my_debug_time "step 4"
            @tariff_analize = @tariff.analize_file(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym])
            session[:bad_destinations] = @tariff_analize[:bad_prefixes]
            session[:bad_lines_array] = @tariff_analize[:bad_prefixes]
            session[:bad_lines_status_array] = @tariff_analize[:bad_prefixes_status]

            flash[:status] = _('Analysis_completed')
            session["tariff_analize_csv2_#{tariff_id}".to_sym] = @tariff_analize
          end

          # Create new destinations.
          if @step == 5
            if Confline.get_value('Destination_create', current_user.id).to_i == 1
              #redirect back
              flash[:notice] = _('Please_wait_while_first_import_is_finished')
              redirect_to :action => "import_csv2", :id => tariff_id, :step => "0" and return false
            else
              @tariff_analize = session["tariff_analize_csv2_#{tariff_id}".to_sym]
              my_debug_time "step 5"
              if ["admin", "accountant"].include?(session[:usertype])
                begin
                  session["tariff_analize_csv2_#{tariff_id}".to_sym][:created_destination_from_file] = @tariff.create_deatinations(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
                  flash[:status] = _('Created_destinations') + ": #{session["tariff_analize_csv2_#{tariff_id}".to_sym][:created_destination_from_file]}"
                  if session["tariff_import_csv2_#{tariff_id}".to_sym][:imp_update_dest_names].to_i == 1
                    session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_destination_from_file] = @tariff.update_destinations(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
                    flash[:status] += "<br />"+ _('Destination_names_updated') + ": #{session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_destination_from_file]}"
                  end
                  if session["tariff_import_csv2_#{tariff_id}".to_sym][:imp_update_subcodes].to_i == 1
                    session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_subcodes_from_file] = @tariff.update_subcodes(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
                    flash[:status] += "<br />"+ _('Subcodes_updated') + ": #{session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_subcodes_from_file]}"
                  end
                  if session["tariff_import_csv2_#{tariff_id}".to_sym][:imp_update_directions].to_i == 1
                    session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_directions_from_file] = @tariff.update_directions(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
                    flash[:status] += "<br />"+ _('Directions_based_on_country_code_updated') + ": #{session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_directions_from_file]}"
                  end
                  if session["tariff_import_csv2_#{tariff_id}".to_sym][:imp_update_destination_groups].to_i == 1
                    session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_destination_groups] = @tariff.update_destination_groups(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
                    flash[:status] += "<br />"+ _('Destination_groups_updated') + ": #{session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_destination_groups]}"
                  end
                #rescue Exception => e
                #  my_debug_time e.to_yaml
                #  flash[:notice] = _('collision_Please_start_over')
                #  my_debug_time "clean start"
                #  Tariff.clean_after_import(session["tariff_name_csv_#{@tariff.id}".to_sym])
                #  session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = nil
                #  my_debug_time "clean done"
                #  redirect_to :action => "import_csv2", :id => @tariff.id, :step => "0" and return false
                end
              else
                flash[:notice] = _('No_Destinations_Were_Created')
              end
            end
          end

          #update rates (ratedetails actually)
          if @step == 6
            begin
              @tariff_analize = session["tariff_analize_csv2_#{tariff_id}".to_sym]
              my_debug_time "step 6"
              session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_rates_from_file] = @tariff.update_rates_from_csv(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
              @tariff.update_rates_from_csv(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
              if @tariff_analize[:new_rates_to_create].to_i.zero?
                @tariff.insert_ratedetails(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
              end
              flash[:status] = _('Rates_updated') + ": " + @tariff_analize[:rates_to_update].to_s
            #rescue Exception => e
            #  my_debug_time e.to_yaml
            #  flash[:notice] = _('collision_Please_start_over')
            #  my_debug_time "clean start"
            #  Tariff.clean_after_import(session["tariff_name_csv_#{@tariff.id}".to_sym])
            #  session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = nil
            #  my_debug_time "clean done"
            #  redirect_to :action => "import_csv2", :id => @tariff.id, :step => "0" and return false
            end
          end

          #create rates/ratedetails
          if @step == 7
            begin
              @tariff_analize = session["tariff_analize_csv2_#{tariff_id}".to_sym]
              my_debug_time "step 7"
              session["tariff_analize_csv2_#{tariff_id}".to_sym][:created_rates_from_file] = @tariff.create_rates_from_csv(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
              if @tariff_analize[:new_rates_to_create].to_i > 0
                @tariff.insert_ratedetails(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
              end

              @tariff.updated
              flash[:status] = _('New_rates_created') + ": " + @tariff_analize[:new_rates_to_create].to_s
              Action.add_action(session[:user_id], "tariff_import_2", _('Tariff_was_imported_from_CSV'))
            #rescue Exception => e
            #  my_debug_time e.to_yaml
            #  flash[:notice] = _('collision_Please_start_over')
            #  my_debug_time "clean start"
            #  #Tariff.clean_after_import(session["tariff_name_csv_#{@tariff.id}".to_sym])
            #  session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = nil
            #  my_debug_time "clean done"
            #  redirect_to :action => "import_csv2", :id => @tariff.id, :step => "0" and return false
            end
          end

          if @step == 8
              @tariff_analize = session["tariff_analize_csv2_#{tariff_id}".to_sym]
              my_debug_time "step 8"
              if @tariff_analize[:rates_to_delete].to_i > 0
                @tariff_analize[:deleted_rates] = @tariff.delete_unimported_rates(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym])
              end
              flash[:status] = _('deleted_rates') + ": " + @tariff_analize[:deleted_rates].to_s
              Action.add_action(session[:user_id], "tariff_import_2", _('Tariff_was_imported_from_CSV'))
          end

        else
          flash[:notice] = _('Please_Select_Columns')
          redirect_to :action => "import_csv2", :id => tariff_id, :step => "2" and return false
        end
      else
        flash[:notice] = _('Zero_file')
        redirect_to :controller => "tariffs", :action => "list" and return false
      end
    end
  end

  def bad_rows_from_csv
    @page_title = _('Bad_rows_from_CSV_file')
    @csv2= params[:csv2].to_i
    if @csv2.to_i == 0
      @rows = session[:bad_lines_array]
      @status = session[:bad_lines_status_array]
    else
      if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym])
        @rows = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym]} WHERE f_error = 1")
      end
    end
    render(:layout => "layouts/mor_min")
  end

  def dst_to_create_from_csv
    @page_title = _('Dst_to_create_from_csv')
    @file = session[:file]
    @status = session[:status_array]
    @csv2=0
    if !@file.blank?
      if params[:csv2].to_i == 0
        flash[:notice] = _('Zero_file_size')
        redirect_to :controller => "tariffs", :action => "list"
      else
        @csv2=1
        if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym])
          @csv_file = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym]} WHERE not_found_in_db = 1 AND f_error = 0")
        end
        render(:layout => "layouts/mor_min")
      end
    else
      flash[:notice] = _('Zero_file_size')
      redirect_to :controller => "tariffs", :action => "list"
    end
  end

  def dst_to_update_from_csv
    @page_title = _('Dst_to_update_from_csv')
    @file = session[:file]
    @status = session[:status_array]
    @csv2= params[:csv2].to_i
    if @csv2.to_i == 0
      @dst = session[:dst_to_update_hash]
    else
      @tariff_id = params[:tariff_id].to_i
      if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym])
        @dst = ActiveRecord::Base.connection.select_all("SELECT destinations.prefix, col_#{session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_dst]} as new_name, IFNULL(original_destination_name,destinations.name) as dest_name FROM destinations JOIN #{session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym]} ON (replace(col_#{session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_prefix]}, '\\r', '') = prefix) WHERE ned_update IN (1, 3, 5, 7) AND BINARY replace(replace(TRIM(col_2), '\r', ''), '  ', ' ') != IFNULL(original_destination_name,destinations.name)")
      end
    end
    render(:layout => "layouts/mor_min")
  end


  def subcode_to_update_from_csv
    @page_title = _('Destination_subcodes_update')
    @file = session[:file]
    @status = session[:status_array]
    @csv2= params[:csv2].to_i
    if @csv2.to_i == 0
      @dst = session[:subcodes_to_update_hash]
    else
      @tariff_id = params[:tariff_id].to_i
      if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym])
        @dst = ActiveRecord::Base.connection.select_all("SELECT destinations.prefix, col_#{session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_subcode]} as new_sub, destinations.subcode as dest_sub FROM destinations JOIN #{session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym]} ON (replace(col_#{session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_prefix]}, '\\r', '') = prefix)  WHERE ned_update IN (2, 3, 6, 7) ")
      end
    end
    render(:layout => "layouts/mor_min")
  end


  def dir_to_update_from_csv
    @page_title = _('Direction_to_update_from_csv')
    @file = session[:file]
    @status = session[:status_array]
    @csv2= params[:csv2].to_i
    if @csv2.to_i == 0
      @dst = session[:dst_to_update_hash]
    else
      @tariff_id = params[:tariff_id].to_i
      if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym])
        imp_cc = session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_cc]
        table_name = session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym]
        imp_prefix = session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_prefix]
        @directions = ActiveRecord::Base.connection.select_all("SELECT prefix, destinations.direction_code old_direction_code, replace(col_#{imp_cc}, '\\r', '') new_direction_code from #{table_name} join directions on (replace(col_#{imp_cc}, '\\r', '') = directions.code) join destinations on (replace(col_#{imp_prefix}, '\\r', '') = destinations.prefix) WHERE destinations.direction_code != directions.code;")
      end
    end
    render(:layout => "layouts/mor_min")
  end

  def rate_import_status
    #render(:layout => false)
  end

  def rate_import_status_view
    render(:layout => false)
  end

  # before_filter : tariff(find_taririff_from_id)
  def delete_all_rates
    a=check_user_for_tariff(@tariff.id)
    return false if !a
    @tariff.delete_all_rates
    @tariff.updated
    flash[:status] = _('All_rates_deleted')
    redirect_to :action => 'list'
  end

=begin
  returns first letter of destination group name if it has any rates set, if nothing is set return 'A'
=end
  def tariff_dstgroups_with_rates(tariff_id)
    res = Destinationgroup.select(:name).joins(:rates).where("rates.tariff_id = #{tariff_id}").group("destinationgroups.id").order("destinationgroups.name, destinationgroups.desttype ASC").all
    res.map! { |rate| rate['name'][0..0] }
    res.uniq
  end

  def dstgroup_name_first_letters
    res = Destination.select("destinationgroups.name").joins(:destinationgroup).group(:destinationgroup_id).order("destinationgroups.name, destinationgroups.desttype ASC").all
    res.map! {|dstgroup| dstgroup['name'][0..0].upcase}
    res.uniq
  end

  # =============== RATES FOR USER ==================
  # before_filter : tariff(find_taririff_from_id)
  def user_rates_list
    tariff_id = @tariff.id
    check_user_for_tariff(tariff_id)

    if flash[:notice].blank? and @tariff.purpose != 'user'
      flash[:notice] = _('Tariff_type_error')
      redirect_to :controller => :tariffs, :action => :list and return false
    end


    @page_title = _('Rates_for_tariff') #+": " + @tariff.name
    @page_icon = "coins.png"
    @res =[]
    session[:tariff_user_rates_list] ? @options = session[:tariff_user_rates_list] : @options = {:page => 1}
    @options[:page] = params[:page].to_i if !params[:page].blank?
    @items_per_page = Confline.get_value("Items_Per_Page").to_i
    @letter_select_header_id = tariff_id

    #dst groups are rendered in 'pages' according to they name's first letter
    #if no letter is specified in params, by default we show page full of
    #dst groups
    @directions_first_letters = tariff_dstgroups_with_rates(tariff_id)
    @st = (params[:st] ? params[:st].upcase : (@directions_first_letters[0] || 'A'))

    #needed to know whether to make link to sertain letter or not
    #when rendering letter_select_header
    @directions_defined = dstgroup_name_first_letters()

    @page = 1
    @page = params[:page].to_i if params[:page]

    if params[:s_prefix] and !params[:s_prefix].blank?
      @s_prefix = params[:s_prefix].gsub(/[^0-9%]/, '')
      cond = "prefix LIKE '#{@s_prefix.to_s}'"
      @search =1
    else
      cond = "destinationgroups.name LIKE '#{@st}%'"
    end

    #Cia refactorintas , veikia x7 greiciau...
    sql = "SELECT * FROM (
                          SELECT destinationgroups.flag, destinationgroups.name, destinationgroups.desttype, destinationgroup_id AS dg_id, COUNT(DISTINCT destinations.id) AS destinations  FROM destinations
                                JOIN destinationgroups ON (destinationgroups.id = destinations.destinationgroup_id)
                                WHERE #{cond}
                                GROUP BY destinations.destinationgroup_id
                                ORDER BY destinationgroups.name, destinationgroups.desttype ASC
                         ) AS dest
              LEFT JOIN (SELECT rates.ghost_min_perc, rates.destinationgroup_id AS dg_id2, rates.id AS rate_id, COUNT(DISTINCT aratedetails.id) AS arates_size,  IF(art2.id IS NULL, aratedetails.price, NULL) AS price, IF(art2.id IS NULL, aratedetails.round, NULL) AS round, IF(art2.id IS NOT NULL,  NULL, 'minute') as artype FROM destinations
                                JOIN destinationgroups ON (destinationgroups.id = destinations.destinationgroup_id)
                                LEFT JOIN rates ON (rates.destinationgroup_id = destinationgroups.id )
                                LEFT JOIN aratedetails ON (aratedetails.rate_id = rates.id)
                                LEFT JOIN aratedetails AS art2 ON (art2.rate_id = rates.id and art2.artype != 'minute')
                                WHERE #{cond}  AND rates.tariff_id = #{tariff_id}
                                GROUP BY rates.destinationgroup_id
                        ) AS rat ON (dest.dg_id = rat.dg_id2)"

    #@rates = Rate.find(:all, :conditions=>["rates.tariff_id = ? #{con}", @tariff.id], :include => [:aratedetails, :destinationgroup ], :order=>"destinationgroups.name, destinationgroups.desttype ASC" )
    @res = ActiveRecord::Base.connection.select_all(sql)
    @options[:total_pages] = (@res.size.to_d / @items_per_page.to_d).ceil
    @options[:page] = 1 if @options[:page] > @options[:total_pages]
    istart = (@options[:page]-1)*@items_per_page
    iend = (@options[:page])*@items_per_page-1
    @res = @res[istart..iend]
    session[:tariff_user_rates_list] = @options

    rids= []
    @res.each { |res| rids << res['rate_id'].to_i if !res['rate_id'].blank? }
    @rates_list = Rate.where("rates.id IN (#{rids.join(',')})").includes([:aratedetails, :tariff, :destinationgroup]).all if rids.size.to_i > 0

    current_user_id = current_user.id.to_i
    @can_edit = true
    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user_id and CommonUseProvider.where(["reseller_id = ? AND tariff_id = ?", current_user_id, tariff_id]).first
      @can_edit = false
    end

  end

  def user_arates
    @rate = Rate.where(["id = ?", params[:id]]).first
    if !@rate
      Action.add_action(session[:user_id], "error", "Rate: #{params[:id].to_s} was not found") if session[:user_id].to_i != 0
      dont_be_so_smart
      redirect_to :root and return false
    end
    @tariff = @rate.tariff
    @page_title = _('Rates_for_tariff') +": " + @tariff.name
    @dgroup = @rate.destinationgroup

    @st = params[:st]
    @dt = params[:dt]
    @dt = "" if not params[:dt]

    @ards = Aratedetail.where(["rate_id = ? AND start_time = ? AND daytype = ?", @rate.id, @st, @dt]).order("aratedetails.from ASC, artype ASC")

    @ards and @ards.size > 0 ? @et = nice_time2(@ards[0].end_time) : @et = "23:59:59"

    @can_add = false
    #last ard
    lard = @ards.last
    if lard
      lard_duration = lard.duration
      lard_artype = lard.artype
      lard_from = lard.from
      if (lard_duration != -1 and lard_artype == "minute") or (lard_artype == "event")
        @can_add = true
        @from = lard_from + lard_duration if lard_artype == "minute"
        @from = lard_from if lard_artype == "event"
      end
    end

    current_user_id = current_user.id.to_i
    @can_edit = true
    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user_id and CommonUseProvider.where(["reseller_id = ? AND tariff_id = ?", current_user_id, @tariff.id]).first
      @can_edit = false
    end

  end

  # before_filter : tariff(find_taririff_from_id)
  def user_arates_full
    check_user_for_tariff(@tariff.id)
    @page_title = _('Rates_for_tariff') +": " + @tariff.name
    @dgroup = Destinationgroup.where(:id => params[:dg]).first

    unless @dgroup
      flash[:notice]=_('Destinationgroup_was_not_found')
      redirect_to :action => :list and return false
    end

    @rate = @dgroup.rate(@tariff.id)

    if not @rate
      rate = Rate.new(tariff: @tariff, destinationgroup: @dgroup)
      rate.save

      ard = Aratedetail.new(
          from: 1,
          duration: -1,
          artype: 'minute',
          round: 1,
          price: 0,
          rate: rate,
      )
      ard.save

      @rate = rate
      #my_debug "creating rate and ard"
    end

    @ards = @rate.aratedetails

    if @ards.first.blank?

      ard = Aratedetail.new(
          from: 1,
          duration: -1,
          artype: 'minute',
          round: 1,
          price: 0,
          rate: @rate
      )
      ard.save

      @ards = @rate.aratedetails
    end


    if @ards.first.daytype.to_s == ""
      @wdfd = true

      sql = "SELECT TIME(start_time) start_time, TIME(end_time) end_time FROM aratedetails WHERE daytype = '' AND rate_id = #{@rate.id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @st_arr = []
      @et_arr = []
      for r in res
        @st_arr << r["start_time"].strftime("%H:%M:%S")
        @et_arr << r["end_time"].strftime("%H:%M:%S")
      end

    else
      @wdfd = false

      sql = "SELECT TIME(start_time) start_time, TIME(end_time) end_time FROM aratedetails WHERE daytype = 'WD' AND rate_id = #{@rate.id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @wst_arr = []
      @wet_arr = []
      for r in res
        @wst_arr << r["start_time"].strftime("%H:%M:%S")
        @wet_arr << r["end_time"].strftime("%H:%M:%S")
      end

      sql = "SELECT TIME(start_time) start_time, TIME(end_time) end_time FROM aratedetails WHERE daytype = 'FD' AND rate_id = #{@rate.id} GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @fst_arr = []
      @fet_arr = []
      for r in res
        @fst_arr << r["start_time"].strftime("%H:%M:%S")
        @fet_arr << r["end_time"].strftime("%H:%M:%S")
      end

    end

    current_user_id = current_user.id.to_i
    @can_edit = true

    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user_id and
      CommonUseProvider.where(["reseller_id = ? AND tariff_id = ?", current_user_id, @tariff.id]).first
      @can_edit = false
    end
  end

  def user_ard_time_edit
    @rate = Rate.where(:id => params[:id]).first

    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end

    a = check_user_for_tariff(@rate.tariff_id)
    return false if !a

    dt = params[:daytype]

    et = params[:date][:hour] + ":" + params[:date][:minute] + ":" + params[:date][:second]
    st = params[:st]

    if Time.parse(st) > Time.parse(et)
      flash[:notice] = _('Bad_time')
      redirect_to :action => 'user_arates_full', :id => @rate.tariff_id, :dg => @rate.destinationgroup_id and return false
    end

    rdetails = @rate.aratedetails_by_daytype(params[:daytype])

    ard = Aratedetail.where("rate_id = #{@rate.id} AND start_time = '#{st}'  AND daytype = '#{dt}'").first

    #my_debug ard.start_time
    #my_debug rdetails[(rdetails.size - 1)].start_time

    # we need to create new rd to cover all day
    if (et != "23:59:59") and ((rdetails[(rdetails.size - 1)].start_time == ard.start_time))
      nst = Time.mktime('2000', '01', '01', params[:date][:hour], params[:date][:minute], params[:date][:second]) + 1.second
      #my_debug nst
      ards = Aratedetail.where("rate_id = #{@rate.id} AND start_time = '#{st}'   AND daytype = '#{dt}'")

      ards.each do |arate_detail|
        attributes = arate_detail.attributes.merge(start_time: nst.to_s, end_time: '23:59:59')

        new_arate_detail = Aratedetail.new(attributes)
        new_arate_detail.save

        arate_detail.end_time = et
        arate_detail.save
      end

    end

    @rate.tariff_updated
    flash[:status] = _('Rate_details_updated')
    redirect_to :action => 'user_arates_full', :id => @rate.tariff_id, :dg => @rate.destinationgroup_id
  end


  def artg_destroy
    @rate = Rate.where(:id => params[:id]).first
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    dt = params[:dt]
    dt = "" if not params[:dt]
    st = params[:st]

    ards = Aratedetail.where("rate_id = #{@rate.id} AND start_time = '#{st}'   AND daytype = '#{dt}'")
    #my_debug ards.size
    pet = nice_time2(ards[0].start_time - 1.second)

    for a in ards
      a.destroy
    end

    pards = Aratedetail.where("rate_id = #{@rate.id} AND end_time = '#{pet}'   AND daytype = '#{dt}'")
    for pa in pards
      pa.end_time = "23:59:59"
      pa.save
    end


    flash[:status] = _('Rate_details_updated')
    redirect_to :action => 'user_arates_full', :id => @rate.tariff_id, :dg => @rate.destinationgroup_id

  end


  def ard_manage
    @rate = Rate.where(:id => params[:id]).first

    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end

    a = check_user_for_tariff(@rate.tariff_id)
    return false if !a

    rdetails = @rate.aratedetails
    rdaction = params[:rdaction]

    if rdaction == "COMB_WD"
      for rd in rdetails
        if rd.daytype == "WD"
          rd.daytype = ""
          rd.save
        else
          rd.destroy
        end
      end
      flash[:status] = _('Rate_details_combined')
    end

    if rdaction == "COMB_FD"
      for rd in rdetails
        if rd.daytype == "FD"
          rd.daytype = ""
          rd.save
        else
          rd.destroy
        end
      end

      flash[:status] = _('Rate_details_combined')
      @rate.tariff_updated
    end

    if rdaction == "SPLIT"
      rdetails.each do |rate_detail|
        attributes = rate_detail.attributes.merge(daytype: 'FD')
        new_rate_detail = Aratedetail.new(attributes)
        new_rate_detail.save
        rate_detail.daytype = "WD"
        rate_detail.save
      end

      flash[:status] = _('Rate_details_split')
      @rate.tariff_updated
    end

    redirect_to :action => 'user_arates_full', :id => @rate.tariff_id, :dg => @rate.destinationgroup_id
  end

  #update one rate
  def user_rate_update
    @ard = Aratedetail.where(:id => params[:id]).first
    unless @ard
      flash[:notice]=_('Aratedetail_was_not_found')
      redirect_to :action => :list and return false
    end

    a = check_user_for_tariff(@ard.rate.tariff_id)
    return false if !a
    if params[:infinity] == "1"
      p_duration = -1
    else
      p_duration = params[:duration].to_i
    end
    from_duration = params[:from].to_i + p_duration
    from_duration_db = @ard.from.to_i + @ard.duration.to_i
    rate_id = @ard.rate_id
    st = nice_time2 @ard.start_time
    dt = @ard.daytype

    if (p_duration != -1 and from_duration < params[:round].to_i and params[:rate].to_i == 0) or (params[:rate].to_i == 1 and @ard.duration.to_i != -1 and from_duration_db < params["round_#{@ard.id}".to_sym].to_i)
      flash[:notice] = _('Round_by_is_too_big')
    else
      if params[:rate].to_i == 0
        artype = params[:artype]

        duration = params[:duration].to_i
        infinity = params[:infinity]
        duration = -1 if infinity == "1" and artype == "minute"
        duration = 0 if artype == "event"

        round = params[:round].to_i
        price = params[:price].to_d
        round = 1 if round < 1

        @ard.assign_attributes(
          from: params[:from],
          artype: artype,
          duration: duration,
          round: round,
          price: price
        )
      else
        @ard.assign_attributes(
          price: params["price_#{@ard.id}".to_sym].to_d,
          round: params["round_#{@ard.id}".to_sym].to_i
        )
      end
      @ard.save
      flash[:status] = _('Rate_updated')
    end
    redirect_to :action => 'user_arates', :id => rate_id, :st => st, :dt => dt
  end


  def user_rate_add
    @rate = Rate.where(:id => params[:id]).first
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    @ard = Aratedetail.new

    a = check_user_for_tariff(@rate.tariff_id)
    return false if !a
    from_duration = params[:from].to_i + params[:duration].to_i
    artype = params[:artype]

    duration = params[:duration].to_i
    infinity = params[:infinity]
    duration = -1 if infinity == "1" and artype == "minute"
    duration = 0 if artype == "event"

    round = params[:round].to_i
    price = params[:price].to_d
    round = 1 if round < 1

    rate_id = @rate.id
    st = params[:st]
    et = params[:et]
    dt = params[:dt]
    dt = "" if not params[:dt]
    if params[:duration].to_i!= -1 and from_duration < params[:round].to_i
      flash[:notice] = _('Round_by_is_too_big')
    else
      attributes = {
          from: params[:from],
          artype: artype,
          duration: duration,
          round: round,
          price: price,
          rate: @rate,
          daytype: dt,
          start_time: st,
          end_time: et
      }
      @ard.update_attributes(attributes)
      flash[:status] = _('Rate_updated')
    end
    redirect_to :action => 'user_arates', :id => rate_id, :st => st, :dt => dt

  end

  def user_rate_delete
    @ard = Aratedetail.where(:id => params[:id]).first
    unless @ard
      flash[:notice]=_('Aratedetail_was_not_found')
      redirect_to :action => :list and return false
    end

    a = check_user_for_tariff(@ard.rate.tariff)
    return false if !a

    rate_id = @ard.rate_id
    st = nice_time2 @ard.start_time
    dt = @ard.daytype

    @ard.destroy

    flash[:status] = _('Rate_deleted')
    redirect_to :action => 'user_arates', :id => rate_id, :st => st, :dt => dt

  end

  #update all rates at once
  # before_filter : tariff(find_taririff_from_id)
  def user_rates_update
    a=check_user_for_tariff(@tariff.id)
    return false if !a
    @dgroups = Destinationgroup.where("destinationgroups.name LIKE '#{params[:st]}%'").order("name ASC, desttype ASC").all

    for dg in @dgroups

      price = ""
      price = params[('rate' + dg.id.to_s).intern] if params[('rate' + dg.id.to_s).intern]
      round = params[('round' + dg.id.to_s).intern].to_i
      round = 1 if round < 0
      #      if price.to_d != 0 or round != 1
      rrate = dg.rate(@tariff.id)
      unless price.blank?
        #let's create ard
        unless rrate
          rate = Rate.new(
              tariff: @tariff,
              destinationgroup: dg,
              ghost_min_perc: params["gch#{dg.id}".intern].to_d
          )
          rate.tariff_updated
          rate.save


          ard = Aratedetail.new(
              from: 1,
              duration: -1,
              artype: 'minute',
              round: round,
              price: price.to_d,
              rate: rate
          )
          ard.save

          #my_debug "create rate"

        else
          #update existing ard
          aratedetails = rrate.aratedetails
          #my_debug aratedetails.size
          if aratedetails.size == 1
            ard = aratedetails[0]
            #my_debug price
            #my_debug "--"
            if price == ''
              rrate.destroy_everything
              #ard.destroy
            else
              from_duration_db = ard.from.to_i + ard.duration.to_i
              rrate.ghost_min_perc = params[("gch" + dg.id.to_s).intern].to_d
              rrate.tariff_updated
              rrate.save
              if ard.duration.to_i != -1 and from_duration_db < round.to_i
                flash[:notice] = _('Rate_not_updated_round_by_is_too_big') + ': '+ "#{dg.name}"
                redirect_to :action => 'user_rates_list', :id => @tariff.id, :page => params[:page], :st => params[:st], :s_prefix => params[:s_prefix] and return false
              else
                ard.price = price.to_d
                ard.round = round
                ard.save
              end
            end
          end

        end
      else
        if rrate
          rrate.ghost_min_perc = params[('gch' + dg.id.to_s).intern].to_d
          rrate.save
        end
      end
    end

    flash[:status] = _('Rates_updated')
    redirect_to(action: 'user_rates_list', id: @tariff.id, page: params[:page], st: params[:st], s_prefix: params[:s_prefix]) && (return false)
  end


  def user_rate_destroy
    rate = Rate.where(:id => params[:id]).first
    unless rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    tariff_id = rate.tariff_id

    a = check_user_for_tariff(tariff_id)
    return false if !a

    rate.destroy_everything

    flash[:status] = _('Rate_deleted')
    redirect_to(action: 'user_rates_list', id: tariff_id, page: params[:page], st: params[:st], s_prefix: params[:s_prefix])

  end

  #for final user
  # before_filter : user; tariff
  def user_rates
    @page_title, @page_icon = [_('Personal_rates'), 'coins.png']

    if !(user? || reseller?) || (session[:show_rates_for_users].to_i != 1)
      dont_be_so_smart
      redirect_to :root and return false
    end

    @show_currency_selector = true
    show_currency = session[:show_currency].gsub(/[^A-Za-z]/, '')
    items_per_page = session[:items_per_page]

    session[:user_rates_prefix] = params[:s_prefix].gsub(/[^0-9%]/, '') if params[:s_prefix]
    @s_prefix = session[:user_rates_prefix] ||= ''
    prefix_cond = @s_prefix.present? ? "prefix LIKE '#{@s_prefix.to_s}'" : ''
    @page = params[:page] ? params[:page].to_i : 1

    if @tariff.purpose == 'user'
      @letters_to_bold = Destinationgroup.select('LEFT(destinationgroups.name, 1) AS first_letter')
                                         .joins('JOIN destinations ON (destinations.destinationgroup_id = destinationgroups.id)')
                                         .where(prefix_cond)
                                         .group('first_letter').collect(&:first_letter)
    else
      @letters_to_bold = @tariff.rates.select('LEFT(directions.name, 1) AS first_letter')
                                .joins('JOIN destinations ON (rates.destination_id = destinations.id)')
                                .joins('JOIN directions ON (destinations.direction_code = directions.code)')
                                .where(prefix_cond)
                                .group('first_letter').collect(&:first_letter)
    end

    @st = (params[:st] ? params[:st].upcase : (@letters_to_bold[0] || 'A'))

    @dgroupse = Destinationgroup.joins('JOIN destinations ON (destinations.destinationgroup_id = destinationgroups.id)')
                                .where(['destinationgroups.name like ?', "#{@st}%"])
                                .where(prefix_cond)
                                .group('destinationgroups.id')
                                .order('destinationgroups.name ASC, destinationgroups.desttype ASC')

    @dgroups = []
    ibeginn, iend = generate_page_details(@dgroupse.length)

    for item in ibeginn..iend
      @dgroups << @dgroupse[item]
    end

    if @tariff.purpose == 'user'
      @total_pages = (@dgroupse.length.to_d / items_per_page).ceil
    else
      @rates = @tariff.rates_by_st(@st, 10000, prefix_cond)
      @total_pages = (@rates.length.to_d / items_per_page).ceil

      @all_rates = @rates
      @rates = []

      ibeginn, iend = generate_page_details(@all_rates.size)
      for item in ibeginn..iend
        @rates << @all_rates[item]
      end

      exrate = Currency.count_exchange_rate(@tariff.currency, show_currency)
      @ratesd = Ratedetail.find_all_from_id_with_exrate({rates: @rates, exrate: exrate, destinations: true, directions: true})
    end

    tariff_id = @tariff.id
    @letter_select_header_id = tariff_id
    @page_select_header_id = tariff_id

    @exchange_rate = count_exchange_rate(@tariff.currency, show_currency)
    @cust_exchange_rate = count_exchange_rate(session[:default_currency], show_currency)
    @show_rates_without_tax = Confline.get_value('Show_Rates_Without_Tax', @user.owner_id)
  end

  # for final user
  # before_filter : user; tariff
  def common_use_prov_rates
    common_use_provider_tariff(params[:id])

    if @common_use_provider.blank?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
    @page_title = @tariff.name
    @page_icon = 'coins.png'

    @show_currency_selector = true
    show_currency = session[:show_currency].gsub(/[^A-Za-z]/, '')
    items_per_page =  session[:items_per_page]

    @page = (params[:page].present?) ? params[:page].to_i : 1

    @st = (params[:st] && ('A'..'Z').include?(params[:st].upcase)) ?  params[:st].upcase  : 'A'
    @dgroupse = Destinationgroup.where(['name like ?', "#{@st}%"]).order('name ASC, desttype ASC')

    @dgroups = []
    dgroupse_size = @dgroupse.size
    ibeginn, iend = generate_page_details(dgroupse_size)
    for item in ibeginn..iend
      @dgroups << @dgroupse[item]
    end

    if @tariff.purpose == 'user'
      @total_pages = (dgroupse_size.to_d / items_per_page).ceil
    else
      @rates = @tariff.rates_by_st(@st, 10000, '')
      @total_pages = (@rates.length.to_d / items_per_page).ceil

      @all_rates = @rates
      @rates = []
      ibeginn, iend = generate_page_details(@all_rates.size)
      for item in ibeginn..iend
        @rates << @all_rates[item]
      end

      exrate = Currency.count_exchange_rate(@tariff.currency, show_currency)
      @ratesd = Ratedetail.find_all_from_id_with_exrate({:rates => @rates, :exrate => exrate, :destinations => true, :directions => true})
    end

    @letter_select_header_id = @common_use_provider
    @page_select_header_id = @common_use_provider

    @exchange_rate = count_exchange_rate(@tariff.currency, show_currency)
    @cust_exchange_rate = count_exchange_rate(session[:default_currency], show_currency)
    @show_rates_without_tax = Confline.get_value('Show_Rates_Without_Tax', @user.owner_id)
    render 'user_rates'
  end

  # before_filter : user; tariff
  def user_rates_detailed
    @page_title = _('Personal_rates')
    @page_icon = "view.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Advanced_Rates"
    #    @user = current_user
    #    @tariff = @user.tariff

    if (Confline.get_value("Show_Advanced_Rates_For_Users", current_user.owner_id).to_i != 1 || session[:show_rates_for_users].to_i != 1) && @common_use_provider.blank?
      dont_be_so_smart
      redirect_to :root and return false
    end

    @page_title = _("Detailed_rates")
    @dgroup = Destinationgroup.where(:id => params[:id]).first
    unless @dgroup
      dont_be_so_smart
      redirect_to :root and return false
    end

    @rate = @dgroup.rate(@tariff.id)

    @custom_rate = Customrate.where(["user_id = ? AND destinationgroup_id = ?", session[:user_id], @dgroup.id]).first
    if !@rate and !@custom_rate
      dont_be_so_smart
      redirect_to :root and return false
    end

    if @custom_rate
      @ards = @custom_rate.acustratedetails
      r_details = 'acustratedetails'
      r_ident	= 'customrate_id'
      r_id	= @custom_rate.id or 0
    else
      @ards = @rate.aratedetails
      r_details = 'aratedetails'
      r_ident	= 'rate_id'
      r_id	= @rate.id or 0
    end

    if @ards.first.daytype.to_s == ""
      @wdfd = true

      sql = "SELECT * FROM #{r_details} WHERE daytype = '' AND #{r_ident} = '#{r_id}' GROUP BY start_time ORDER BY start_time ASC"
      @day_arr = ActiveRecord::Base.connection.select_all(sql)
    else
      @wdfd = false

      sql = "SELECT * FROM #{r_details} WHERE daytype = 'WD' AND #{r_ident} = '#{r_id}' GROUP BY start_time ORDER BY start_time ASC"
      @wd_arr = ActiveRecord::Base.connection.select_all(sql)

      sql = "SELECT * FROM #{r_details} WHERE daytype = 'FD' AND #{r_ident} = '#{r_id}' GROUP BY start_time ORDER BY start_time ASC"
      @fd_arr = ActiveRecord::Base.connection.select_all(sql)
    end

    @exchange_rate = count_exchange_rate(@tariff.currency, session[:show_currency])
    @show_rates_without_tax = Confline.get_value("Show_Rates_Without_Tax", @user.owner_id)
  end

  def user_advrates
    @page_title = _('Rates_details')
    @page_icon = "coins.png"

    @dgroup = Destinationgroup.where(:id => params[:id]).first
    unless @dgroup
      flash[:notice]=_('Destinationgroup_was_not_found')
      redirect_to :action => :list and return false
    end
    @rate = @dgroup.rate(session[:tariff_id])
    @custrate = @dgroup.custom_rate(session[:user_id])

    @cards = Acustratedetail.where("customrate_id = #{@custrate.id}").order("daytype DESC, start_time ASC, acustratedetails.from ASC, artype ASC") if @custrate
    @ards = Aratedetail.where("rate_id = #{@rate.id}").order("daytype DESC, start_time ASC, aratedetails.from ASC, artype ASC")

    if @cards and @cards.size > 0
      table = "acustratedetails"
      trate_id = "customrate_id"
      rate_id = @custrate.id
    else
      table = "aratedetails"
      trate_id = "rate_id"
      rate_id = @rate.id
    end

    if @ards[0].daytype == ""
      @wdfd = true


      sql = "SELECT start_time, end_time FROM #{table} WHERE daytype = '' AND #{trate_id} = #{rate_id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @st_arr = []
      @et_arr = []
      for r in res
        @st_arr << r["start_time"]
        @et_arr << r["end_time"]
      end

    else
      @wdfd = false

      sql = "SELECT start_time, end_time FROM #{table} WHERE daytype = 'WD' AND #{trate_id} = #{rate_id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @wst_arr = []
      @wet_arr = []
      for r in res
        @wst_arr << r["start_time"]
        @wet_arr << r["end_time"]
      end

      sql = "SELECT start_time, end_time FROM #{table} WHERE daytype = 'FD' AND #{trate_id} = #{rate_id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @fst_arr = []
      @fet_arr = []
      for r in res
        @fst_arr << r["start_time"]
        @fet_arr << r["end_time"]
      end

    end

    @tax = session[:tax]
  end

  #======= Day setup ==========

  def day_setup
    @page_title = _('Day_setup')
    @page_icon = "date.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Day_setup"
    @days = Day.order("date ASC")
  end

  def day_add
    date = params[:date][:year] + "-" + good_date(params[:date][:month]) + "-" + good_date(params[:date][:day])
    #my_debug  date

    # real_date = Time.mktime(params[:date][:year], good_date(params[:date][:month]), good_date(params[:date][:day]))

    if Application.validate_date(params[:date][:year], good_date(params[:date][:month]), good_date(params[:date][:day])) == 0
      flash[:notice] = _('Bad_date')
      redirect_to :action => 'day_setup' and return false
    end

    #my_debug "---"


    if Day.where(["date = ? ", date]).first
      flash[:notice] = _('Duplicate_date')
      redirect_to :action => 'day_setup' and return false
    end

    attributes = params.slice(:daytype, :description).merge date: date
    day = Day.new(attributes)
    day.save

    flash[:status] = _('Day_added') + ": " + date
    redirect_to :action => 'day_setup'
  end


  def day_destroy

    day = Day.where(:id => params[:id]).first
    unless day
      flash[:notice]=_('Day_was_not_found')
      redirect_to :action => :list and return false
    end
    flash[:status] = _('Day_deleted') + ": " + day.date.to_s
    day.destroy
    redirect_to :action => 'day_setup'
  end


  def day_edit
    @page_title = _('Day_edit')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Day_setup"

    @day = Day.where(:id => params[:id]).first
    unless @day
      flash[:notice]=_('Day_was_not_found')
      redirect_to :action => :list and return false
    end
  end

  def day_update
    day = Day.where(:id => params[:id]).first
    unless day
      flash[:notice]=_('Day_was_not_found')
      redirect_to :action => :list and return false
    end

    date = params[:date][:year] + "-" + good_date(params[:date][:month]) + "-" + good_date(params[:date][:day])

    if Day.where(["date = ? and id != ?", date, day.id]).first
      flash[:notice] = _('Duplicate_date')
      redirect_to :action => 'day_setup' and return false
    end

    attributes = params.slice(:daytype, :description).merge date: date
    day.assign_attributes(attributes)
    day.save

    flash[:status] = _('Day_updated') + ": " + date
    redirect_to :action => 'day_setup'

  end


  #======== Make user tariff out of provider tariff ==========
  # before_filter : tariff(find_taririff_from_id)
  def make_user_tariff
    @page_title = _('Make_user_tariff')
    @page_icon = "application_add.png"
    @ptariff = @tariff
    @total_rates = Rate.where("tariff_id = '#{@ptariff.id}' AND destination_id != 0").count
    check_user_for_tariff(@ptariff.id)
    @rates_number = Rate.where("tariff_id = '#{@ptariff.id}' AND destination_id != 0").count
  end

  # before_filter : tariff(find_taririff_from_id)
  def make_user_tariff_wholesale
    @page_title = _('Make_user_tariff')
    @page_icon = "application_add.png"
    @ptariff = @tariff
    @tariff_rates = @ptariff.rates.size
    check_user_for_tariff(@ptariff.id)
    @rates_number = Rate.where("tariff_id = '#{@ptariff.id}' AND destination_id != 0").count
  end

  # before_filter : tariff(find_taririff_from_id)
  def make_user_tariff_status
    @page_title = _('Make_user_tariff')
    @page_icon = "application_add.png"
    @ptariff = @tariff
    a=check_user_for_tariff(@ptariff.id)
    return false if !a

    @add_amount = 0
    @add_percent = 0
    @add_confee_percent = 0
    @add_confee_amount = 0
    if (params[:add_amount].to_s.length + params[:add_percent].to_s.length + params[:add_confee_amount].to_s.length + params[:add_confee_percent].to_s.length) == 0
      flash[:notice] = _('Please_enter_amount_or_percent')
      redirect_to :action => 'make_user_tariff', :id => @ptariff.id and return false
    end

    @add_amount = params[:add_amount] if params[:add_amount].length > 0
    @add_percent = params[:add_percent] if params[:add_percent].length > 0
    @add_confee_amount = params[:add_confee_amount] if params[:add_confee_amount].length > 0
    @add_confee_percent = params[:add_confee_percent] if params[:add_confee_percent].length > 0
    if @ptariff.make_retail_tariff(@add_amount, @add_percent, @add_confee_amount, @add_confee_percent, correct_owner_id)
      flash[:status] = _('Tariff_created')
    else
      flash[:notice] = _('Tariff_not_created')
    end

  end

  #
  # Makes new tariff and adds fixed percentage and/or amount to prices
  # Most of the work is done inside model.

  # before_filter : tariff(find_taririff_from_id)
  def make_user_tariff_status_wholesale
    @page_title = _('Make_wholesale_tariff')
    @page_icon = "application_add.png"
    @ptariff = @tariff
    a=check_user_for_tariff(@ptariff)
    return false if !a
    if (params[:add_amount].to_s.length + params[:add_percent].to_s.length + params[:add_confee_amount].to_s.length + params[:add_confee_percent].to_s.length) == 0
      flash[:notice] = _('Please_enter_amount_or_percent')
      redirect_to :action => 'make_user_tariff_wholesale', :id => @ptariff.id and return false
    end
    @rates_number = Rate.where("tariff_id = '#{@ptariff.id}' AND destination_id != 0").count
    @add_amount = params[:add_amount].to_d
    @add_percent = params[:add_percent].to_d
    @add_confee_amount = params[:add_confee_amount].to_d
    @add_confee_percent = params[:add_confee_percent].to_d
    if admin? or accountant?
      @t_type = params[:t_type] if params[:t_type].to_s.length > 0
    end
    if session[:usertype] == "reseller"
      @t_type ="user_wholesale"
    end

    unless @t_type
      flash[:notice] = _("Please_set_tariff_type")
      redirect_to :action => 'make_user_tariff_wholesale', :id => @ptariff.id and return false
    end

    if @ptariff.make_wholesale_tariff(@add_amount, @add_percent, @add_confee_amount, @add_confee_percent, @t_type)
      flash[:status] = _('Tariff_created')
    else
      flash[:notice] = _('Such_Tariff_Already_Exists')
      redirect_to :action => 'make_user_tariff_wholesale', :id => @ptariff.id and return false
    end
  end

  def change_tariff_for_users
    @page_title = _('Change_tariff_for_users')
    @page_icon = "application_add.png"
    user_id = correct_owner_id
    if Confline.get_value("User_Wholesale_Enabled").to_i == 0
      cond = " AND purpose = 'user' "
    else
      cond = " AND (purpose = 'user' OR purpose = 'user_wholesale') "
    end
    @tariffs= Tariff.where("owner_id = #{user_id} #{cond}")
  end

  def update_tariff_for_users
    if params[:tariff_from] and params[:tariff_to]
      @tariff_from = Tariff.where(:id => params[:tariff_from]).first
      unless @tariff_from
        flash[:notice]=_('Tariff_was_not_found')
        redirect_to :action => :list and return false
      end
      @tariff_to = Tariff.where(:id => params[:tariff_to]).first
      unless @tariff_to
        flash[:notice]=_('Tariff_was_not_found')
        redirect_to :action => :list and return false
      end
      @tariff_from.users.each do |user|
        user.tariff = @tariff_to
        user.save
      end
      flash[:status] = _('Updated_tariff_for_users')
    else
      flash[:notice] = _('Tariff_not_found')
    end
    redirect_to :action => 'list'
  end


  #----------------- PDF/CSV export

  # before_filter : tariff(find_tariff_whith_currency)
  def generate_providers_rates_csv
    a = check_user_for_tariff(@tariff)
    return false if !a

    filename = "Rates-#{session[:show_currency]}.csv"
    file = @tariff.generate_providers_rates_csv(session)
    testable_file_send(file, filename, 'text/csv; charset=utf-8; header=present')
  end

  # before_filter : user; tariff
  def generate_personal_wholesale_rates_csv
    filename = "Rates-#{(session[:show_currency]).to_s}.csv"
    file = @tariff.generate_providers_rates_csv(session)
    testable_file_send(file, filename, 'text/csv; charset=utf-8; header=present')
  end

  # before_filter : user; tariff
  def generate_personal_wholesale_rates_pdf
    @s_prefix = session[:user_rates_prefix] ||= ''
    prefix_cond = @s_prefix.present? ? "prefix LIKE '#{@s_prefix.to_s}'" : ''

    rates = Rate.includes({:destination => :direction}).where(['rates.tariff_id = ?', @tariff.id]).where(prefix_cond).order('directions.name ASC').all
    options = {
        :name => @tariff.name,
        :pdf_name => _('Rates'),
        :currency => session[:show_currency]
    }
    pdf = PdfGen::Generate.generate_rates_header(options)
    pdf = PdfGen::Generate.generate_personal_wholesale_rates_pdf(pdf, rates, @tariff, options)
    file = pdf.render
    filename = "Rates-#{(session[:show_currency]).to_s}.pdf"
    testable_file_send(file, filename, "application/pdf")
  end

  # before_filter : tariff(find_tariff_whith_currency)
  def generate_user_rates_pdf
    rates = Rate.joins('LEFT JOIN destinationgroups on (destinationgroups.id = rates.destinationgroup_id)').where(['rates.tariff_id = ?', @tariff.id]).order('destinationgroups.name, destinationgroups.desttype ASC').all
    options = {
        :name => @tariff.name,
        :pdf_name => _('Users_rates'),
        :currency => session[:show_currency]
    }
    pdf = PdfGen::Generate.generate_rates_header(options)
    pdf = PdfGen::Generate.generate_user_rates_pdf(pdf, rates, @tariff, options)
    file = pdf.render
    filename = "Rates-#{session[:show_currency]}.pdf"
    testable_file_send(file, filename, "application/pdf")
  end

  # before_filter : tariff(find_tariff_whith_currency)
  def generate_user_rates_csv
    filename = "Rates-#{session[:show_currency]}.csv"
    file = @tariff.generate_user_rates_csv(session)
    testable_file_send(file, filename, 'text/csv; charset=utf-8; header=present')
  end

=begin
 Duplicated in Rate model for portability.
=end


  def get_personal_rate_details(tariff, dg, exrate)
    rate = dg.rate(tariff.id)

    @arates = []
    @arates = Aratedetail.where("rate_id = #{rate.id} AND artype = 'minute'").order("price DESC") if rate

    #check for custom rates
    @crates = []
    crate = Customrate.where("user_id = '#{session[:user_id]}' AND destinationgroup_id = '#{dg.id}'").first
    if crate && crate[0]
      @crates = Acustratedetail.where("customrate_id = '#{crate[0].id}'").order("price DESC")
      @arates = @crates if @crates[0]
    end
    if @arates[0]
      @arate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [@arates[0].price.to_d]}) if @arates[0]
    end
  end

  # before_filter : user; tariff
  def generate_personal_rates_pdf
    @s_prefix = session[:user_rates_prefix] ||= ''
    prefix_cond = @s_prefix.present? ? "prefix LIKE '#{@s_prefix.to_s}'" : ''
    dgroups = Destinationgroup.joins('JOIN destinations ON destinations.destinationgroup_id = destinationgroups.id')
                              .where(prefix_cond).order('name ASC, desttype ASC').all
    dgroups.uniq!
    tax = session[:tax]
    options = {
        :name => @tariff.name,
        :pdf_name => _('Personal_rates'),
        :currency => session[:show_currency]
    }
    pdf = PdfGen::Generate.generate_rates_header(options)
    pdf = PdfGen::Generate.generate_personal_rates(pdf, dgroups, @tariff, tax, @user, options)

    filename = "Rates-Personal-#{@user.username}-#{session[:show_currency]}.pdf"
    file = pdf.render
    testable_file_send(file, filename, "application/pdf")
  end

  # before_filter : user; tariff
  def generate_personal_rates_csv
    @s_prefix = session[:user_rates_prefix] ||= ''
    prefix_cond = @s_prefix.present? ? "prefix LIKE '#{@s_prefix.to_s}'" : ''
    dgroups = Destinationgroup.joins('JOIN destinations ON destinations.destinationgroup_id = destinationgroups.id')
                              .where(prefix_cond).order('name ASC, desttype ASC').all
    dgroups.uniq!
    tax = session[:tax]

    sep = Confline.get_value("CSV_Separator").to_s
    dec = Confline.get_value("CSV_Decimal").to_s

    #csv_string = "Name,Type,Rate,Rate_with_VAT(#{vat}%)\n"
    csv_string = _("Name")+sep+_("Type")+sep+_("Rate")+sep+_("Rate_with_VAT")+"\n"

    exrate = Currency.count_exchange_rate(@tariff.currency, session[:show_currency])

    for dg in dgroups
      get_personal_rate_details(@tariff, dg, exrate)

      if @arates.size > 0
        csv_string += "#{dg.name.to_s.gsub(sep, " ")}#{sep}#{dg.desttype}#{sep}"
        csv_string += @arate_cur ? "#{nice_number(@arate_cur).to_s.gsub(".", dec)}#{sep}#{nice_number(tax.count_tax_amount(@arate_cur) + @arate_cur).to_s.gsub(".", dec)}\n" : "0#{sep}0\n"
      end
    end

    filename = "Rates-Personal-#{@user.username}-#{session[:show_currency]}.csv"
    testable_file_send(csv_string, filename, 'text/csv; charset=utf-8; header=present')
  end

  def analysis
    @page_title = _('Tariff_analysis')
    @page_icon = "table_gear.png"

    @prov_tariffs = Tariff.where("purpose = 'provider'").order("name ASC")
    @user_wholesale_tariffs = Tariff.where("purpose = 'user_wholesale'").order("name ASC")
    @currs = Currency.get_active
  end


  def analysis2
    @page_title = _('Tariff_analysis')
    @page_icon = "table_gear.png"

    @prov_tariffs_temp = Tariff.where("purpose = 'provider'").order("name ASC").all
    #@user_tariffs_temp = Tariff.find(:all, :conditions => "purpose = 'user'", :order => "name ASC")
    @user_wholesale_tariffs_temp = Tariff.where("purpose = 'user_wholesale'").order("name ASC").all

    @prov_tariffs = []
    #@user_tariffs = []
    @user_wholesale_tariffs = []
    @all_tariffs = []

    @prov_tariffs_temp.each do |provider_tariff|
      tariff_id = provider_tariff.id
      @prov_tariffs << provider_tariff if params["t#{tariff_id}".intern] == '1'
      @all_tariffs << tariff_id if params["t#{tariff_id}".intern] == '1'
    end

    #for t in @user_tariffs_temp
    #  @user_tariffs << t if params[("t" + t.id.to_s).intern] == "1"
    #  @all_tariffs << t.id if params[("t" + t.id.to_s).intern] == "1"
    #end

    @user_wholesale_tariffs_temp.each do |wholesale_tariff|
      tariff_id = wholesale_tariff.id
      @user_wholesale_tariffs << wholesale_tariff if params["t#{tariff_id}".intern] == '1'
      @all_tariffs << tariff_id if params["t#{tariff_id}".intern] == '1'
    end

    @curr = params[:currency]

    @tariff_line = ''
    @all_tariffs.each do |tariff|
      @tariff_line << "#{tariff}|"
    end
  end


  def generate_analysis_csv

    cs = confline("CSV_Separator")
    dec = confline("CSV_Decimal")

    curr = params[:curr]
    all_tariffs = params[:tariffs].split('|')

    #my_debug "t----"
    #my_debug params[:tariffs]

    exch_rates = []
    tariff_names = []
    tariff_rates = []

    #header

    csv_string = _("Currency")+": #{curr}#{cs}#{cs}#{cs}#{cs}".gsub(cs, " ")

    for t in all_tariffs
      tariff = Tariff.find(t)
      tariff_names << tariff.name
      er = count_exchange_rate(curr, tariff.currency)
      exch_rates << er.to_d
      if tariff.rates
        tariff_rates << tariff.rates.size
      else
        tariff_rates << 0
      end
      csv_string += "(#{curr}/#{tariff.currency}): ".gsub(cs, " ")
      csv_string += er.to_s.gsub(".", dec) if er
      csv_string += cs
    end
    csv_string += "\n"

    #my_debug tariff_names

    #csv_string += "direction#{cs}destinations#{cs}subcode#{cs}prefix#{cs}"
    csv_string += _("Direction")+cs+_("Destinations")+cs+_("Subcode")+cs+_("Prefix")

    for t in all_tariffs
      csv_string += Tariff.find(t).name.gsub(cs, " ")
      csv_string += (" (" + t.to_s.gsub(".", dec) + ")#{cs}")
    end

    csv_string += cs
    #csv_string += "Min#{cs}Min Provider#{cs}Max#{cs}Max Provider"
    csv_string += _("Min")+cs+_("Min_provider")+cs+_("Max")+cs+_("Max_provider")
    csv_string += "\n"


    # data

    res = []
    prefixes = []
    directions = []
    subcodes = []
    destinations = []

    min_rates = []
    max_rates = []

    i = 0
    for t in all_tariffs

      min_rates[i] = 0
      max_rates[i] = 0

      res[i] = []
      tariff = Tariff.find(t)

      sql = "SELECT directions.name, destinations.name as 'dname', destinations.subcode, destinations.prefix, ratedetails.rate FROM destinations JOIN directions ON (directions.code = destinations.direction_code) LEFT JOIN  rates ON (destinations.id = rates.destination_id AND rates.tariff_id = '#{tariff.id}')  	LEFT JOIN ratedetails ON (ratedetails.rate_id = rates.id) ORDER BY directions.name ASC, destinations.subcode ASC, destinations.prefix ASC;"
      sqlres = ActiveRecord::Base.connection.select_all(sql)

      j = 0
      for sr in sqlres
        res[i][j] = sr['rate']
        prefixes[j] = sr['prefix']
        directions[j] = sr['name']
        subcodes[j] = sr['subcode']
        destinations[j] = sr['dname']

        j += 1
      end

      i += 1
    end


    i = 0
    for rr in 0..res[0].size - 1

      min = nil
      minp = nil
      max = nil
      maxp = nil

      csv_string += directions[i].to_s.gsub(cs, " ") if directions[i]
      csv_string += cs

      csv_string += destinations[i].to_s.gsub(cs, " ") if destinations[i]
      csv_string += cs

      csv_string += subcodes[i] if subcodes[i]
      csv_string += cs

      csv_string += prefixes[i] if prefixes[i]
      csv_string += cs

      j = 0
      for r in res

        rate = nil
        rate = r[i].to_d / exch_rates[j] if r[i] and exch_rates[j]


        if rate and ((min == nil) or (min.to_d > rate.to_d))
          min = rate
          minp = j
        end

        if rate and ((max == nil) or (max.to_d < rate.to_d))
          max = rate
          maxp = j
        end

        #          my_debug "j: #{j}, maxp: #{maxp}"

        csv_string += nice_number(rate).to_s.gsub(".", dec)
        csv_string += cs
        j += 1
      end


      csv_string += cs
      if not min
        min = ""
        minpt = ""
      else
        if minp
          minpt = tariff_names[minp]
          min_rates[minp] += 1
        end
      end

      if not max
        max = ""
        maxpt = ""
      else
        if maxp
          maxpt = tariff_names[maxp]
          max_rates[maxp] += 1
        end
      end

      csv_string += "#{cs}#{min.to_s.gsub(".", dec)}#{cs}#{minpt.to_s.gsub(cs, " ")}#{cs}#{max.to_s.gsub(".", dec)}#{cs}#{maxpt.to_s.gsub(cs, " ")}"

      csv_string += "\n"
      i += 1
    end

    csv_string += "\n"
    csv_string += "#{cs}#{cs}#{cs}#{cs}"

    all_tariffs.each do |tariff|
      csv_string += Tariff.find(tariff).name
      csv_string += (" (" + tariff.to_s + ")#{cs}")
    end

    csv_string += "\n"
    csv_string += "#{cs}#{cs}#{cs}Total rates: #{cs}"

    all_tariffs.each_with_index do |tariff, index|
      csv_string += ("#{tariff_rates[index]}#{cs}")
    end

    csv_string += "\n"
    csv_string += "#{cs}#{cs}#{cs}Min rates: #{cs}"

    all_tariffs.each_with_index do |tariff, index|
      csv_string += ("#{min_rates[index]}#{cs}")
    end

    csv_string += "\n"
    csv_string += "#{cs}#{cs}#{cs}Max rates: #{cs}"

    all_tariffs.each_with_index do |tariff, index|
      csv_string += ("#{max_rates[index]}#{cs}")
    end

    filename = 'Tariff_analysis.csv'
    testable_file_send(csv_string, filename, 'text/csv; charset=utf-8; header=present')
  end

  def destinations_csv
    sql = "SELECT prefix, directions.name AS 'dir_name', subcode, destinations.name AS 'dest_name'  FROM destinations JOIN directions ON (destinations.direction_code = directions.code) ORDER BY directions.name, prefix ASC;"
    res = ActiveRecord::Base.connection.select_all(sql)
    cs = confline("CSV_Separator", correct_owner_id)
    cs = "," if cs.blank?
    csv_line = res.map { |r| "#{r["prefix"]}#{cs}#{r["dir_name"].to_s.gsub(cs, " ")}#{cs}#{r["subcode"].to_s.gsub(cs, " ")}#{cs}#{r["dest_name"].to_s.gsub(cs, " ")}" }.join("\n")
    if params[:test].to_i == 1
      render :text => csv_line
    else
      send_data(csv_line, :type => 'text/csv; charset=utf-8; header=present', :filename => "Destinations.csv")
    end
  end

  def check_tariff_time
    a=check_user_for_tariff(@tariff.id)
    return false if !a
    session[:imp_date_day_type] = params[:rate_day_type].to_s

    @f_h, @f_m, @f_s, @t_h, @t_m, @t_s = params[:time_from_hour].to_s, params[:time_from_minute].to_s, params[:time_from_second].to_s, params[:time_till_hour].to_s, params[:time_till_minute].to_s, params[:time_till_second].to_s
    @rate_type, flash[:notice_2] = @tariff.check_types_periods(params)

    #logger.info @f_h

    render(:layout => false)
  end

  private

  def check_user_for_tariff(tariff)
    if tariff.class.to_s !='Tariff'
      tariff = Tariff.where(['id = ? ', tariff]).first
    end

    owner_id = tariff.owner_id

    if session[:usertype].to_s == 'accountant'
      if owner_id != 0 or session[:acc_tariff_manage].to_i == 0
        dont_be_so_smart
        redirect_to :action => :list and return false
      end
    elsif session[:usertype].to_s == 'reseller' && owner_id != session[:user_id] && (params[:action] == 'rate_details' || params[:action] == 'rates_list'|| params[:action] == 'user_rates_list'|| params[:action] == 'user_arates_full')
      if !CommonUseProvider.find.where(['reseller_id = ? AND tariff_id = ?', current_user.id, tariff.id]).first
        dont_be_so_smart
        redirect_to :action => :list and return false
      end
    else
      if owner_id != session[:user_id]
        dont_be_so_smart
        redirect_to :action => :list and return false
      end
    end
    return true
  end

  def find_tariff_whith_currency
    @tariff = Tariff.where(['id=?', params[:id]]).first
    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to :action => :list and return false
    end

    unless @tariff.real_currency
      flash[:notice]=_('Tariff_currency_not_found')
      redirect_to :action => :list and return false
    end
  end

  def find_tariff_from_id
    @tariff = Tariff.where(['id=?', params[:id]]).first
    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to :action => :list and return false
    end
  end

  def find_user_from_session
    @user = User.includes(:tariff).where(['users.id = ?', session[:user_id]]).first
    unless @user
      flash[:notice]=_('User_was_not_found')
      redirect_to :action => :list and return false
    end
  end

  def find_user_tariff
    common_use_provider_tariff
    @tariff = @user.tariff if @tariff.blank?
    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to :action => :list and return false
    end

    unless @tariff.real_currency
      flash[:notice]=_('Tariff_currency_not_found')
      redirect_to :action => :list and return false
    end
  end

  def get_provider_rate_details(rate, exrate)
    @rate_details = Ratedetail.where(["rate_id = ?", rate.id]).order('rate DESC')
    if @rate_details.size > 0
      @rate_increment_s=@rate_details[0]['increment_s']
      @rate_cur, @rate_free = Currency.count_exchange_prices({:exrate => exrate, :prices => [@rate_details[0]['rate'].to_d, @rate_details[0]['connection_fee'].to_d]})
    end
    @rate_details
  end

  def accountant_permissions
    allow_manage = !(session[:usertype] == 'accountant'&& (session[:acc_tariff_manage].to_i == 0 or session[:acc_tariff_manage].to_i == 1))
    allow_read = !(session[:usertype] == 'accountant' && (session[:acc_tariff_manage].to_i == 0))
    return allow_manage, allow_read
  end

  def csv_import_cleanup
    if @tariff_analize && @tariff_analize[:last_step_flag] == true
      my_debug_time 'clean start'
      Tariff.clean_after_import(session["tariff_name_csv_#{@tariff.id}".to_sym])

      session[:file] = nil

      my_debug_time 'clean done'
    end
  end

  def common_use_provider_tariff(id = nil)
    @common_use_provider = nil
    provider_id = id || params[:common_use_provider]
    if provider_id.present? && reseller?
      provider = Application.common_use_provider(provider_id)
      if provider.present?
        @tariff = Tariff.where(id: provider.tariff_id).first
        @common_use_provider = provider_id
      end
    end
  end

  def generate_page_details(collection_size)
    items_per_page = session[:items_per_page]
    page_number = @page

    iend = ((items_per_page * page_number) - 1)
    iend = collection_size - 1 if iend > collection_size - 1
    items_beginning = ((page_number - 1) * items_per_page)

    return items_beginning, iend
  end
end
