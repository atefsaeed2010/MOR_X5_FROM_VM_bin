# -*- encoding : utf-8 -*-
class DestinationGroupsController < ApplicationController
  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update, :dg_add_destinations, :dg_destination_delete]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_destination, :only => [:dg_destination_delete, :dg_destination_stats]
  before_filter :save_params, :only => [:bulk_management_confirmation, :bulk_rename_confirm, :bulk, :list]
  before_filter :find_destination_group, :only => [:bulk_management_confirmation, :bulk_assign, :edit, :update, :destroy, :destinations, :dg_new_destinations, :dg_add_destinations, :dg_list_user_destinations, :stats]

  def list
    @page_title = _('Destination_groups')
    @help_link = "http://wiki.kolmisoft.com/index.php/Destinations_Groups"

    @st = "A"
    @st = params[:st].upcase if params[:st]
    @destinationgroups = Destinationgroup.where("name like ?", @st+'%').order("name ASC, desttype ASC")
    store_location
  end

  def list_json
    groups = Destinationgroup.select("id, name, desttype").order("name ASC, desttype ASC").map { |dg| [dg.id.to_s, [dg.name.to_s, dg.desttype.to_s].join(" ")] }
    render :json => ([["none", _('Not_assigned')]] + groups).to_json
  end

  def new
    @page_title = _('New_destination_group')
    @dg = Destinationgroup.new
  end

  def create
    @dg = Destinationgroup.new(params[:dg])
    if @dg.save
      flash[:status] = _('Destination_group_was_successfully_created')
      redirect_to :action => 'list', :st => @dg.name[0, 1]
    else
      flash[:notice] = _('Destination_group_was_not_created')
      redirect_to :action => 'new'
    end
  end

  def edit
    @page_title = _('Edit_destination_group')
  end

  def update
    if @dg.update_attributes(params[:dg])
      flash[:status] = _('Destination_group_was_successfully_updated')
      redirect_to :action => 'list', :st => @dg.name[0, 1]
    else
      flash[:notice] = _('Destination_group_was_not_updated')
      redirect_to :action => 'new'
    end
  end

  def destroy
    first_letter = @dg.name[0, 1]
    if @dg.destroy
      flash[:status] = _('Destination_group_deleted') + @dg.message
      redirect_to(action: 'list', st: first_letter)
    else
      @dg.errors.each { |key, value| flash[:notice] += "<br> * #{value}" }
      redirect_to(action: 'list', st: first_letter) && (return false)
    end
  end

  def destinations
    @page_title = _('Destinations')
    @destinations = @destgroup.destinations
  end

  def dg_new_destinations

    @free_dest_size = Destination.count(:all, :conditions => ['destinationgroup_id < ?', 1])

    @page_title = _('New_destinations')

    @st = params[:st].blank? ? "A" : params[:st].upcase

    @page = 1
    @page = params[:page].to_i if params[:page]
    items_per_page = session[:items_per_page]
    @free_destinations = @destgroup.free_destinations_by_st(@st)
    @total_pages = (@free_destinations.size.to_d / session[:items_per_page].to_d).ceil

    @destinations = []
    iend = ((session[:items_per_page] * @page) - 1)
    iend = (@free_destinations.size - 1) if iend > (@free_destinations.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @destinations << @free_destinations[i]
    end

    @letter_select_header_id = @destgroup.id
    @page_select_header_id = @destgroup.id
  end


  def dg_add_destinations

    @st = params[:st].upcase if params[:st]

    @free_destinations = @destgroup.free_destinations_by_st(@st)

    #my_debug @free_destinations.size

    for fd in @free_destinations
      if params[fd.prefix.intern] == "1"
        sql = "UPDATE destinations SET destinationgroup_id = '#{@destgroup.id}' WHERE id = '#{fd.id}'"
        #  INSERT INTO destgroups (destinationgroup_id, prefix) VALUES ('#{@destgroup.id}', '#{fd.prefix.to_s}')"
        res = ActiveRecord::Base.connection.update(sql)
      end
    end

    flash[:status] = _('Destinations_added')
    redirect_to :action => :destinations, :id => @destgroup.id
  end


  def dg_destination_delete
    @destgroup = Destinationgroup.where(:id => params[:dg_id]).first
    unless @destgroup
      flash[:notice]=_('Destinationgroup_was_not_found')
      redirect_to :action => :index and return false
    end
    sql = "UPDATE destinations SET destinationgroup_id = 0 WHERE id = '#{@destination.id}' "
    #    DELETE FROM destgroups WHERE destinationgroup_id = '#{@destgroup.id}' AND prefix = '#{@dest.prefix.to_s}'"
    res = ActiveRecord::Base.connection.update(sql)

    flash[:status] = _('Destination_deleted')
    redirect_to :action => :destinations, :id => @destgroup.id
  end

  #for final user

  def dg_list_user_destinations
    @page_title = _('Destinations')
    @destinations = @destgroup.destinations
    render(:layout => "layouts/mor_min")
  end


  def dest_mass_update
    @page_title = _('Destination_mass_update')
    @page_icon = "application_edit.png"

    @prefix_s = params[:prefix_s].blank? ? "%" : params[:prefix_s]
    @subcode_s = params[:subcode_s].blank? ? '%' : params[:subcode_s]
    @name_s = params[:name_s].blank? ? '%' : params[:name_s]
    @name = params[:name].blank? ? '' : params[:name]
    @subcode = params[:subcode].blank? ? '' : params[:subcode]


    if (@name != "" || @subcode != "")

      @prefix_s = session[:prefix_s]
      @subcode_s = session[:subcode_s]
      @name_s = session[:name_s]

      @destinations = Destination.where("prefix LIKE '" + @prefix_s + "' and subcode LIKE '" + @subcode_s + "' and name LIKE '" + @name_s + "'")
      for destination in @destinations
        if (@name != "" and @subcode != "")
          destination.update_attributes(:subcode => @subcode, :name => @name)
        else
          if @subcode != ""
            destination.update_attributes(:subcode => @subcode)
          else
            if (@name != "")
              destination.update_attributes(:name => @name)
            end
          end
        end
      end
      flash[:status] = _('Destinations_updated')
    end

    @destinations = Destination.where("prefix LIKE '" + @prefix_s + "' and subcode LIKE '" + @subcode_s + "' and name LIKE '" + @name_s + "'")

    session[:prefix_s] = @prefix_s
    session[:subcode_s] = @subcode_s
    session[:name_s] = @name_s
  end


  def destinations_to_dg
    @page_title = _('Destinations_without_Destination_Groups')
    @page_icon = 'wrench.png'

    @options = session[:destinations_destinations_to_dg_options] || {}
    @options[:page] = params[:page].to_i
    @options[:page] = 1 if @options[:page].to_i <= 0

    @options[:order_desc] = params[:order_desc] || @options[:order_desc] || 0
    @options[:order_by] = params[:order_by] || @options[:order_by] || 'country'

    @options[:order] = Destinationgroup.destinationgroups_order_by(params, @options)

    @total_pages = (Destination.count(:all, :conditions => "destinationgroup_id = 0").to_d/session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages.to_i if @total_pages.to_i < @options[:page].to_i && @total_pages > 0

    @destinations_without_dg = Destination.select_destination_assign_dg(@options[:page], @options[:order])
    dgs = Destinationgroup.select("id, CONCAT(name, ' ', desttype) as gname").order("name ASC, desttype ASC")
    @dgs = dgs.map { |d| [d.gname.to_s, d.id.to_s] }

    session[:destinations_destinations_to_dg_options] = @options
  end

  def destinations_to_dg_update
    @options = session[:destinations_destinations_to_dg_options]
    ds = Destination.select_destination_assign_dg(session[:destinations_destinations_to_dg_options][:page], @options[:order])
    dgs = []
    ds.each { |d| dgs << d.id.to_s }
    if dgs and dgs.size.to_i > 0
      @destinations_without_dg = Destination.where("id IN (#{dgs.join(',')})")
      counter = 0
      if @destinations_without_dg and @destinations_without_dg.size.to_i > 0
        size = @destinations_without_dg.size
        for dest in @destinations_without_dg
          if dest.update_by(params)
            dest.save
            counter += 1
          end
        end

        session[:integrity_check] = FunctionsController.integrity_recheck

        not_updated = size - counter
      end
      if not_updated == 0
        flash[:status] = _('Destinations_updated')
      else
        flash[:notice] = "#{not_updated} " + _('Destinations_not_updated')
        flash[:status] = "#{counter} " +_('Destinations_updated_successfully')
      end
    else
      flash[:notice] = _('No_Destinations')
    end

    redirect_to :action => 'destinations_to_dg' and return false
  end

  def auto_assign_warning
    @page_title = _('Destinations_Auto_assign_warning')
    @page_icon = 'exclamation.png'
  end

  def auto_assign_destinations_to_dg
    Destination.auto_assignet_to_dg
    flash[:status] = _('Destinations_assigned')
    redirect_to :controller => "functions", :action => 'integrity_check' and return false
  end

  def bulk_management_confirmation
    @page_title = _('Bulk_management')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Destinations_Groups"

    @saved[:prefix_2] = params[:prefix].to_s if @saved and params[:prefix]
    @saved[:type] = params[:type].to_s if params[:type]
    search = params[:prefix].to_s.include?('%') ? params[:prefix].to_s.delete("%") : params[:prefix].to_s + '$'
    @destinations = Destination.where(['prefix REGEXP ?', '^' + search]).includes([:destinationgroup]).order('prefix ASC').all

    if @destinations.blank?
      flash[:notice] = _('Invalid_prefix')
      redirect_to :action => :bulk, :params => params
    end
    @prefix = params[:prefix]
    @type = params[:type]
  end

  def bulk_assign
    search = params[:prefix].to_s.include?('%') ? params[:prefix].to_s.delete("%") : params[:prefix].to_s + '$'
    begin
      @destinations = Destination.where('prefix REGEXP ?', '^' + search).includes([:destinationgroup]).order('prefix ASC').all
    rescue
      flash[:notice] = _('Invalid_prefix')
      redirect_to :action => :bulk, :params => params
    end
    @prefix = params[:prefix]
    @type = params[:type]
    for d in @destinations
      d.destinationgroup = @dg
      d.subcode = q(@type) if @type and !@type.blank?
      d.save
    end
    pr = _('assigned_to')
    flash[:status] = _('Destinations') + ': ' + @destinations.size.to_s + ' ' + pr + ' - ' + @dg.name
    redirect_back_or_default('/callc/main')
  end

  #========================================= Destinations group stats ======================================================

  def stats
    @page_title = _('Destination_group_stats')
    @page_icon = "chart_bar.png"

    change_date

    destinationgroup_flag = @destinationgroup.flag
    @html_flag = destinationgroup_flag
    @html_name = @destinationgroup.name + " " + @destinationgroup.desttype
    @html_prefix_name = ""
    @html_prefix = ""

    @calls, @Calls_graph, @answered_calls, @no_answer_calls, @busy_calls, @failed_calls = Direction.get_calls_for_graph({:a1 => session_from_date, :a2 => session_till_date, :code => destinationgroup_flag})

    @sdate = Time.mktime(session[:year_from], session[:month_from], session[:day_from])

    year, month, day = last_day_month('till')
    @edate = Time.mktime(year, month, day)

    @a_date = []
    @a_calls = []
    @a_billsec = []
    @a_avg_billsec = []
    @a_calls2 = []
    @a_ars = []
    @a_ars2 = []

    @t_calls = 0
    @t_billsec = 0
    @t_avg_billsec = 0
    @t_normative = 0
    @t_norm_days = 0
    @t_avg_normative = 0

    index = 0
    while @sdate < @edate
      @a_date[index] = @sdate.strftime("%Y-%m-%d")

      @a_calls[index] = 0
      @a_billsec[index] = 0
      @a_calls2[index] = 0

      sql ="SELECT COUNT(calls.id) as \'calls\',  SUM(calls.billsec) as \'billsec\' FROM destinations, destinationgroups, calls WHERE (destinations.direction_code = destinationgroups.flag) AND (destinationgroups.flag ='#{destinationgroup_flag}' ) AND (destinations.prefix = calls.prefix) "+
          "AND calls.calldate BETWEEN '#{@a_date[index]} 00:00:00' AND '#{@a_date[index]} 23:23:59'" +
          "AND disposition = 'ANSWERED'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @a_calls[index] = res[0]["calls"].to_i
      @a_billsec[index] = res[0]["billsec"].to_i


      @a_avg_billsec[index] = 0
      @a_avg_billsec[index] = @a_billsec[index] / @a_calls[index] if @a_calls[index] > 0


      @t_calls += @a_calls[index]
      @t_billsec += @a_billsec[index]

      sqll ="SELECT COUNT(calls.id) as \'calls2\' FROM destinations, destinationgroups, calls WHERE (destinations.direction_code = destinationgroups.flag) AND (destinationgroups.flag ='#{destinationgroup_flag}' ) AND (destinations.prefix = calls.prefix) "+
          "AND calls.calldate BETWEEN '#{@a_date[index]} 00:00:00' AND '#{@a_date[index]} 23:23:59'"
      res2 = ActiveRecord::Base.connection.select_all(sqll)
      @a_calls2[index] = res2[0]["calls2"].to_i

      @a_ars2[index] = (@a_calls[index].to_d / @a_calls2[index]) * 100 if @a_calls[index] > 0
      @a_ars[index] = nice_number @a_ars2[index]


      @sdate += (60 * 60 * 24)
      index+=1
    end

    @t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0

    format_graphs(index)
  end

  #========================================= Dg destination stats ======================================================

  def dg_destination_stats
    @page_title = _('Dg_destination_stats')
    @page_icon = "chart_bar.png"
    @destinationgroup = Destinationgroup.where(:id => params[:dg_id]).first
    unless @destinationgroup
      flash[:notice]=_('Destinationgroup_was_not_found')
      redirect_to :action => :index and return false
    end

    change_date
    destinationgroup_flag = @destinationgroup.flag
    @dest = @destination
    @html_flag = destinationgroup_flag
    @html_name = @destinationgroup.name + " " + @destinationgroup.desttype
    @html_prefix_name = _('Prefix') + " : "
    @html_prefix = @dest.prefix

    @calls, @Calls_graph, @answered_calls, @no_answer_calls, @busy_calls, @failed_calls = Direction.get_calls_for_graph({:a1 => session_from_date, :a2 => session_till_date, :destination => @html_prefix, :code => destinationgroup_flag})

    @sdate = Time.mktime(session[:year_from], session[:month_from], session[:day_from])

    year, month, day = last_day_month('till')
    @edate = Time.mktime(year, month, day)

    @a_date = []
    @a_calls = []
    @a_billsec = []
    @a_avg_billsec = []
    @a_calls2 = []
    @a_ars = []
    @a_ars2 = []

    @t_calls = 0
    @t_billsec = 0
    @t_avg_billsec = 0
    @t_normative = 0
    @t_norm_days = 0
    @t_avg_normative = 0

    index = 0
    while @sdate < @edate
      @a_date[index] = @sdate.strftime("%Y-%m-%d")

      @a_calls[index] = 0
      @a_billsec[index] = 0
      @a_calls2[index] = 0

      sql ="SELECT COUNT(calls.id) as \'calls\',  SUM(calls.billsec) as \'billsec\' FROM destinations, destinationgroups, calls WHERE (destinations.direction_code = destinationgroups.flag) AND (destinationgroups.flag ='#{destinationgroup_flag}' ) AND (destinations.prefix = '#{@html_prefix}') AND (destinations.prefix = calls.prefix) "+
          "AND calls.calldate BETWEEN '#{@a_date[index]} 00:00:00' AND '#{@a_date[index]} 23:23:59'" +
          "AND disposition = 'ANSWERED'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @a_calls[index] = res[0]["calls"].to_i
      @a_billsec[index] = res[0]["billsec"].to_i


      @a_avg_billsec[index] = 0
      @a_avg_billsec[index] = @a_billsec[index] / @a_calls[index] if @a_calls[index] > 0


      @t_calls += @a_calls[index]
      @t_billsec += @a_billsec[index]

      sqll ="SELECT COUNT(calls.id) as \'calls2\' FROM destinations, destinationgroups, calls WHERE (destinations.direction_code = destinationgroups.flag) AND (destinationgroups.flag ='#{destinationgroup_flag}' ) AND (destinations.prefix = '#{@html_prefix}') AND (destinations.prefix = calls.prefix) "+
          "AND calls.calldate BETWEEN '#{@a_date[index]} 00:00:00' AND '#{@a_date[index]} 23:23:59'"
      res2 = ActiveRecord::Base.connection.select_all(sqll)
      @a_calls2[index] = res2[0]["calls2"].to_i

      @a_ars2[index] = (@a_calls[index].to_d / @a_calls2[index]) * 100 if @a_calls[index] > 0
      @a_ars[index] = nice_number @a_ars2[index]


      @sdate += (60 * 60 * 24)
      index+=1
    end

    @t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0

    # Tariff and rate

    @rate = Rate.where(["destination_id=?", @dest.id])

    @rate_details = []
    @rate1 = []
    @rate2 = []
    for rat in @rate
      rat_id = rat.id
      rat_tariff = rat.tariff
      unless rat_tariff.nil?
        if rat.tariff.purpose == "provider"
          @rate1[rat_id]=rat_tariff.name
          @rate_details[rat_id] = Ratedetail.where(["rate_id=?", rat_id]).first
        elsif rat.tariff.purpose == "user_wholesale"
          @rate2[rat_id]=rat_tariff.name
          @rate_details[rat_id] = Ratedetail.where(["rate_id=?", rat_id]).first
        end
      end
    end

    #===== Graph =====================

    format_graphs(index)
  end

=begin
  If at least one destination found redirect to confirmation page, else
  redirect back to /destination_groups/list and inform user that nothing was found
=end
  def bulk_rename_confirm
  @page_title = _('Bulk_management')
  @page_icon = "edit.png"
  @help_link = "http://wiki.kolmisoft.com/index.php/Destinations_Groups"

  @prefix = params[:prefix]
	@saved[:prefix_1] = params[:prefix].to_s if params[:prefix]
	@saved[:type] = params[:type].to_s if params[:type]
    begin
      @destinations = Destination.dst_by_prefix(@prefix)
    rescue
      flash[:notice] = _('Invalid_prefix')
      redirect_to :action => :bulk, :params => params
    end
    if @destinations.size > 0
      @destination_count = @destinations.size
      @destination_name = params[:destination]
    else
      flash[:notice] = _('No_destinations_found')
      redirect_to :action => :bulk, :params => params
    end
  end

=begin
  Update destination names by prefix that matches supplied pattern
  redirect back to /destination_groups/list and inform user that nothing was found
=end
  def bulk_rename
    Destination.rename_by_prefix(params[:destination], params[:prefix])
    flash[:status] = _('Destinations_were_renamed')
    redirect_to :action => :bulk, :params => params
  end

  def bulk
    @page_title = _('Bulk_management')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Destinations_Groups"

    if @saved and params[:type] and params[:prefix]
      @saved[:prefix_2] = params[:prefix].to_s
    elsif params[:prefix]
      @saved[:prefix_1] = params[:prefix].to_s
    end
  end

  private

  def format_graphs(index)
    ine=0
    @Calls_graph2 =""
    @Avg_Calltime_graph =""
    @Asr_graph =""
    while ine <= index
      -1
      @Calls_graph2 +=@a_date[ine].to_s + ";" + @a_calls[ine].to_s + "\\n"
      @Avg_Calltime_graph +=@a_date[ine].to_s + ";" + @a_avg_billsec[ine].to_s + "\\n"
      @Asr_graph +=@a_date[ine].to_s + ";" + @a_ars[ine].to_s + "\\n"
      ine +=1
    end

    #formating graph for Calltime

    i=0
    @Calltime_graph =""
    for i in 0..@a_billsec.size-1
      @Calltime_graph +=@a_date[i].to_s + ";" + (@a_billsec[i] / 60).to_s + "\\n"
    end

  end

  def find_destination_group
    @dg = Destinationgroup.where(['id=?', params[:id]]).first
    @page_title = _('Bulk_management')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Destinations_Groups"
    unless @dg
      flash[:notice]=_('Destinationgroup_was_not_found')
      redirect_to :action => :bulk, :params => params
    end
    @destgroup = @dg
    @destinationgroup = @dg
  end

  def find_destination
    @destination=Destination.where(['id=?', params[:id]]).first
    unless @destination
      flash[:notice]=_('Destination_was_not_found')
      render :controller => :directions, :action => :bulk  and return false
    end
    @dest = @destination
  end


  def save_params
    @saved = {
        prefix_1: '',
        prefix_2: '',
        type:'FIX',
        destination: ''
    }

    @saved[:destination] = params[:destination].to_s if params[:destination]
    @saved[:type] = params[:type].to_s if params[:type]
  end

end