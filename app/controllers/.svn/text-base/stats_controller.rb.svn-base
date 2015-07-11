# -*- encoding : utf-8 -*-
class StatsController < ApplicationController
  include PdfGen
  include SqlExport
  require 'uri'
  require 'net/http'
  require 'pdf_gen/prawn'

  layout "callc"

  before_filter :check_localization
  before_filter :authorize, :except => [:active_calls_longer_error, :active_calls_longer_error_send_email]
  before_filter :access_denied, :only => [:active_calls_graph, :server_load], :if => lambda { not admin? }
  before_filter :check_if_can_see_finances, :only => [:profit]
  before_filter :check_authentication, :only => [:active_calls, :active_calls_count, :active_calls_order, :active_calls_show]
  before_filter :load_ok?, :only => [:show_user_stats, :active_calls, :calls_by_scr, :calls_per_day, :all_users_detailed, :last_calls_stats, :load_stats, :loss_making_calls, :old_calls_stats, :users_finances, :profit, :country_stats, :dids, :dids_usage, :faxes, :first_activity, :hangup_cause_codes_stats, :providers, :subscriptions_stats, :system_stats, :action_log, :google_maps]
  before_filter :find_user_from_id_or_session, :only => [:reseller_all_user_stats, :call_list, :index, :user_stats, :call_list_to_csv, :call_list_from_link, :new_calls_list, :user_logins, :call_list_to_pdf]
  before_filter :find_provider, :only => [:providers_calls]
  before_filter :check_reseller_in_providers, :only => [:providers, :providers_stats, :country_stats]
  before_filter :no_cache, :only => [:active_calls]
  before_filter :no_users, :only => [:old_calls_stats]
  before_filter :strip_params, :only => [:last_calls_stats, :old_calls_stats]
  before_filter :lambda_round_seconds, :only => [:active_calls_graph, :update_active_calls_graph]
  before_filter :check_if_searching, :only => [:last_calls_stats, :old_calls_stats, :user_stats]
  before_filter :number_separator, :only => [:server_load]
  skip_before_filter :redirect_callshop_manager, :only => [:prefix_finder_find, :prefix_finder_find_country]
  before_filter :strip_params, :only => [:active_calls_show, :last_calls_stats]
  before_filter :find_csv_separator, :only => [:country_stats]

  before_filter { |c|
    c.instance_variable_set :@allow_read, true
    c.instance_variable_set :@allow_edit, true
  }

  before_filter(:only => [:subscriptions_stats]) { |c|
    allow_read, allow_edit = c.check_read_write_permission( [:subscriptions_stats], [], {:role => "accountant", :right => :acc_manage_subscriptions_opt_1})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  def index
    redirect_to :action => :user_stats and return false
  end

  def show_user_stats
    show_user_stats_clear_search(params) if params[:clear].to_i == 1
    session[:show_user_stats_options] ? @options = session[:show_user_stats_options] : @options = {:order_by => "nice_user", :order_desc => 0, :page => 1}
    @show_currency_selector=1
    change_date
    search_from = limit_search_by_days
    @searching = params[:search_on].to_i == 1

    @page_title = _('Calls')
    @page_icon = "call.png"

    @clear_search = show_user_stats_check_searching_params(session_from_datetime, session_till_datetime)

    not_admin_acc = "users.usertype <> 'admin' AND users.usertype <> 'accountant'"

    if session[:usertype] == "accountant"
      @owner_id = "0"
    else
      @owner_id = session[:user_id].to_s
    end

    if session[:usertype] == "reseller"
      if current_user.own_providers.to_i == 0
        caller_type = ""
        provider_prices = "calls.reseller_price"
      else
        caller_type = ""
        provider_prices ="IF(providers.common_use = '0',calls.provider_price,calls.reseller_price)"
      end
    elsif session[:usertype] == "admin"
      caller_type = ""
      provider_prices = "calls.provider_price"
    else
      caller_type = "AND callertype = 'Local'"
      provider_prices = "calls.provider_price"
    end

    sql_get_all_users = "(SELECT COUNT(*) FROM users
    LEFT JOIN calls ON (calls.user_id = users.id)
    WHERE calldate BETWEEN '" + search_from + "' AND '" + session_till_datetime + "' #{caller_type}
    AND users.usertype <> 'admin' and users.usertype <> 'accountant' AND
    users.hidden = 0 AND users.owner_id = #{@owner_id}) AS all_calls"

    sql_get = "SELECT COUNT(A.users_id) as users, SUM(A.balance) as balance, SUM(A.calls) as calls, #{sql_get_all_users}, SUM(sum_duration) as sum_duration, SUM(price) as price, SUM( provider_price)as provider_price, SUM(reseller_price) as reseller_price
    FROM (SELECT users.id as 'users_id', users.balance as 'balance', B.calls as 'calls', B.sum_duration as 'sum_duration', B.price as 'price', B.provider_price as 'provider_price', B.reseller_price as 'reseller_price'
    FROM users
    LEFT JOIN (SELECT users.id as 'users_id', users.balance as 'balance', COUNT( calls.id ) AS 'calls', sum( IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) ) ) AS 'sum_duration', SUM( calls.user_price ) AS 'price', SUM( #{provider_prices}) AS 'provider_price', SUM( calls.reseller_price ) AS 'reseller_price'
    FROM users
    LEFT JOIN calls ON (calls.user_id = users.id)
    #{'LEFT JOIN providers ON calls.provider_id = providers.id ' if session[:usertype] == "reseller" and current_user.own_providers.to_i == 1}
    WHERE calldate BETWEEN '" + search_from + "' AND '" + session_till_datetime + "' #{caller_type} AND disposition = 'ANSWERED'
    GROUP BY users.id
    ORDER BY users.first_name ASC) AS B ON (users.id = B.users_id)
    WHERE users.hidden = 0 AND users.owner_id = #{@owner_id} AND users.id >= 0 AND #{not_admin_acc}) AS A"

    if @searching
    sum = ActiveRecord::Base.connection.select_all(sql_get)

    @options[:order_by] = params[:order_by] if params[:order_by]
    @options[:order_desc] = params[:order_desc].to_i if params[:order_desc]
    @options[:order_by_full] = @options[:order_by] + (@options[:order_desc] == 1 ? ' DESC' : ' ASC')

    if @options[:order_by] == 'users.first_name'
      @options[:order_by_full] += ', users.last_name' + (@options[:order_desc] == 1 ? ' DESC' : ' ASC')
    end

    @options[:order_by_full] = @options[:order_by] + (@options[:order_desc] == 1 ? ' DESC' : ' ASC')
    @options[:order] = User.users_order_by(params, @options)

    user_count = sum[0]["users"].to_i
    @options[:page] = params[:page].to_i if params[:page]
    @page = @options[:page]
    @total_pages = (user_count / session[:items_per_page].to_d).ceil
    istart = (session[:items_per_page] * (@page - 1))

    session[:usertype] == 'admin' ? price_by = "provider_price" : price_by ="reseller_price"

    sql = "SELECT #{SqlExport.nice_user_sql}, users.id, users.first_name, users.last_name, users.username, users.balance, B.calls AS 'calls', B.sum_duration as 'sum_duration', B.price as 'price', B.provider_price as 'provider_price', B.reseller_price as 'reseller_price', A.all_calls,
    IF(sum_duration/calls IS NOT NULL,sum_duration/calls , 0) AS 'acd',
    IF ((calls/all_calls)*100 IS NOT NULL,(calls/all_calls)*100, 0 ) AS 'asr',
    IF (price-#{price_by} IS NOT NULL,price-#{price_by}, 0) AS 'profit',
    IF ((price-#{price_by})/price IS  NOT NULL,(price-#{price_by})/price,0) AS'margin',
    IF (price/#{price_by} IS NOT NULL, (price/#{price_by}*100)-100, 0) as 'markup'
    FROM users
    LEFT JOIN (SELECT calls.user_id AS 'user_id', COUNT(calls.id) as 'calls', sum(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) AS 'sum_duration', SUM(calls.user_price) AS 'price', SUM( #{provider_prices}) AS 'provider_price', SUM(calls.reseller_price) AS 'reseller_price'
    FROM calls
    #{'LEFT JOIN providers ON calls.provider_id = providers.id ' if session[:usertype] == "reseller" and current_user.own_providers.to_i == 1}
    WHERE disposition = 'ANSWERED' AND calldate BETWEEN \'" + search_from + "' AND '" + session_till_datetime + "' #{caller_type}
    GROUP BY calls.user_id) AS B   ON (B.user_id = users.id)

    LEFT JOIN (SELECT calls.user_id as 'user_id', COUNT(calls.id) as 'all_calls'
    FROM calls
    WHERE calldate BETWEEN \'" + search_from + "' AND '" + session_till_datetime + "' #{caller_type}
    GROUP BY calls.user_id) AS A ON (A.user_id = users.id)
    WHERE users.hidden = 0 AND users.owner_id = '#{@owner_id}' AND users.id >= 0 AND #{not_admin_acc}
    ORDER BY #{@options[:order]}
    LIMIT #{istart},#{session[:items_per_page]};"

    res = ActiveRecord::Base.connection.select_all(sql)
    exrate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])
    @res = res

    @total_balance = 0.0
    @total_calls = 0
    @total_attempts = 0
    @total_time = 0
    @total_price = 0.0
    @total_prov = 0.0
    @curr_price = []
    @curr_prov_price = []
    @user_price = []
    @prov_price = []
    @profit = []
    @curr_balance = []
    res.each do |r|
      id = r["id"].to_i
      @rate_cur, @rate_cur2 = Currency.count_exchange_prices({:exrate => exrate, :prices => [r["price"].to_d, r["balance"].to_d]})
      @total_balance += @rate_cur2
      @total_calls += r["calls"].to_d
      @total_attempts += r["all_calls"].to_d
      @total_time += r["sum_duration"].to_d
      @total_price += @rate_cur
      @curr_price[id]=@rate_cur
      @curr_balance[id]=@rate_cur2
      @user_price[id] = r["price"].to_d

      #  if session[:usertype]=='admin'
      @prov_price[id]= r["provider_price"].to_d
      @rate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [r["provider_price"].to_d]}) if r["provider_price"]
      @curr_prov_price[id] = @rate_cur if r["provider_price"]
      @total_prov += @rate_cur.to_d
      # else
      # @prov_price[id]= r["reseller_price"].to_d
      # @rate_cur = Currency.count_exchange_prices({:exrate=>exrate, :prices=>[provider_price.to_d]}) if provider_price
      # @curr_prov_price[id] =  @rate_cur if provider_price
      # @total_prov += @rate_cur.to_d
      # end
    end

    @all_balance = Currency.count_exchange_prices({:exrate => exrate, :prices => [sum[0]["balance"].to_d]})
    @all_time = sum[0]["sum_duration"].to_i
    @all_price = Currency.count_exchange_prices({:exrate => exrate, :prices => [sum[0]["price"].to_d]})
    #if session[:usertype]=='admin'
    @all_prov_price = Currency.count_exchange_prices({:exrate => exrate, :prices => [sum[0]["provider_price"].to_d]})
    #else
    #  @all_prov_price = Currency.count_exchange_prices({:exrate=>exrate, :prices=>[sum[0]["reseller_price"].to_d]})
    #end
    @all_profit = Currency.count_exchange_prices({:exrate => exrate, :prices => [sum[0]["price"].to_d]}) - @all_prov_price.to_d
    @total_profit = @total_price.to_d - @total_prov.to_d
    @all_calls = sum[0]["calls"].to_i
    @all_attempts = sum[0]["all_calls"].to_i
    #========================
    session[:show_user_stats_options] = @options
    if request.xml_http_request?
      render :partial => "list_stats", :layout => false
    end
  end
  end

  def all_users_detailed
    @page_title = _('All_users_detailed')
    @users = User.where("hidden = 0") #, :conditions => "usertype = 'user'") #, :limit => 6)
    @help_link = "http://wiki.kolmisoft.com/index.php/Integrity_Check"
    @searching = params[:search_on].to_i == 1
    change_date

    if @searching
      session[:hour_from] = "00"
      session[:minute_from] = "00"
      session[:hour_till] = "23"
      session[:minute_till] = "59"

      @call_stats = Call.total_calls_by_direction_and_disposition(session_time_from_db, session_time_till_db)

      @o_answered_calls = 0
      @o_no_answer_calls = 0
      @o_busy_calls = 0
      @o_failed_calls = 0
      @i_answered_calls = 0
      @i_no_answer_calls = 0
      @i_busy_calls = 0
      @i_failed_calls = 0
      @call_stats.each do |stats|
        direction = stats['direction'].to_s
        disposition = stats['disposition'].to_s.upcase
        total_calls = stats['total_calls'].to_i
        if  direction == 'outgoing'
          if disposition == 'ANSWERED'
            @o_answered_calls = total_calls
          elsif disposition == 'NO ANSWER'
            @o_no_answer_calls = total_calls
          elsif disposition == 'BUSY'
            @o_busy_calls = total_calls
          elsif disposition == 'FAILED'
            @o_failed_calls = total_calls
          end
        elsif direction == 'incoming'
          if disposition == 'ANSWERED'
            @i_answered_calls = total_calls
          elsif disposition == 'NO ANSWER'
            @i_no_answer_calls = total_calls
          elsif disposition == 'BUSY'
            @i_busy_calls = total_calls
          elsif disposition == 'FAILED'
            @i_failed_calls = total_calls
          end
        end
      end
      @outgoing_calls = @o_answered_calls + @o_no_answer_calls + @o_busy_calls + @o_failed_calls
      @incoming_calls = @i_answered_calls + @i_no_answer_calls + @i_busy_calls + @i_failed_calls
      @total_calls = @incoming_calls + @outgoing_calls

      sfd = session_time_from_db
      std = session_time_till_db

      @outgoing_perc = 0
      @outgoing_perc = @outgoing_calls.to_d / @total_calls * 100 if @total_calls > 0
      @incoming_perc = 0
      @incoming_perc = @incoming_calls.to_d / @total_calls * 100 if @total_calls > 0

      @o_answered_perc = 0
      @o_answered_perc = @o_answered_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
      @o_no_answer_perc = 0
      @o_no_answer_perc = @o_no_answer_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
      @o_busy_perc = 0
      @o_busy_perc = @o_busy_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
      @o_failed_perc = 0
      @o_failed_perc = @o_failed_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0

      @i_answered_perc = 0
      @i_answered_perc = @i_answered_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
      @i_no_answer_perc = 0
      @i_no_answer_perc = @i_no_answer_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
      @i_busy_perc = 0
      @i_busy_perc = @i_busy_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
      @i_failed_perc = 0
      @i_failed_perc = @i_failed_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0

      @t_answered_calls = @o_answered_calls + @i_answered_calls
      @t_no_answer_calls = @o_no_answer_calls + @i_no_answer_calls
      @t_busy_calls = @o_busy_calls + @i_busy_calls
      @t_failed_calls = @o_failed_calls + @i_failed_calls

      @t_answered_perc = 0
      @t_answered_perc = @t_answered_calls.to_d / @total_calls * 100 if @total_calls > 0
      @t_no_answer_perc = 0
      @t_no_answer_perc = @t_no_answer_calls.to_d / @total_calls * 100 if @total_calls > 0
      @t_busy_perc = 0
      @t_busy_perc = @t_busy_calls.to_d / @total_calls * 100 if @total_calls > 0
      @t_failed_perc = 0
      @t_failed_perc = @t_failed_calls.to_d / @total_calls * 100 if @total_calls > 0

      @a_date, @a_calls, @a_billsec, @a_avg_billsec, @total_sums = Call.answered_calls_day_by_day(session_time_from_db, session_time_till_db)

      @t_calls = @total_sums['total_calls'].to_i
      @t_billsec = @total_sums['total_billsec'].to_i
      @t_avg_billsec = @total_sums['average_billsec'].to_i

      index = @a_date.length

  #    @t_avg_billsec =  @t_billsec / @t_calls if @t_calls > 0

      #formating graph for INCOMING/OUTGOING calls

      @Out_in_calls_graph = "\""
      if @t_calls > 0
        @Out_in_calls_graph += _('Outgoing') + ";" +@outgoing_calls.to_s + ";" + "false" + "\\n" + _('Incoming') +";" +@incoming_calls.to_s + ";" + "false" + "\\n\""
      else
        @Out_in_calls_graph = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
      end

      #formating graph for Call-type calls

      @Out_in_calls_graph2 = "\""
      if @t_calls > 0

        @Out_in_calls_graph2 += _('ANSWERED') +";" +@t_answered_calls.to_s + ";" + "false" + "\\n"
        @Out_in_calls_graph2 += _('NO_ANSWER') +";" +@t_no_answer_calls.to_s + ";" + "false" + "\\n"
        @Out_in_calls_graph2 += _('BUSY') +";" +@t_busy_calls.to_s + ";" + "false" + "\\n"
        @Out_in_calls_graph2 += _('FAILED') +";" +@t_failed_calls.to_s + ";" + "false" + "\\n"

        @Out_in_calls_graph2 += "\""
      else
        @Out_in_calls_graph2 = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
      end

      #formating graph for Calls

      @Calls_graph =""
      (0..@a_calls.size-1).each do |i|
        @Calls_graph += @a_date[i].to_s + ";" + @a_calls[i].to_i.to_s + "\\n"
      end
      #formating graph for Calltime

      @Calltime_graph =""
      (0..@a_billsec.size-1).each do |i|
        @Calltime_graph += @a_date[i].to_s + ";" + (@a_billsec[i].to_i / 60).to_s + "\\n"
      end

      #formating graph for Avg.Calltime
      @Avg_Calltime_graph =""
      (0..@a_avg_billsec.size-1).each do |i|
        @Avg_Calltime_graph += @a_date[i].to_s + ";" + @a_avg_billsec[i].to_i.to_s + "\\n"
      end
    end
  end

#in before filter : user (:find_user_from_id_or_session, :authorize_user)
  def reseller_all_user_stats

    unless session[:usertype] == 'reseller'
      dont_be_so_smart
      redirect_to :root and return false
    end

    @users = User.find_all_for_select(corrected_user_id, {:exclude_owner => true})
    @users << @user
    change_date
    search_from = limit_search_by_days

    @page_title = _('Detailed_stats_for')+" "+@user.first_name+" "+@user.last_name

    #    @todays_normative = @user.normative_perc(Time.now)
    #    @months_normative = @user.months_normative(Time.now.strftime("%Y-%m"))

    ############

    session[:hour_from] = "00"
    session[:minute_from] = "00"
    session[:hour_till] = "23"
    session[:minute_till] = "59"

    year, month, day = last_day_month('till')
    @edate = Time.mktime(year, month, day)


    @a_date = []
    @a_calls = []
    @a_billsec = []
    @a_avg_billsec = []
    @a_normative = []

    @t_calls = 0
    @t_billsec = 0
    @t_avg_billsec = 0
    @t_normative = 0
    @t_norm_days = 0
    @t_avg_normative = 0

    #@new_calls_today =0

    @i_answered_calls=0
    @i_busy_calls=0
    @i_failed_calls=0
    @i_no_answer_calls=0
    @outgoing_calls=0
    @incoming_calls=0
    @total_calls=0
    @o_answered_calls=0
    @o_no_answer_calls=0
    @o_busy_calls=0
    @o_failed_calls = 0

    i = 0

    @users.each do |user|
      #@new_calls_today += user.new_calls(Time.now.strftime("%Y-%m-%d")).size
      @outgoing_calls += user.total_calls("outgoing", search_from, session_till_datetime)
      @incoming_calls += user.total_calls("incoming", search_from, session_till_datetime)
      @total_calls += user.total_calls("all", search_from, session_till_datetime)

      @o_answered_calls += user.total_calls("answered_out", search_from, session_till_datetime)
      @o_no_answer_calls += user.total_calls("no_answer_out", search_from, session_till_datetime)
      @o_busy_calls += user.total_calls("busy_out", search_from, session_till_datetime)
      @o_failed_calls += user.total_calls("failed_out", search_from, session_till_datetime)

      @i_answered_calls += user.total_calls("answered_inc", search_from, session_till_datetime)
      @i_no_answer_calls += user.total_calls("no_answer_inc", search_from, session_till_datetime)
      @i_busy_calls += user.total_calls("busy_inc", search_from, session_till_datetime)
      @i_failed_calls += user.total_calls("failed_inc", search_from, session_till_datetime)

      i = 0
      @sdate = Time.mktime(session[:year_from], session[:month_from], session[:day_from])
      @edate = Time.mktime(year, month, day)

      while @sdate < @edate
        @start_date = (@sdate - Time.zone.now.utc_offset().second + Time.now.utc_offset().second).to_s(:db)
        @a_date[i] = @start_date
        unless @a_calls[i]
          @a_calls[i] = 0
          @a_billsec[i] = 0
          @a_normative[i] = 0
        end

        @end_date = (@a_date[i].to_time + 23.hour + 59.minute + 59.second).to_s(:db)
        @a_calls[i] += user.total_calls("answered_out", @a_date[i], @end_date) + @user.total_calls("answered_inc", @a_date[i], @end_date)
        @a_billsec[i] += user.total_billsec("answered_out", @a_date[i], @end_date) + @user.total_duration("answered_inc", @a_date[i], @end_date)
        @a_normative[i] += user.normative_perc(@start_date).to_i
        @sdate += (60 * 60 * 24)
        i+=1
      end
    end

    @a_calls.each_with_index do |calls, index|
      @a_avg_billsec[index] = @a_billsec[index] / @a_calls[index] if @a_calls[index] > 0
      @t_calls += @a_calls[index]
      @t_billsec += @a_billsec[index]
      @t_normative += @a_normative[index]
      @t_norm_days += 1 if @a_normative[index] > 0
    end

    @outgoing_perc = 0
    @outgoing_perc = @outgoing_calls.to_d / @total_calls * 100 if @total_calls > 0
    @incoming_perc = 0
    @incoming_perc = @incoming_calls.to_d / @total_calls * 100 if @total_calls > 0

    @o_answered_perc = 0
    @o_answered_perc = @o_answered_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
    @o_no_answer_perc = 0
    @o_no_answer_perc = @o_no_answer_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
    @o_busy_perc = 0
    @o_busy_perc = @o_busy_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
    @o_failed_perc = 0
    @o_failed_perc = @o_failed_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0

    @i_answered_perc = 0
    @i_answered_perc = @i_answered_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
    @i_no_answer_perc = 0
    @i_no_answer_perc = @i_no_answer_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
    @i_busy_perc = 0
    @i_busy_perc = @i_busy_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
    @i_failed_perc = 0
    @i_failed_perc = @i_failed_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0


    @t_answered_calls = @o_answered_calls + @i_answered_calls
    @t_no_answer_calls = @o_no_answer_calls + @i_no_answer_calls
    @t_busy_calls = @o_busy_calls + @i_busy_calls
    @t_failed_calls = @o_failed_calls + @i_failed_calls

    @t_answered_perc = 0
    @t_answered_perc = @t_answered_calls.to_d / @total_calls * 100 if @total_calls > 0
    @t_no_answer_perc = 0
    @t_no_answer_perc = @t_no_answer_calls.to_d / @total_calls * 100 if @total_calls > 0
    @t_busy_perc = 0
    @t_busy_perc = @t_busy_calls.to_d / @total_calls * 100 if @total_calls > 0
    @t_failed_perc = 0
    @t_failed_perc = @t_failed_calls.to_d / @total_calls * 100 if @total_calls > 0

    @t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0
    @t_avg_normative = @t_normative / @t_norm_days if @t_norm_days > 0

    #formating graph for INCOMING/OUTGING calls

    @Out_in_calls_graph = "\""
    if @t_calls > 0
      @Out_in_calls_graph += _('Outgoing') + ";" +@outgoing_calls.to_s + ";" + "false" + "\\n" + _('Incoming') +";" +@incoming_calls.to_s + ";" + "true" + "\\n\""
    else
      @Out_in_calls_graph = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
    end

    #formating graph for INCOMING/OUTGING calls

    @Out_in_calls_graph2 = "\""
    if @t_calls > 0
      @Out_in_calls_graph2 += _('ANSWERED') +";" +@t_answered_calls.to_s + ";" + "false" + "\\n" + _('NO_ANSWER') +";" +@t_no_answer_calls.to_s + ";" + "true" + "\\n" + _('BUSY') +";" +@t_busy_calls.to_s + ";" + "false" + "\\n" + _('FAILED') +";" +@t_failed_calls.to_s + ";" + "false" +"\\n\""
    else
      @Out_in_calls_graph2 = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
    end

    #formating graph for Calls
    #formating graph for Avg.Calltime

    index = i

    @Calls_graph =""
    @Avg_Calltime_graph =""

    (0..index-1).each do |i|
      nice_a_date = nice_date(@a_date[i].to_s)
      @Calls_graph += nice_a_date + ";" + @a_calls[i].to_s + "\\n"
      @Avg_Calltime_graph += nice_a_date + ";" + @a_avg_billsec[i].to_s + "\\n"
    end

    #formating graph for Calltime

    @Calltime_graph =""
    (0..@a_billsec.size-1).each do |i|
      @Calltime_graph += nice_date(@a_date[i].to_s) + ";" + (@a_billsec[i] / 60).to_s + "\\n"
    end
  end

# in before filter : user (:find_user_from_id_or_session, :authorize_user)
  def user_stats
    change_date

    @page_title = "#{_('Detailed_stats_for')} #{nice_user(@user)}"

    session[:hour_from] = "00"
    session[:minute_from] = "00"
    session[:hour_till] = "23"
    session[:minute_till] = "59"

    if @searching
      @hide_non_answered_calls_for_user = (@user.usertype == 'user' and
                                           @user.hide_non_answered_calls.to_i == 1)
      @todays_normative = @user.normative_perc(Time.now)
      @months_normative = @user.months_normative(Time.now.strftime("%Y-%m"))
      @new_calls_today = @user.new_calls(Time.now.strftime("%Y-%m-%d")).size

      call_stats = Call.total_calls_by_direction_and_disposition(limit_search_by_days, session_till_datetime, [@user.id])

      @o_answered_calls = 0
      @o_no_answer_calls = 0
      @o_busy_calls = 0
      @o_failed_calls = 0
      @i_answered_calls = 0
      @i_no_answer_calls = 0
      @i_busy_calls = 0
      @i_failed_calls = 0
      call_stats.each do |stats|
        direction = stats['direction'].to_s
        disposition = stats['disposition'].to_s.upcase
        total_calls = stats['total_calls'].to_i
        if  direction == 'outgoing'
          if disposition == 'ANSWERED'
            @o_answered_calls = total_calls
          elsif disposition == 'NO ANSWER'
            @o_no_answer_calls = total_calls
          elsif disposition == 'BUSY'
            @o_busy_calls = total_calls
          elsif disposition == 'FAILED'
            @o_failed_calls = total_calls
          end
        end
        if  direction == 'incoming'
          if disposition == 'ANSWERED'
            @i_answered_calls = total_calls
          elsif disposition == 'NO ANSWER'
            @i_no_answer_calls = total_calls
          elsif disposition == 'BUSY'
            @i_busy_calls = total_calls
          elsif disposition == 'FAILED'
            @i_failed_calls = total_calls
          end
        end
      end
      @outgoing_calls = @o_answered_calls + @o_no_answer_calls + @o_busy_calls + @o_failed_calls
      @incoming_calls = @i_answered_calls + @i_no_answer_calls + @i_busy_calls + @i_failed_calls
      @total_calls = @incoming_calls + @outgoing_calls

      @o_answered_perc = 0
      @o_answered_perc = @o_answered_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
      @o_no_answer_perc = 0
      @o_no_answer_perc = @o_no_answer_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
      @o_busy_perc = 0
      @o_busy_perc = @o_busy_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
      @o_failed_perc = 0
      @o_failed_perc = @o_failed_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0

      @i_answered_perc = 0
      @i_answered_perc = @i_answered_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
      @i_no_answer_perc = 0
      @i_no_answer_perc = @i_no_answer_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
      @i_busy_perc = 0
      @i_busy_perc = @i_busy_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
      @i_failed_perc = 0
      @i_failed_perc = @i_failed_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0

      @t_answered_calls = @o_answered_calls + @i_answered_calls
      @t_no_answer_calls = @o_no_answer_calls + @i_no_answer_calls
      @t_busy_calls = @o_busy_calls + @i_busy_calls
      @t_failed_calls = @o_failed_calls + @i_failed_calls

      @t_answered_perc = 0
      @t_answered_perc = @t_answered_calls.to_d / @total_calls * 100 if @total_calls > 0
      @t_no_answer_perc = 0
      @t_no_answer_perc = @t_no_answer_calls.to_d / @total_calls * 100 if @total_calls > 0
      @t_busy_perc = 0
      @t_busy_perc = @t_busy_calls.to_d / @total_calls * 100 if @total_calls > 0
      @t_failed_perc = 0
      @t_failed_perc = @t_failed_calls.to_d / @total_calls * 100 if @total_calls > 0

      @outgoing_perc = 0
      @outgoing_perc = @outgoing_calls.to_d / @total_calls * 100 if @total_calls > 0
      @incoming_perc = 0
      @incoming_perc = @incoming_calls.to_d / @total_calls * 100 if @total_calls > 0

      ############

      @sdate = Time.mktime(session[:year_from], session[:month_from], session[:day_from])

      year, month, day = last_day_month('till')
      @edate = Time.mktime(year, month, day)

      @a_date = []
      @a_calls = []
      @a_billsec = []
      @a_avg_billsec = []
      @a_normative = []

      @t_calls = 0
      @t_billsec = 0
      @t_avg_billsec = 0
      @t_normative = 0
      @t_norm_days = 0
      @t_avg_normative = 0

      sfd = limit_search_by_days
      std = session_till_datetime

      @total_sums = {}
      if @searching
        @a_date, @a_calls, @a_billsec, @a_avg_billsec, @total_sums = Call.answered_calls_day_by_day(sfd, std, [@user.id])
      end

      @t_calls = @total_sums['total_calls'].to_i
      @t_billsec = @total_sums['total_billsec'].to_i
      @t_avg_billsec = @total_sums['average_billsec'].to_i

      index = @a_date.length

      #@t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0
      @t_avg_normative = @t_normative / @t_norm_days if @t_norm_days > 0

      #formating graph for INCOMING/OUTGING calls

      @Out_in_calls_graph = "\""
      if @t_calls > 0
        @Out_in_calls_graph += _('Outgoing') + ";" +@outgoing_calls.to_s + ";" + "false" + "\\n" + _('Incoming') +";" +@incoming_calls.to_s + ";" + "true" + "\\n\""
      else
        @Out_in_calls_graph = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
      end

      #formating graph for INCOMING/OUTGING calls

      @Out_in_calls_graph2 = "\""
      if @t_calls > 0
        @Out_in_calls_graph2 += _('ANSWERED') +";" +@t_answered_calls.to_s + ";" + "false" + "\\n" + _('NO_ANSWER') +";" +@t_no_answer_calls.to_s + ";" + "true" + "\\n" + _('BUSY') +";" +@t_busy_calls.to_s + ";" + "false" + "\\n" + _('FAILED') +";" +@t_failed_calls.to_s + ";" + "false" +"\\n\""
      else
        @Out_in_calls_graph2 = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
      end

      #formating graph for Calls
      #formating graph for Calltime

      @Calls_graph =""
      @Calltime_graph =""
      @Avg_Calltime_graph =""
      (0..@a_billsec.size-1).each do |i|
        nice_a_date = nice_date(@a_date[i].to_s)
        @Calls_graph += nice_a_date + ";" + @a_calls[i].to_s + "\\n"
        @Calltime_graph += nice_a_date + ";" + (@a_billsec[i] / 60).to_s + "\\n"
        @Avg_Calltime_graph += nice_a_date + ";" + @a_avg_billsec[i].to_s + "\\n"
      end
    end
  end

# in before filter : user (:find_user_from_id_or_session, :authorize_user)
  def user_logins
    change_date
    @Login_graph =[]

    @page = 1
    @page = params[:page].to_i if params[:page]
    @page_title = _('Login_stats_for') + nice_user(@user)

    date_start = Time.mktime(session[:year_from], session[:month_from], session[:day_from])
    date_end = Time.mktime(session[:year_till], session[:month_till], session[:day_till])

    @MyDay = Struct.new("MyDay", :date, :login, :logout, :duration)
    @a = [] #day
    @b = [] #login
    @c = [] #logout
    @d = [] #duration

    #making date array
    date_end = Time.now if date_end > Time.now
    if date_start == date_end
      @a << date_start
    else
      date = date_start
      while date < (date_end + 1.day)
        @a << date
        date = date+1.day
      end
    end


    @total_pages = ((@a.size).to_d / 10.to_d).ceil
    @all_date =@a
    @a = []
    iend = ((10 * @page) - 1)
    iend = @all_date.size - 1 if iend > (@all_date.size - 1)
    for i in ((@page - 1) * 10)..iend
      @a << @all_date[i]
    end
    @page_select_header_id = @user.id


    #make state lists for every date
    d = 0

    user_id = @user.id

    @a.each do |date|
      bb = [] #login date
      cc = [] #logout date
      dd = [] # duration

      date_str = date.strftime("%Y-%m-%d")
      #let's find starting action for the day
      start_action = Action.where(["user_id = ? AND SUBSTRING(date,1,10) < ?", user_id, date_str]).order("date DESC").first
      other_actions = Action.where(["user_id = ? AND SUBSTRING(date,1,10) = ?", user_id, date_str]).order("date ASC")

      #form array for actions
      actions = []
      actions << start_action if start_action
      for oa in other_actions
        actions << oa
      end

      #compress array removing spare logins/logouts
      pa = 0 #previous action to compare
      #if actions.size > 0
      for i in 1..actions.size-1
        if actions[i].action == actions[pa].action #and actions[i] != actions.last
          actions[i] = nil
        else
          pa = i
        end
        i+=1
      end
      actions.compact!
      #build array from data
      if actions.size > 0 #fix if we do not have data
        if actions.size == 1
          #all day same state
          date_next_day = date + 1.day

          if actions[0].action == "login"
            bb << date
            cc << date_next_day - 1.second
            dd << date_next_day - date

          end

        else
          #we have some state change during day
          i = 1
          i = 0 if actions[0].action == "login"

          (actions.size/2).times do

            #login
            if actions[i].date.day == date.day
              lin = actions[i].date
            else
              lin = date
            end

            #logout
            if actions[i+1] #we have logout
              lout = actions[i+1].date
            else #no logout, login end - end of day
              lout = date+1.day-1.second
            end

            bb << lin
            cc << lout
            dd << lout - lin

            i+=2
          end
        end

      end

      @b << bb
      @c << cc
      @d << dd

      hours = Hash.new

      i=0
      12.times do
        hours[(i*8)] = (i*2).to_s
        i+=1
      end

      #hours = {0 => "0", 2=>"2", 4=>"4", 6=>"6", 8=>"8", 10=>"10",12=>"12",  14=>"14", 16=>"16", 18=>"18", 20=>"20", 22=>"22" }

      #format data array
      #for i in 0..95

      a = []
      96.times do
        a << 0
      end


      (0..bb.size-1).each do |i|
        x = (bb[i].hour * 60 + bb[i].min) / 15
        y = (cc[i].hour * 60 + cc[i].min) / 15
        for ii in x..y
          a[ii] = 1
        end
        #        my_debug x
        #        my_debug y
      end

      #formating graph for Log States whit flash
      @Login_graph[d]=""
      rr = 0
      while rr <= 96
        db= rr % 8
        as= rr/4
        if db ==0
          @Login_graph[d] += as.to_s + ";" + a[rr].to_s + "\\n"
        end
        rr=rr+1
      end

      d+=1
    end

    @days = @MyDay.new(@a, @b, @c, @d)
  end


  def new_calls
    change_date
    @page_title = _('New_calls')
    @page_icon = "call.png"
    @users = User.where("hidden = 0")
  end


=begin
in before filter : user (:find_user_from_id_or_session, :authorize_user)
=end
  def new_calls_list
    @page_title = "#{_('New_calls')}: #{nice_user(@user)} - #{session_from_date}"
    @calls = @user.new_calls(session_from_date)

    @select_date = false
    render :new_call_list
  end

=begin
in before filter : user (:find_user_from_id_or_session, :authorize_user)
=end
  def call_list_from_link

    @date_from = params[:date_from]
    @date_till = params[:date_till].to_s != 'time_now' ? params[:date_till] : Time.now.strftime("%Y-%m-%d %H:%M:%S")

    @call_type = "all"
    @call_type = params[:call_type] if params[:call_type]

    page_titles = {
      'all' => _('all_calls'),
      'answered' => _('answered_calls'),
      'answered_inc' => _('incoming_calls'),
      'missed' => _('missed_calls')
    }

    @page_title = "#{page_titles[@call_type]}: #{nice_user(@user)}"

    @calls = @user.calls(@call_type, @date_from, @date_till)

    @total_duration = 0
    @total_price = 0
    @total_billsec = 0

    @curr_rate= {}
    @curr_rate2= {}
    exrate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    @calls.each do |call|
      call_id = call.id
      @total_duration += call.duration
      if @direction == "incoming"
        call_did_price = call.did_price
        @rate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [call_did_price.to_d]}) if call_did_price
        @total_price += @rate_cur if call_did_price
        @curr_rate2[call_id]=@rate_cur
        @total_billsec += call.did_billsec
      else
        call_user_price = call.user_price
        @rate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [call_user_price.to_d]}) if call_user_price
        @total_price += @rate_cur if call_user_price
        @curr_rate[call_id]=@rate_cur
        @total_billsec += call.nice_billsec
      end
   end

    @show_destination = params[:show_dst]
    redirect_to :controller => "stats", :action => "call_list", :id => @user.id, :call_type => @call_type, :date_from_link => @date_from, :date_till_link => @date_till, :direction => "outgoing" #and return false
  end

  #in before filter : user (:find_user_from_id_or_session)
  def last_calls_stats
    @page_title = _('Last_calls')
    @page_icon = "call.png"

    @show_currency_selector=1

    change_date
    search_from = limit_search_by_days

    if session[:usertype] == "user"
      unless (@user = current_user)
        dont_be_so_smart
        redirect_to :root and return false
      end
      @hide_non_answered_calls_for_user = (@user.hide_non_answered_calls.to_i == 1)
    end

    @options = last_calls_stats_parse_params(false, @hide_non_answered_calls_for_user ? true : false)

    t = current_user.user_time(Time.now)
    year, month, day = t.year.to_s, t.month.to_s, t.day.to_s
    from = session_from_datetime_array != [year, month, day, "0", "0", "00"]
    till = session_till_datetime_array != [year, month, day, "23", "59", "59"]

    if from or till
      @options[:search_on] = 1
    end

    is_devices_for_sope_present

    if user?
      @devices, @device = last_calls_stats_user(@user, @options)
    end

    if reseller?
      @user, @devices, @device, @hgcs, @hgc, @providers, @provider, @did, @did_provider = last_calls_stats_reseller(@options)
    end

    if ["admin", "accountant"].include?(session[:usertype])
      @user, @devices, @device, @hgcs, @hgc, @did, @providers, @provider, @reseller, @resellers, @resellers_with_dids, @did_provider = last_calls_stats_admin(@options)
    end

    session[:last_calls_stats] = @options
    options = last_calls_stats_set_variables(@options, {:user => @user, :device => @device, :hgc => @hgc, :did => @did,
                                                        :current_user => current_user, :provider => @provider,
                                                        :can_see_finances => can_see_finances?, :reseller => @reseller,
                                                        :did_provider => @did_provider})
    type = 'html'
    type = 'csv' if params[:csv].to_i == 1
    type = 'pdf' if params[:pdf].to_i == 1

    case type
      when 'html'
        if @searching && @options[:s_user_id].present?
          @total_calls_stats = Call.last_calls_total_stats(options)
          @total_calls = @total_calls_stats.total_calls.to_i
          logger.debug " >> Total calls: #{@total_calls}"
          @calls = Call.last_calls(options)
          logger.debug("  >> Calls #{@calls.size}")
        else
          @total_calls_stats = []
          @total_calls = 0
          @calls = []
       	end
        @total_pages = (@total_calls/ session[:items_per_page].to_d).ceil
        options[:page] = @total_pages if options[:page].to_i > @total_pages.to_i
        options[:page] = 1 if options[:page].to_i < 1
        @show_destination = 1
        session[:last_calls_stats] = @options
      #@calls = [@calls[1]]
      when 'pdf'
        options[:column_dem] = '.'
        options[:current_user] = current_user
        calls, test_data = Call.last_calls_csv(options.merge({pdf: 1}))
        total_calls = Call.last_calls_total_stats(options)
        pdf = PdfGen::Generate.generate_last_calls_pdf(calls, total_calls, current_user, {:direction => '', :date_from => session_from_datetime, :date_till => search_from, :show_currency => session[:show_currency], :rs_active => reseller_active?, :can_see_finances => can_see_finances?})
        logger.debug("  >> Calls #{calls.size}")
        @show_destination = 1
        session[:last_calls_stats] = @options

        if params[:test].to_i == 1
          render :text => "OK"
        elsif (@user == nil) or (Confline.get_value("Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls").to_i == 0)
          send_data pdf.render, :filename => "Calls_#{session_from_datetime}-#{session_till_datetime}.pdf", :type => "application/pdf"
        else
          send_data pdf.render, :filename => "#{nice_user(@user).gsub(' ', '_')}_Calls_#{session_from_datetime}-#{session_till_datetime}.pdf", :type => "application/pdf"
        end
      when 'csv'
        options[:test] = 1 if params[:test]
        options[:collumn_separator], options[:column_dem] = current_user.csv_params
        options[:current_user] = current_user
        options[:show_full_src] = session[:show_full_src]
        options[:csv] = true
        filename, test_data = Call.last_calls_csv(options)
        filename = load_file_through_database(filename) if Confline.get_value("Load_CSV_From_Remote_Mysql").to_i == 1
        if filename
          filename = archive_file_if_size(filename, "csv", Confline.get_value("CSV_File_size").to_d)
          if (params[:test].to_i == 1) and (@user != nil) and (Confline.get_value("Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls").to_i != 0)
            render :text => ("#{nice_user(@user).gsub(' ', '_')}_" <<  filename) + test_data.to_s
          elsif params[:test].to_i == 1
            render :text => filename + test_data.to_s
          elsif (@user == nil) or (Confline.get_value("Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls").to_i == 0)
            file = File.open(filename) if File.exist?(filename)
            send_data file.read, :filename => filename if file
          else
            file = File.open(filename)
            send_data file.read, :filename => "#{nice_user(@user).gsub(' ', '_')}_" << filename
          end
        else
          flash[:notice] = _("Cannot_Download_CSV_File_From_DB_Server")
          redirect_to :root and return false
        end
    end

    if !params[:commit].nil?
      @options[:page] = 1
    end
  end

  def old_calls_stats
    @page_title = _('Old_Calls')
    @page_icon	= "call.png"
    @help_link	= "http://wiki.kolmisoft.com/index.php/Old_calls"

    change_date

    @show_currency_selector = 1
    @options = last_calls_stats_parse_params(true)

    t = current_user.user_time(Time.now)
    from = session_from_datetime_array != [t.year.to_s, t.month.to_s, t.day.to_s, "0", "0", "00"]
    till = session_till_datetime_array != [t.year.to_s, t.month.to_s, t.day.to_s, "23", "59", "59"]

    if from or till
      @options[:search_on] = 1
    end

    is_devices_for_sope_present

    if user?
      unless (@user = current_user)
        dont_be_so_smart
        redirect_to :root and return false
      end
      @devices, @device = last_calls_stats_user(@user, @options)
    end

    if reseller?
      @user, @devices, @device, @hgcs, @hgc, @providers, @provider, @did, @did_provider = last_calls_stats_reseller(@options)
    end

    if ["admin", "accountant"].include?(session[:usertype])
      @user, @devices, @device, @hgcs, @hgc, @did, @providers, @provider, @reseller, @resellers, @resellers_with_dids, @did_provider = last_calls_stats_admin(@options)
    end

    session[:last_calls_stats] = @options
    options = last_calls_stats_set_variables(@options, {:user => @user, :device => @device, :hgc => @hgc, :did => @did, :current_user => current_user, :provider => @provider, :can_see_finances => can_see_finances?, :reseller => @reseller, :did_provider => @did_provider})

    type = 'html'
    type = 'csv' if params[:csv].to_i == 1
    #type = 'pdf' if params[:pdf].to_i == 1

    case type
      when 'html'
        if @searching && @options[:s_user_id].present?
          @total_calls_stats = OldCall.last_calls_total_stats(options)
          @total_calls = @total_calls_stats.total_calls.to_i
          logger.debug " >> Total calls: #{@total_calls}"
          @calls = OldCall.last_calls(options)
          logger.debug("  >> Calls #{@calls.size}")
        else
          @total_calls_stats = []
          @total_calls = 0
          @calls = []
        end
        @total_pages = (@total_calls/ session[:items_per_page].to_d).ceil
        options[:page] = @total_pages if options[:page].to_i > @total_pages.to_i
        options[:page] = 1 if options[:page].to_i < 1
        @show_destination = 1
        session[:last_calls_stats] = @options
      # @calls = [@calls[1]]
      # when 'pdf'
      #   options[:column_dem] = '.'
      #   options[:current_user] = current_user
      #   calls, test_data = OldCall.last_calls_csv(options.merge({:pdf => 1}))
      #   total_calls = OldCall.last_calls_total_stats(options)
      #   pdf = PdfGen::Generate.generate_last_calls_pdf(calls, total_calls, current_user, {:direction => '', :date_from => session_from_datetime, :date_till => session_till_datetime, :show_currency => session[:show_currency], :rs_active => reseller_active?, :can_see_finances => can_see_finances?})
      #   logger.debug("  >> Calls #{calls.size}")
      #   @show_destination = 1
      #   session[:last_calls_stats] = @options
      #   if params[:test].to_i == 1
      #     render :text => "OK"
      #   else
      #     send_data pdf.render, :filename => "Calls_#{session_from_datetime}-#{session_till_datetime}.pdf", :type => "application/pdf"
      #   end
      when 'csv'
        options[:test] = 1 if params[:test]
        options[:collumn_separator], options[:column_dem] = current_user.csv_params
        options[:current_user]	= current_user
        options[:show_full_src] = session[:show_full_src]
        options[:csv] = true
        filename, test_data = OldCall.last_calls_csv(options)
        filename = load_file_through_database(filename) if Confline.get_value("Load_CSV_From_Remote_Mysql").to_i == 1
        if filename
          filename = archive_file_if_size(filename, "csv", Confline.get_value("CSV_File_size").to_d)
          if (params[:test].to_i == 1) and (@user != nil) and (Confline.get_value("Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls").to_i != 0)
            render :text => ("#{nice_user(@user).gsub(' ', '_')}_" <<  filename) + test_data.to_s
          elsif params[:test].to_i == 1
            render :text => filename + test_data.to_s
          elsif (@user == nil) or (Confline.get_value("Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls").to_i == 0)
            file = File.open(filename) if File.exist?(filename)
            send_data file.read, :filename => filename if file
          else
            file = File.open(filename)
            send_data file.read, :filename => "#{nice_user(@user).gsub(' ', '_')}_" << filename
          end
        else
          flash[:notice] = _("Cannot_Download_CSV_File_From_DB_Server")
          redirect_to :root and return false
        end
    end

    if !params[:commit].nil?
      @options[:page] = 1
    end
  end

  def call_list
    dont_be_so_smart
    redirect_to :root and return false
  end

  def country_stats
    @page_title = _('Country_Stats')
    @page_icon = "world.png"
    @searching = params[:search_on].to_i == 1

    change_date

    country_stats_parse_params

    if @options[:start] <= @options[:end]
      @calls, @totals, @pies = Aggregate.country_stats(@options, current_user)
    else
      @calls, @totals, @pies = [], nil, {}
    end

    generate_country_stats_csv if params[:csv].to_i == 1

    session[:country_stats] = @options
  end

  ############ CSV ###############

  def last_calls_stats_admin
    redirect_to :action => "last_calls_stats"
  end


# in before filter : user (:find_user_from_id_or_session, :authorize_user)
  def call_list_to_csv
    @direction = "outgoing"
    @direction = params[:direction] if params[:direction]

    @sel_device_id = 0
    @sel_device_id = params[:device].to_i if params[:device]

    @device = Device.where(["id = ?", @sel_device_id]).first if @sel_device_id > 0

    @hgcs = Hangupcausecode.all
    @sel_hgc_id = 0
    @sel_hgc_id = params[:hgc].to_i if params[:hgc]

    @hgc = Hangupcausecode.where(:id => @sel_hgc_id).first if @sel_hgc_id > 0

    if session[:usertype].to_s != 'admin' and params[:reseller]
      dont_be_so_smart
      redirect_to :root and return false
    end
    res = session[:usertype] == 'admin' ? params[:reseller].to_i : 0

    date_from = params[:date_from] ? params[:date_from] : session_from_datetime
    date_till = params[:date_till] ? params[:date_till] : session_till_datetime
    call_type = params[:call_type] ? params[:call_type].to_s : 'answered'

    session[:usertype] == "accountant" ? user_type = "admin" : user_type = session[:usertype]
    filename, test_data = @user.user_calls_to_csv({:tz => current_user.time_offset, :device => @device, :direction => @direction, :call_type => call_type, :date_from => date_from, :date_till => date_till, :default_currency => session[:default_currency], :show_currency => session[:show_currency], :show_full_src => session[:show_full_src], :hgc => @hgc, :usertype => user_type, :nice_number_digits => session[:nice_number_digits], :test => params[:test].to_i, :reseller => res.to_i, :hide_finances => !can_see_finances?})
    filename = load_file_through_database(filename) if Confline.get_value("Load_CSV_From_Remote_Mysql").to_i == 1
    if filename
      filename = archive_file_if_size(filename, "csv", Confline.get_value("CSV_File_size").to_d)
      if params[:test].to_i != 1
        send_data(File.open(filename).read, :filename => filename)
      else
        render :text => filename + test_data.to_s
      end
    else
      flash[:notice] = _("Cannot_Download_CSV_File_From_DB_Server")
      redirect_to :root and return false
    end
  end

  ############ PDF ###############

=begin
in before filter : user (:find_user_from_id_or_session, :authorize_user)
=end
  def call_list_to_pdf
    @direction = "outgoing"
    @direction = params[:direction] if params[:direction]

    @sel_device_id = 0
    @sel_device_id = params[:device].to_i if params[:device]

    @device = Device.find(@sel_device_id) if @sel_device_id > 0


    @hgcs = Hangupcausecode.all
    @sel_hgc_id = 0
    @sel_hgc_id = params[:hgc].to_i if params[:hgc]

    @hgc = Hangupcausecode.where(:id => @sel_hgc_id).first if @sel_hgc_id > 0

    date_from = params[:date_from]
    date_till = params[:date_till]
    call_type = params[:call_type]
    user = @user

    calls = user.calls(call_type, date_from, date_till, @direction, "calldate", "DESC", @device, {:hgc => @hgc})


    ###### Generate PDF ########
    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")

    pdf.text("#{_('CDR_Records')}: #{user.first_name} #{user.last_name}", {:left => 40, :size => 16})
    pdf.text(_('Period') + ": " + date_from + "  -  " + date_till, {:left => 40, :size => 10})
    pdf.text(_('Currency') + ": #{session[:show_currency]}", {:left => 40, :size => 8})
    pdf.text(_('Total_calls') + ": #{calls.size}", {:left => 40, :size => 8})

    total_price = 0
    total_billsec = 0
    total_prov_price = 0
    total_prfit = 0
    total_did_provider = 0
    total_did_inc = 0
    total_did_own = 0
    total_did_prof = 0


    exrate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    items = []
    calls.each do |call|
      item = []
      @rate_cur3 = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.user_price.to_d]})
      @rate_prov = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.provider_price.to_d]}) if session[:usertype] == "admin"
      if session[:usertype] == "reseller"
        if call.reseller_id == 0
          # selfcost for reseller himself is user price, so profit always = 0 for his own calls
          @rate_prov = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.user_price.to_d]})
        else
          @rate_prov = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.reseller_price.to_d]})
        end
      end

      @rate_did_pr = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.did_prov_price.to_d]})
      @rate_did_ic = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.did_inc_price.to_d]})
      @rate_did_ow = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.did_price.to_d]})

      item << call.calldate.strftime("%Y-%m-%d %H:%M:%S")
      item << call.src
      item << hide_dst_for_user(current_user, "pdf", call.dst.to_s)

      if @direction == "incoming"
        billsec = call.did_billsec
      else
        billsec = call.nice_user_billsec
      end

      item << nice_time(billsec)
      item << call.disposition

      if session[:usertype] == "admin"
        if @direction == "incoming"
          item << nice_number(@rate_did_pr)
          item << nice_number(@rate_did_ic)
          item << nice_number(@rate_did_ow)
          item << nice_number(@rate_did_pr + @rate_did_ic + @rate_did_ow)
          item << nice_number(@rate_did_pr + @rate_did_ow)
        else
          item << nice_number(@rate_cur3)
          item << nice_number(@rate_prov)
          item << nice_number(@rate_cur3.to_d - @rate_prov.to_d)
          item << nice_number(@rate_cur3.to_d != 0.to_d ? ((@rate_cur3.to_d - @rate_prov.to_d)/ @rate_cur3.to_d) *100 : 0) + " %"
          item << nice_number(@rate_prov.to_d != 0.to_d ? ((@rate_cur3.to_d / @rate_prov.to_d) *100)-100 : 0) + " %"
        end
      end

      if session[:usertype] == "reseller"
        if @direction == "incoming"
          item << nice_number(@rate_did_ow)
        else
          item << nice_number(@rate_cur3)
          item << nice_number(@rate_prov)
          item << nice_number(@rate_cur3.to_d - @rate_prov.to_d)
          item << nice_number(@rate_cur3.to_d != 0.to_d ? ((@rate_cur3.to_d - @rate_prov.to_d)/ @rate_cur3.to_d) *100 : 0) + " %"
          item << nice_number(@rate_prov.to_d != 0.to_d ? ((@rate_cur3.to_d / @rate_prov.to_d) *100)-100 : 0) + " %"
        end
      end

      if session[:usertype] == "user" or session[:usertype] == "accountant"
        if @direction != "incoming"
          item << nice_number(@rate_cur3)
        else
          item << nice_number(@rate_did_ow)
        end
      end

      price_element = 0
      if @direction == "incoming"
        price_element = @rate_did_ow
      else
        price_element = @rate_cur3 if call.user_price
      end
      total_price += price_element
      #total_price += @rate_cur3 if call.user_price
      total_prov_price += @rate_prov.to_d
      total_prfit += @rate_cur3.to_d - @rate_prov.to_d
      total_billsec += call.nice_user_billsec
      total_did_provider += @rate_did_pr
      total_did_inc += @rate_did_ic
      total_did_own += @rate_did_ow
      total_did_prof += @rate_did_pr.to_d + @rate_did_ic.to_d + @rate_did_ow.to_d

      items << item
    end
    item = []
    #Totals
    item << {:text => _('Total'), :colspan => 3}
    item << nice_time(total_billsec)
    item << ' '
    if session[:usertype] == "admin" or session[:usertype] == "reseller"
      if @direction == "incoming"
        item << nice_number(total_did_provider)
        item << nice_number(total_did_inc)
        item << nice_number(total_did_own)
        item << nice_number(total_did_prof)
      else
        item << nice_number(total_price)
        item << nice_number(total_prov_price)
        item << nice_number(total_prfit)
        total_price_dec = total_price.to_d
        if total_price_dec != 0
          item << nice_number(total_price_dec != 0.to_d ? (total_prfit / total_price_dec) * 100 : 0) + " %"
        else
          item << nice_number(0) + " %"
        end
        if total_prov_price.to_d != 0
          item << nice_number(total_prov_price.to_d != 0 ? ((total_price_dec / total_prov_price.to_d) *100)-100 : 0) + " %"
        else
          item << nice_number(0) + " %"
        end
      end
    else
      if @direction != "incoming"
        item << nice_number(total_price)
      end
    end

    items << item

    headers, h = PdfGen::Generate.call_list_to_pdf_header(pdf, @direction, session[:usertype], 0, {})

    pdf.table(items,
              :width => 550, :border_width => 0,
              :font_size => 7,
              :headers => headers) do
    end

    string = "<page>/<total>"
    opt = {:at => [500, 0], :size => 9, :align => :right, :start_count_at => 1}
    pdf.number_pages string, opt

    send_data pdf.render, :filename => "Calls_#{user.first_name}_#{user.last_name}_#{date_from}-#{date_till}.pdf", :type => "application/pdf"
  end

  def users_finances
    default = {:page => "1", :s_completed => '', :s_username => "", :s_fname => "", :s_lname => "", :s_balance_min => "", :s_balance_max => "", :s_type => ""}
    @page_title = _('Users_finances')
    @page_icon = "money.png"
    @searching = params[:search_on].to_i == 1

    @options = !session[:users_finances_options] ? default : session[:users_finances_options]
    default.each { |key, value| @options[key] = params[key] if params[key] }

    if @searching
      owner_id = (session[:usertype] == "accountant" ? 0 : session[:user_id])
      cond = ['users.hidden = ?', 'users.owner_id = ?']
      var = [0, owner_id]

      if ['postpaid', 'prepaid'].include?(@options[:s_type])
        cond << 'users.postpaid = ?'
        var << (@options[:s_type] == "postpaid" ? 1 : 0)
      end

      add_contition_and_param(@options[:s_username], @options[:s_username] + '%', "users.username LIKE ?", cond, var)
      add_contition_and_param(@options[:s_fname], @options[:s_fname] + '%', "users.first_name LIKE  ?", cond, var)
      add_contition_and_param(@options[:s_lname], @options[:s_lname] + '%', "users.last_name LIKE ?", cond, var)
      add_contition_and_param(@options[:s_balance_min], @options[:s_balance_min].to_d, "users.balance >= ?", cond, var)
      add_contition_and_param(@options[:s_balance_max], @options[:s_balance_max].to_d, "users.balance <= ?", cond, var)
      @total_users = User.count(:all, :conditions => [cond.join(' AND ').to_s] + var).to_i

      items_per_page, total_pages = item_pages(@total_users)
      page_no = Application.valid_page_number(@options[:page], total_pages)
      offset, limit = Application.query_limit(total_pages, items_per_page, page_no)

      @total_pages = total_pages
      @options[:page] = page_no

      @users = User.includes(payments: {user: :tax}).
                    where([cond.join(' AND ').to_s] + var).
                    limit(limit).
                    offset(offset).all

      cond.size.to_i > 2 ? @search = 1 : @search = 0
      @total_balance = @total_credit = @total_payments = @total_amount =0
      @amounts = {}
      @payment_size = {}
      hide_uncompleted_payment = Confline.get_value("Hide_non_completed_payments_for_user", current_user.id).to_i

      @users.each_with_index do |user, i|

        payments = user.payments
        amount = 0
        pz = 0
        payments.each do |p|
          if hide_uncompleted_payment == 0 or (hide_uncompleted_payment == 1 and (p.pending_reason != 'Unnotified payment' or p.pending_reason.blank?))
            if p.completed.to_i == @options[:s_completed].to_i or @options[:s_completed].blank?
              pz += 1
              pa = p.payment_amount
              amount += get_price_exchange(pa, p.currency)
            end
          end
        end
        user_id = user.id
        @amounts[user_id] = amount
        @payment_size[user_id] = pz
        @total_balance += user.balance
        @total_credit += user.credit if user.credit != (-1) and user.postpaid.to_i != 0
        @total_payments += pz
        @total_amount += amount
      end
    end
    session[:users_finances_options] = @options
  end

  def providers
    @page_title = _('Providers_stats')

    @searching = params[:search_on].to_i == 1
    @clear = params[:clear].to_i == 1 if params[:clear]

    change_date

    change_date_to_present if @clear

    @show_currency_selector=1
    @s_prefix = params[:search].to_s.strip
    @show_hidden_providers = params[:show_hidden_providers].to_i
    @hide_providers = params[:hide_providers].to_i
    unless  @s_prefix.blank?
      @dest = Destination.where("prefix LIKE '#{@s_prefix}'").order("LENGTH(destinations.prefix) DESC").first
      @flag = nil
      if @dest == nil
        @results = ""
      else
        @flag = @dest.direction_code
        direction = @dest.direction
        @results = @dest.subcode.to_s+" "+@dest.name.to_s
        @results = direction.name.to_s+" "+ @results if direction
      end
    end

    if @searching
      @providers = Provider.find_all_with_calls_for_stats(current_user, { :date_from => limit_search_by_days, :date_till => session_till_datetime,
                                                                          :s_prefix => @s_prefix, :show_currency => session[:show_currency],
                                                                          :default_currency => session[:default_currency],
                                                                          :show_hidden => @show_hidden_providers,
                                                                          :hide_providers_without_calls => @hide_providers })
    end
  end

  def providers_stats
    @page_title = _('Providers_stats')
    @page_icon = "chart_pie.png"

    id = params[:id]
    p = Provider.where(:id => id).first

    if !p
      flash[:notice] = _("Provider_not_found")
      redirect_to :root and return false
    end

    id = id.to_i

    change_date

    @s_prefix = ""
    @s_prefix = params[:search] if params[:search]
    cond =""

    if  @s_prefix.to_s != ""
      cond += " AND calls.prefix = '#{@s_prefix}' "
      @dest = Destination.where("prefix = SUBSTRING('#{@s_prefix}', 1, LENGTH(destinations.prefix))").order("LENGTH(destinations.prefix) DESC").first
      @flag = nil
      if @dest == nil
        @results = ""
      else
        @flag = @dest.direction_code
        direction = @dest.direction
        @results = @dest.subcode.to_s+" "+@dest.name.to_s
        @results = direction.name.to_s+" "+ @results if direction
      end
    end

    @provider = Provider.find_all_with_calls_for_stats(current_user, {:date_from => session_from_datetime, :date_till => session_till_datetime, :s_prefix => @s_prefix, :p_id => id})[0]
    if @provider
      @asr_calls = nice_number((@provider.answered.to_d / @provider.pcalls.to_d) * 100)
      @no_answer_calls_pr = nice_number((@provider.no_answer.to_d / @provider.pcalls.to_d) * 100)
      @busy_calls_pr = nice_number((@provider.busy.to_d / @provider.pcalls.to_d) * 100)
      @failed_calls_pr = nice_number((@provider.failed.to_d / @provider.pcalls.to_d) * 100)

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

      @_billsec2=[]
      @a_user_price2 = []
      @a_provider_price2 = []

      @t_calls = 0
      @t_billsec = 0
      @t_avg_billsec = 0
      @t_normative = 0
      @t_norm_days = 0
      @t_avg_normative = 0

      i = 0
      cond += reseller? ? " AND (calls.reseller_id = #{current_user.id} OR calls.user_id = #{current_user.id} )" : ''
      s = []
      if admin?
        s << "SUM(provider_price) as 'selfcost_price'"
        s << "SUM(IF(reseller_id > 0, reseller_price, user_price)) AS 'sel_price'"
        s << "SUM(IF(reseller_id > 0, reseller_price, user_price) - provider_price ) AS 'profit'"
      else
        s << "SUM(IF(providers.common_use = 1, reseller_price,provider_price)) as 'selfcost_price'"
        s << "SUM(user_price) AS 'sel_price'"
        s << "SUM(user_price - IF(providers.common_use = 1, reseller_price,provider_price)) AS 'profit'"
      end

      while @sdate < @edate
        @a_date[i] = @sdate.strftime("%Y-%m-%d")

        @a_calls[i] = 0
        @a_billsec[i] = 0
        @a_calls2[i] = 0
        @a_user_price = 0
        @a_provider_price = 0
        @a_user_price2[i] = 0
        @a_provider_price2[i]= 0
        @_billsec2[i] = 0

        sql ="SELECT COUNT(calls.id) as \'calls\',  SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) as \'billsec\' FROM calls WHERE ((calls.provider_id = '#{id}' and calls.callertype = 'Local') OR (calls.did_provider_id = '#{id}' and calls.callertype = 'Outside'))" +
            "AND calls.calldate BETWEEN '#{@a_date[i]} 00:00:00' AND '#{@a_date[i]} 23:23:59'" +
            "AND disposition = 'ANSWERED' #{cond}"
        res = ActiveRecord::Base.connection.select_all(sql)
        @a_calls[i] = res[0]["calls"].to_i
        @a_billsec[i] = res[0]["billsec"].to_i

        if @a_billsec[i] != 0

          @a_profit=0
          @a_user_price=0
          @a_user_price2[i]=0
          @a_provider_price=0
          @a_provider_price2[i]=0

          @calls3 = Call.select(s.join(' , ')).
                         joins("LEFT JOIN providers ON (providers.id = calls.provider_id)").
                         where(["((calls.provider_id = ? and calls.callertype = 'Local') OR (calls.did_provider_id = ? and calls.callertype = 'Outside')) AND disposition = 'ANSWERED' AND calldate BETWEEN '#{@a_date[i]} 00:00:00' AND '#{@a_date[i]} 23:23:59' #{cond}", id, id]).
                         group("calls.provider_id").
                         order("calldate DESC")
          @a_user_price2[i]= nice_number @calls3[0].sel_price
          @a_provider_price2[i]= nice_number @calls3[0].selfcost_price
        end

        @a_avg_billsec[i] = 0
        @a_avg_billsec[i] = @a_billsec[i] / @a_calls[i] if @a_calls[i] > 0


        @t_calls += @a_calls[i]
        @t_billsec += @a_billsec[i]

        sqll ="SELECT COUNT(calls.id) as \'calls2\' FROM calls WHERE ((calls.provider_id = '#{id}' and calls.callertype = 'Local') OR (calls.did_provider_id = '#{id}' and calls.callertype = 'Outside'))" +
            "AND calls.calldate BETWEEN '#{@a_date[i]} 00:00:00' AND '#{@a_date[i]} 23:23:59' #{cond}"
        res2 = ActiveRecord::Base.connection.select_all(sqll)
        @a_calls2[i] = res2[0]["calls2"].to_i

        @a_ars2[i] = (@a_calls[i].to_d / @a_calls2[i]) * 100 if @a_calls[i] > 0
        @a_ars[i] = nice_number @a_ars2[i]

        @sdate += (60 * 60 * 24)
        i+=1
      end

      index = i

      @t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0

      #===== Graph =====================

      @Calls_graph = "\""
      if @provider.pcalls.to_i > 0

        @Calls_graph += _('ANSWERED') +";" +@provider.answered.to_s + ";" + "false" + "\\n"
        @Calls_graph += _('NO_ANSWER') +";" +@provider.no_answer.to_s + ";" + "false" + "\\n"
        @Calls_graph += _('BUSY') +";" +@provider.busy.to_s+ ";" + "false" + "\\n"
        @Calls_graph += _('FAILED') +";" +@provider.failed.to_s + ";" + "false" + "\\n"

        @Calls_graph += "\""
      else
        @Calls_graph = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
      end

      #formating graph for Avg.Calltime
      ine=0
      @Avg_Calltime_graph =""
      while ine <= index - 1
        @Avg_Calltime_graph +=nice_date(@a_date[ine].to_s) + ";" + @a_avg_billsec[ine].to_s + "\\n"
        ine=ine +1
      end

      #formating graph for Asr calls
      ine=0
      @Asr_graph =""
      while ine <= index - 1
        @Asr_graph +=nice_date(@a_date[ine].to_s) + ";" + @a_ars[ine].to_s + "\\n"
        ine=ine +1
      end

      #formating graph for Profit calls
      ine=0
      @Profit_graph =""
      while ine <= index - 1
        @Profit_graph +=nice_date(@a_date[ine].to_s) + ";" + @a_user_price2[ine].to_s + ";"+@a_provider_price2[ine].to_s + "\\n"
        ine=ine +1
      end
    end
  end

  def loss_making_calls
    @page_title = _('Loss_making_calls')
    @page_icon = "money_delete.png"
    @searching = params[:search_on].to_i == 1

    change_date

    condition = ""
    if params[:reseller_id]
      if params[:reseller_id].to_i != -1
        @reseller = User.where(["id = ?", params[:reseller_id]]).first
        condition =" AND calls.reseller_id = '#{@reseller.id}' "
        @reseller_id = @reseller.id
      else
        condition = ""
      end
    end
    @resellers = User.where('usertype = "reseller"').order('first_name ASC').all

    if @searching
      @calls = Call.includes([:user, :provider, :device]).
                    where("provider_price > user_price AND calldate BETWEEN \'" + session_from_date + " 00:00:00\' AND \'" + session_till_date + " 23:59:59\' AND disposition = \'ANSWERED\'"+ condition).
                    order("calldate DESC").all

      @total_calls = Call.select('COUNT(*), SUM(IF((billsec IS NULL OR billsec = 0), IF(real_billsec IS NULL, 0, real_billsec), billsec)) AS total_duration, SUM(provider_price - did_prov_price - (user_price + did_inc_price)) AS total_loss').
                          where('provider_price > user_price AND calldate BETWEEN \'' + session_from_date + ' 00:00:00\' AND \'' + session_till_date + ' 23:59:59\' AND disposition = \'ANSWERED\''+ condition)
    end
  end

  def get_rs_user_map
    @responsible_accountant_id = params[:responsible_accountant_id] ? params[:responsible_accountant_id].to_i : -1
    @responsible_accountant_id.to_s != "-1" ? cond = ['responsible_accountant_id = ?', @responsible_accountant_id] : ""
    output = []
    output << "<option value='-1'>All</option>"
    output << User.where(cond).map { |u| ["<option value='"+u.id.to_s+"'>"+nice_user(u)+"</option>"] }
    render :text => output.join
  end

  def profit
    @page_title = _('Profit')
    @page_icon = "money.png"
    change_date
    @searching = params[:search_on].to_i == 1
    @sub_vat = @sub_price = @did_owner_cost = 0
    owner = correct_owner_id
    if admin?
      @responsible_accountants = User.select('accountants.*').
                                 joins(['JOIN users accountants ON(accountants.id = users.responsible_accountant_id)']).
                                 where("accountants.hidden = 0 and accountants.usertype = 'accountant'").
                                 group('accountants.id').order('accountants.username')
    end

    @search_user = params[:s_user]
    @user_id = params[:s_user_id]

    up, rp, pp = current_user.get_price_calculation_sqls
    @user_id = params[:s_user_id] ? params[:s_user_id].to_i : -1
    @user_id = -1 if @user_id == -2 && @search_user.blank?
    @responsible_accountant_id = params[:responsible_accountant_id] ? params[:responsible_accountant_id].to_i : -1

    if @searching
      session[:hour_from], session[:minute_from], session[:hour_till], session[:minute_till] = ['00', '00', '23', '59']
      conditions, cond_did_owner_cost, user_sql2, select = Stat.find_sql_conditions_for_profit(reseller?, session[:user_id].to_i, @user_id, @responsible_accountant_id, session_from_datetime, session_till_datetime, up, pp)

      total = Call.find_totals_for_profit_prices(select, conditions)

      @total_duration = (total["billsec"]).to_i
      @total_call_price = (total["user_price"]).to_d
      @total_call_selfprice = (total["provider_price"].to_d - (reseller? ? 0 : total["did_prov_price"].to_d))

      total = Call.find_totals_for_profit(conditions)

      if total and total[0] and total[0]["total_calls"].to_i != 0
        @total_calls = total[0]["total_calls"].to_i
        @total_answered_calls = total[0]["answered_calls"].to_i
        @total_not_ans_calls = total[0]["no_answer_calls"].to_i
        @total_busy_calls = total[0]["busy_calls"].to_i
        @total_error_calls = total[0]["failed_calls"].to_i

        if @total_calls != 0
          @average_call_duration = @total_duration.to_d / @total_answered_calls.to_d

          @total_answer_percent = @total_answered_calls.to_d * 100 / @total_calls.to_d
          @total_not_ans_percent = @total_not_ans_calls.to_d * 100 / @total_calls.to_d
          @total_busy_percent = @total_busy_calls.to_d * 100 / @total_calls.to_d
          @total_error_percent = @total_error_calls.to_d * 100 / @total_calls.to_d
        else
          @total_answer_percent = @total_not_ans_percent = @total_busy_percent = @total_error_percent = @average_call_duration = 0
        end
      else
        @total_calls = @total_answered_calls = 0
        @total_answer_percent = @total_not_ans_percent = @total_busy_percent = @total_error_percent = 0
        @average_call_duration = @total_not_ans_calls = @total_busy_calls = @total_error_calls = 0
      end

      @total_profit = @total_call_price - @total_call_selfprice

      if @total_call_price != 0 && @total_answered_calls != 0
        select = ['']
        res = Call.where("#{SqlExport.replace_price("SUM(#{up})", {:reference => 'price'})}, SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) AS 'duration', COUNT(DISTINCT(calls.user_id)) AS 'users', SUM(did_price) AS did_price").
                   joins("LEFT JOIN users ON (users.id = calls.user_id) #{ SqlExport.left_join_reseler_providers_to_calls_sql}").
                   where((conditions + ["calls.disposition = 'ANSWERED'"]).join(" AND "))
        if !reseller?
          @did_owner_cost = Call.select("SUM(did_price) AS did_price").
                                 joins("LEFT JOIN users ON (users.id = calls.user_id) #{ SqlExport.left_join_reseler_providers_to_calls_sql}").
                                 where((cond_did_owner_cost + ["calls.disposition = 'ANSWERED'"]).
                                 join(" AND ")).first.did_price
        end

        resu = Call.select("COUNT(DISTINCT(calls.user_id)) AS 'users'").
                    joins("LEFT JOIN users ON (users.id = calls.user_id) #{ SqlExport.left_join_reseler_providers_to_calls_sql}").
                    where((conditions + ["calls.disposition = 'ANSWERED' and card_id < 1"]).join(" AND "))
        @total_users = resu[0]["users"].to_i if resu and resu[0]

        @total_percent = 100
        @total_profit_percent = @total_profit.to_d * 100 / @total_call_price.to_d
        @total_selfcost_percent = @total_percent - @total_profit_percent
        #average
        @total_duration_min = @total_duration.to_d / 60
        @avg_profit_call_min = @total_profit.to_d / @total_duration_min
        @avg_profit_call = @total_profit.to_d / @total_answered_calls.to_d
        days = (session_till_date.to_date - session_from_date.to_date).to_f
        days = 1.0 if days == 0;
        @avg_profit_day = @total_profit.to_d / (session_till_date.to_date - session_from_datetime.to_date + 1).to_i
        @total_users != 0 ? @avg_profit_user = @total_profit.to_d / @total_users.to_d : @avg_profit_user = 0
      else
        #profit
        @total_percent = 0
        @total_profit_percent = 0
        @total_selfcost_percent = 0
        #avg
        @avg_profit_call_min = 0
        @avg_profit_call = 0
        @avg_profit_day = 0
        @avg_profit_user = 0
      end

      a1 = session_from_datetime
      a2 = session_till_datetime
      @sub_price_vat = 0
      res = Stat.find_services_for_profit(reseller?, a1, a2, user_sql2)
      @sub_price = Stat.find_subs_params(res, a1, a2, @sub_price)
      @s_total_profit = @total_profit

      if !reseller?
        @s_total_profit += @did_owner_cost.to_d
      end

      @s_total_profit += @sub_price
    end
  end

 #Generates profit report in PDF
  def generate_profit_pdf
    @user_id = -1
    user_name = ""
    if params[:user_id]
      if params[:user_id] != "-1"
        @user_id = params[:user_id]
        user = User.find_by_sql("SELECT * FROM users WHERE users.id = '#{@user_id}'")
        if user[0].present?
          user_name = user[0]["username"] + " - " + user[0]["first_name"] + " " + user[0]["last_name"]
        else
          user_name = params[:username].to_s
        end
      else
        user_name = "All users"
      end
    end

    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf.font_families.update("arial" => {
        :bold => "#{Prawn::BASEDIR}/data/fonts/Arialb.ttf",
        :italic => "#{Prawn::BASEDIR}/data/fonts/Ariali.ttf",
        :bold_italic => "#{Prawn::BASEDIR}/data/fonts/Arialbi.ttf",
        :normal => "#{Prawn::BASEDIR}/data/fonts/Arial.ttf"})

    #pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")
    pdf.text(_('PROFIT_REPORT'), {:left => 40, :size => 14, :style => :bold})
    pdf.text(_('Time_period') + ": " + session_from_date.to_s + " - " + session_till_date.to_s, {:left => 40, :size => 10, :style => :bold})
    pdf.text(_('Counting') + ": " + user_name.to_s, {:left => 40, :size => 10, :style => :bold})

    pdf.move_down 60
    pdf.stroke do
      pdf.horizontal_line 0, 550, :fill_color => '000000'
    end
    pdf.move_down 20

    items = []

    item = [_('Total_calls'), {:text => params[:total_calls].to_s, :align => :left}, {:text => ' ', :colspan => 3}]
    items << item

    item = [_('Answered_calls'), {:text => params[:total_answered_calls].to_s, :align => :left}, {:text => nice_number(params[:total_answer_percent].to_s) + " %", :align => :left}, _('Duration') + ": " + nice_time(params[:total_duration]), _('Average_call_duration') + ": " + nice_time(params[:average_call_duration])]
    items << item

    item = [_('No_Answer'), {:text => params[:total_not_ans_calls].to_s, :align => :left}, {:text => nice_number(params[:total_not_ans_percent].to_s) + " %", :align => :left}, {:text => ' ', :colspan => 2}]
    items << item

    item = [_('Busy_calls'), {:text => params[:total_busy_calls].to_s, :align => :left}, {:text => nice_number(params[:total_busy_percent].to_s) + " %", :align => :left}, {:text => ' ', :colspan => 2}]
    items << item

    item = [_('Error_calls'), {:text => params[:total_error_calls].to_s, :align => :left}, {:text => nice_number(params[:total_error_percent].to_s) + " %", :align => :left}, {:text => ' ', :colspan => 2}]
    items << item

    # bold
    item = [' ', {:text => _('Price'), :align => :left, :style => :bold}, {:text => _('Percent'), :align => :left, :style => :bold}, {:text => _('Call_time'), :align => :left, :style => :bold}, {:text => _('Active_users'), :align => :left, :style => :bold}]
    items << item

    item = [_('Total_call_price'), {:text => nice_number(params[:total_call_price].to_s), :align => :left}, {:text => nice_number(params[:total_percent].to_s), :align => :left}, {:text => nice_time(params[:total_duration].to_s), :align => :left}, {:text => params[:active_users].to_i.to_s, :align => :left}]
    items << item

    item = [_('Total_call_self_price'), {:text => nice_number(params[:total_call_selfprice].to_s), :align => :left}, {:text => nice_number(params[:total_selfcost_percent].to_s), :align => :left}, {:text => ' ', :colspan => 2}]
    items << item

    item = [_('Calls_profit'), {:text => nice_number(params[:total_profit].to_s), :align => :left}, {:text => nice_number(params[:total_percent_percent].to_s), :align => :left}, {:text => ' ', :colspan => 2}]
    items << item

    item = [_('Average_profit_per_call_min'), {:text => nice_number(params[:avg_profit_call_min].to_s), :align => :left}, {:text => ' ', :colspan => 3}]
    items << item

    item = [_('Average_profit_per_call'), {:text => nice_number(params[:avg_profit_call].to_s), :align => :left}, {:text => ' ', :colspan => 3}]
    items << item

    item = [_('Average_profit_per_day'), {:text => nice_number(params[:avg_profit_day].to_s), :align => :left}, {:text => ' ', :colspan => 3}]
    items << item

    item = [_('Average_profit_per_active_user'), {:text => nice_number(params[:avg_profit_user].to_s), :align => :left}, {:text => ' ', :colspan => 3}]
    items << item

    if session[:usertype] != 'reseller'
      # bold
      item = [' ', {:text => _('Price'), :align => :left, :style => :bold}, {:text => ' ', :colspan => 3}]
      items << item

      # bold  1 collumn
      item = [{:text => _('Subscriptions_profit'), :align => :left, :style => :bold}, {:text => nice_number(params[:sub_price].to_s), :align => :left}, {:text => ' ', :colspan => 3}]
      items << item

      # bold  1 collumn
      item = [{:text => _('Total_profit'), :align => :left, :style => :bold}, {:text => nice_number(params[:s_total].to_s), :align => :left}, {:text => ' ', :colspan => 3}]
      items << item

    end

    pdf.table(items,
              :width => 550, :border_width => 0,
              :font_size => 9) do
      column(0).style(:align => :left)
      column(1).style(:align => :left)
      column(2).style(:align => :left)
      column(3).style(:align => :left)
      column(4).style(:align => :left)
    end

    pdf.move_down 20
    pdf.stroke do
      pdf.horizontal_line 0, 550, :fill_color => '000000'
    end

    send_data pdf.render, :filename => "Profit-#{user_name}-#{session_from_date.to_s}_#{session_till_date.to_s}.pdf", :type => "application/pdf"
  end

  def providers_calls
    dont_be_so_smart
    redirect_to :root and return false
  end

  ############ PDF ###############

  def providers_calls_to_pdf
    #require "pdf/wrapper"
    id = params[:id]
    if id
      provider = Provider.find(id)
    end

    id = id.to_i

    date_from = params[:date_from]
    date_till = params[:date_till]
    call_type = params[:call_type]
    params[:direction] ? @direction = params[:direction] : @direction = "outgoing"
    params[:call_type] ? @call_type = params[:call_type] : @call_type = "all"
    @orig_call_type = @call_type
    if @direction == "incoming"
      disposition = " (calls.did_provider_id = '#{id}' OR calls.src_device_id = '#{provider.device_id}' )"
    else
      disposition = " calls.provider_id = '#{id}' "
    end
    disposition += " AND disposition = '#{@call_type}' " if @call_type != "all"
    disposition += " AND calldate BETWEEN '#{date_from}' AND '#{date_till}'"
    calls = Call.where("#{disposition}").order("calldate DESC")
    options = {
        :date_from => date_from,
        :date_till => date_till,
        :call_type => call_type,
        :nice_number_digits => session[:nice_number_digits],
        :currency => session[:show_currency],
        :default_currency => session[:default_currency],
        :direction => @direction
    }

    a = MorLog.my_debug("Genetare_start", true)
    pdf = PdfGen::Generate.providers_calls_to_pdf(provider, calls, options)
    b = MorLog.my_debug("Genetare_end", true)
    MorLog.my_debug("Generate_time : #{b - a}")
    send_data pdf.render, :filename => "CDR-#{provider.name}-#{date_from}_#{date_till}.pdf", :type => "application/pdf"
  end

  ############ CSV ###############

  def providers_calls_to_csv

    provider = Provider.where(:id => params[:id]).first
    unless provider
      flash[:notice] = _('Provider_not_found')
      redirect_to :root and return false
    end

    date_from = params[:date_from]
    date_till = params[:date_till]

    @direction = "outgoing"
    @direction = params[:direction] if params[:direction]

    @call_type = "all"
    @call_type = params[:call_type] if params[:call_type]

    @orig_call_type = @call_type

    filename, test_data = provider.provider_calls_csv({:tz => current_user.time_offset, :direction => @direction, :call_type => @call_type, :date_from => date_from, :date_till => date_till, :default_currency => session[:default_currency], :show_currency => session[:show_currency], :show_full_src => session[:show_full_src], :nice_number_digits => session[:nice_number_digits], :test => params[:test].to_i})
    filename = archive_file_if_size(filename, "csv", Confline.get_value("CSV_File_size").to_d)
    if params[:test].to_i != 1
      send_data(File.open(filename).read, :filename => filename)
    else
      render :text => filename + test_data
    end
  end


  def faxes
    @page_title = _('Faxes')
    @page_icon = "printer.png"
    change_date
    if session[:usertype] == "admin"
      @users = User.where("hidden = 0 AND usertype = 'user'").order("username ASC ")
    else
      @users = User.where(["hidden = 0 AND usertype = 'user' AND owner_id = ?", correct_owner_id]).order("username ASC ")
    end

    @search = 0

    @received = []
    @corrupted = []
    @mistaken = []
    @total = []
    @size_on_hdd = []

    @t_received = 0
    @t_corrupted = 0
    @t_mistaken = 0
    @t_total = 0
    @t_size_on_hdd = 0

    i = 0
    for user in @users
      sql = "SELECT COUNT(pdffaxes.id) as 'cf' FROM pdffaxes JOIN devices ON (pdffaxes.device_id = devices.id AND devices.user_id = #{user.id}) WHERE receive_time BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' AND status = 'good'"
      res = ActiveRecord::Base.connection.select_value(sql)
      @received[i] = res.to_i

      sql = "SELECT COUNT(pdffaxes.id) as 'cf' FROM pdffaxes JOIN devices ON (pdffaxes.device_id = devices.id AND devices.user_id = #{user.id}) WHERE receive_time BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' AND status = 'pdf_size_0'"
      res = ActiveRecord::Base.connection.select_value(sql)
      @corrupted[i] = res.to_i

      sql = "SELECT COUNT(pdffaxes.id) as 'cf' FROM pdffaxes JOIN devices ON (pdffaxes.device_id = devices.id AND devices.user_id = #{user.id}) WHERE receive_time BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' AND status = 'no_tif'"
      res = ActiveRecord::Base.connection.select_value(sql)
      @mistaken[i] = res.to_i

      @total[i] = @received[i] + @corrupted[i] + @mistaken[i]

      sql = "SELECT SUM(pdffaxes.size) as 'cf' FROM pdffaxes JOIN devices ON (pdffaxes.device_id = devices.id AND devices.user_id = #{user.id}) WHERE receive_time BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'"
      res = ActiveRecord::Base.connection.select_value(sql)
      @size_on_hdd[i] = res.to_d / (1024 * 1024)

      @t_received += @received[i]
      @t_corrupted += @corrupted[i]
      @t_mistaken += @mistaken[i]
      @t_total += @total[i]
      @t_size_on_hdd += @size_on_hdd[i]

      i += 1
    end
  end

  def faxes_list
    @page_title = _('Faxes')
    @page_icon = "printer.png"

    selected_user = User.where(id: params[:id]).first
    if !selected_user.try(:is_user?) || !session[:fax_device_enabled]
      dont_be_so_smart
      redirect_to :root and return false
    end

    change_date

    if admin? or accountant?
      @user = User.where(["id = ?", params[:id].to_i]).first
      if params[:id].to_i >= 0 and @user == nil
        flash[:notice] = _('User_not_found')
        redirect_to :root and return false
      end
    else
      @user = User.find(session[:user_id])
    end

    @devices = @user.fax_devices

    @Fax2Email_Folder = Confline.get_value("Fax2Email_Folder", 0)
    if @Fax2Email_Folder.to_s == ""
      @Fax2Email_Folder = Web_URL + Web_Dir + "/fax2email/"
    end

    @sel_device = "all"
    @sel_device = params[:device_id] if params[:device_id]
    device_sql = ""
    device_sql = " AND device_id = '#{@sel_device}' " if @sel_device != "all"

    @fstatus = "all"
    @fstatus = params[:fstatus] if params[:fstatus]
    status_sql = ""
    status_sql = " AND status = '#{@fstatus}' " if @fstatus != "all"

    @search = 0
    @search = 1 if params[:search_on]

    sql = "SELECT pdffaxes.* FROM pdffaxes, devices WHERE pdffaxes.device_id = devices.id AND devices.user_id = #{@user.id} AND receive_time BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{status_sql} #{device_sql}"
    @faxes = Pdffax.find_by_sql(sql)


  end

  #================= ACTIVE CALLS ====================

  def active_calls_count
    user = User.new(:usertype => session[:usertype])
    user.id = session[:usertype] == 'accountant' ? 0 : session[:user_id]
    @acc = Activecall.count_for_user(user)
    render(:layout => false)
  end

  def active_calls
    unless ["admin", "accountant"].include?(session[:usertype]) or session[:show_active_calls_for_users].to_i == 1 or (current_user and current_user.reseller_allow_providers_tariff?)
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :root and return false
    end
    user = User.new(:usertype => session[:usertype])
    user.id = session[:usertype] == 'accountant' ? 0 : session[:user_id]
    @page_title = _('Active_Calls')
    @page_icon = "call.png"
    active_calls_order

    #search
    @users = reseller? ? User.where("owner_id = ? AND usertype = 'user'", current_user.id).all : User.where("usertype = 'user'").all
    @countries = Direction.select('name')
    @providers = accountant? ?  Provider.all : current_user.load_providers
  end

  def active_calls_order
    sort_options = ["status", "answer_time", "duration", "src", "localized_dst", "provider_name", "server_id", "did"]
    session[:active_calls_options] ? @options = session[:active_calls_options] : @options = {:order_by => "duration", :order_desc => 1, :update => "active_calls", :controller => :stats, :action => :active_calls_order}
    @options[:order_by] = params[:order_by] if params[:order_by] and sort_options.include?(params[:order_by].to_s)
    @options[:order_desc] = params[:order_desc].to_i if params[:order_desc] and [0, 1].include?(params[:order_desc].to_i)
    session[:active_calls_options] = @options
    active_calls_show
    render(partial: 'active_calls_show',
           locals: {active_calls: @active_calls, options: @options,
                    show_did: @show_did, ma_active: @ma_active,
                    chanspy_disabled: @chanspy_disabled,
                    spy_device: @spy_device, user_id: @user_id,
                    refresh_period: @refresh_period
    }) if params[:action].to_s == "active_calls_order"
  end

  def active_calls_show
    session[:active_calls_options] ? @options = session[:active_calls_options] : @options = {:order_by => "duration", :order_desc => 1, :update => "active_calls", :controller => :stats, :action => :active_calls_order}
    @time_now = Time.now
    @refresh_period = session[:active_calls_refresh_interval].to_i

    # this code selects correct calls for admin/reseller/user
    hide_active_calls_longer_than = Confline.get_value('Hide_active_calls_longer_than', 0).to_i
    hide_active_calls_longer_than = 24 if hide_active_calls_longer_than.zero?
    user_sql = " (DATE_ADD(activecalls.start_time, INTERVAL #{hide_active_calls_longer_than} HOUR) > NOW()) "
    user_id = session[:usertype] == 'accountant' ? 0 : session[:user_id]
    @user_id = user_id
    if user_id != 0
      #reseller or user
      if reseller?
        #reseller
        user_sql << " AND (activecalls.user_id = #{user_id} OR dst_usr.id = #{user_id} OR  activecalls.owner_id = #{user_id} OR dst_usr.owner_id = #{user_id})"
      else
        #user
        user_sql << " AND (activecalls.user_id = #{user_id} OR dst_usr.id = #{user_id}) "
      end
    end

    @show_did = current_user.active_calls_show_did?
    @ma_active = monitorings_addon_active?

    if user_id.to_s.blank?
      @active_calls = []
    else
      @active_calls = Activecall
        .select(
          "activecalls.id as ac_id, activecalls.channel as channel, activecalls.prefix, activecalls.server_id as server_id,
          activecalls.answer_time as answer_time, activecalls.src as src, activecalls.localized_dst as localized_dst, activecalls.uniqueid as uniqueid,
          activecalls.lega_codec as lega_codec,activecalls.legb_codec as legb_codec,activecalls.pdd as pdd,
          #{SqlExport.replace_price('activecalls.user_rate', {:reference => 'user_rate'})}, tariffs.currency as rate_currency,
          users.id as user_id, users.first_name as user_first_name, users.last_name as user_last_name, users.username as user_username, users.owner_id as user_owner_id,
          devices.id as 'device_id',devices.device_type as device_type, devices.name as device_name, devices.username as device_username, devices.extension as device_extension, devices.istrunk as device_istrunk, devices.ani as device_ani, devices.user_id as device_user_id,
          dst.id as dst_device_id,  dst.device_type as dst_device_type, dst.name as dst_device_name, dst.username as dst_device_username, dst.extension as dst_device_extension, dst.istrunk as dst_device_istrunk, dst.ani as dst_device_ani, dst.user_id as dst_device_user_id,
          dst_usr.id as dst_user_id, dst_usr.first_name as dst_user_first_name, dst_usr.last_name as dst_user_last_name, dst_usr.username as dst_user_username, dst_usr.owner_id as dst_user_owner_id,
          destinations.direction_code as direction_code, directions.name as direction_name, destinations.subcode as destination_subcode, destinations.name as destination_name,
          providers.id as provider_id, providers.name as provider_name, providers.common_use, providers.user_id as 'providers_owner_id', activecalls.did_id as did_id, dids.did as did, g.direction_code as did_direction_code,
          NOW() - activecalls.answer_time AS 'duration',
          IF(activecalls.answer_time IS NULL, 0, 1 ) as 'status',
          activecalls.card_id as cc_id, cards.number as cc_number, cards.owner_id as cc_owner_id"
        ).joins(
          'LEFT JOIN providers ON (providers.id =activecalls.provider_id)
          LEFT JOIN devices ON (devices.id = activecalls.src_device_id)
          LEFT JOIN devices AS dst ON (dst.id = activecalls.dst_device_id)
          LEFT JOIN users ON (users.id = devices.user_id)
          LEFT JOIN cards ON (cards.id = activecalls.card_id)
          LEFT JOIN users AS dst_usr ON (dst_usr.id = dst.user_id)
          LEFT JOIN tariffs ON (tariffs.id = users.tariff_id)
          LEFT JOIN destinations ON (destinations.prefix = activecalls.prefix)
          LEFT JOIN directions ON (directions.code = destinations.direction_code)
          LEFT JOIN dids ON (activecalls.did_id = dids.id)
          LEFT JOIN (SELECT * FROM (SELECT dids.did, destinations.direction_code FROM  dids
                      JOIN destinations on (prefix=SUBSTRING(dids.did, 1, LENGTH(prefix)))
                      JOIN activecalls ON (dids.id = activecalls.did_id)
                      ORDER BY LENGTH(destinations.prefix) DESC) AS v
                      GROUP BY did) AS g ON (g.did = dids.did)'
        ).where(user_sql)
        .order("#{@options[:order_by]} #{@options[:order_desc] == 1 ? 'DESC' : 'ASC'}")

      #search filter
      session[:active_calls_search] ||= {}
      if (params[:search_on] == "true")
        elements = [:s_user, :s_status, :s_country, :s_provider, :s_source, :s_destination]
        elements.each {|element| session[:active_calls_search][element] = params[element]}
      end
      search = session[:active_calls_search]

      if search[:s_user].present?
        @active_calls = @active_calls.where(user_id: search[:s_user])
      end
      if search[:s_country].present?
        direction =  Direction.where(name: search[:s_country]).first.code
        @active_calls = @active_calls.where('destinations.direction_code = ?', direction)
      end
      if search[:s_status].present?
        status = 'NOT' unless search[:s_status].to_i.zero?
        @active_calls = @active_calls.where("answer_time IS #{status} NULL")
      end
      if search[:s_provider].present?
        @active_calls = @active_calls.where('providers.id = ?', search[:s_provider])
      end
      if search[:s_source].present?
        @active_calls = @active_calls.where('activecalls.src LIKE ?', search[:s_source])
      end
      if search[:s_destination].present?
        @active_calls = @active_calls.where('activecalls.localized_dst LIKE ?', search[:s_destination])
      end
    end

    @chanspy_disabled = Confline.chanspy_disabled?


    @spy_device = Device.where("id = #{current_user.spy_device_id}").first

    #    sql2 = "SELECT activecalls.id, activecalls.server_id as server_id, activecalls.provider_id as provider_id, activecalls.user_id as user_id  FROM activecalls
    #    WHERE start_time < '#{nice_date_time(Time.now() - 7200)}'"
=begin
    sql2 = "SELECT activecalls.id, activecalls.server_id as server_id, activecalls.provider_id as provider_id, activecalls.user_id as user_id  FROM activecalls
    WHERE start_time < '#{Time.now() - 7200}'"


    calls = ActiveRecord::Base.connection.select_all(sql2)
    if calls
      MorLog.my_debug(sql2)
      sql3 = "DELETE activecalls.* FROM activecalls WHERE start_time < '#{nice_date_time(Time.now() - 7200)}'"
      ActiveRecord::Base.connection.delete(sql3)
      bt = Thread.new {active_calls_longer_error(calls)}
      #bt.join << kam kurt threada jei jo pabaigos yra laukiama ir nieko nedaroma laukimo metu?
    end
=end

    session[:active_calls_options] = @options
    render(partial: 'active_calls_show',
      locals: {active_calls: @active_calls, options: @options,
      show_did: @show_did, ma_active: @ma_active,
      chanspy_disabled: @chanspy_disabled,
      spy_device: @spy_device, user_id: @user_id, refresh_period: @refresh_period
    }) if params[:action].to_s == "active_calls_show"
  end

=begin

SELECT activecalls.start_time as start_time, activecalls.src as src, activecalls.dst as dst, users.id as user_id, users.first_name as user_first_name, users.last_name as user_last_name, devices.device_type as device_type, devices.name as device_name, devices.extension as device_extension, devices.istrunk as device_istrunk, devices.ani as device_ani, dst.id as dst_id, dst.device_type as dst_device_type, dst.name as dst_device_name, dst.extension as dst_device_extension, dst.istrunk as dst_device_istrunk, dst.ani as dst_device_ani, dst_usr.id as dst_user_id, dst_usr.first_name as dst_user_first_name, dst_usr.last_name as dst_user_last_name
FROM activecalls
LEFT JOIN providers ON (providers.id =activecalls.provider_id)
LEFT JOIN devices ON (devices.id = activecalls.src_device_id)
LEFT JOIN devices AS dst ON (dst.id = activecalls.dst_device_id)
LEFT JOIN users ON (users.id = devices.user_id)
LEFT JOIN users AS dst_usr ON (dst_usr.id = dst.user_id)
LEFT JOIN destinations ON (destinations.prefix = activecalls.prefix)
LEFT JOIN directions ON (directions.code = destinations.direction_code)

=end

  def active_calls_graph
    @page_title = _('active_calls_graph')
    @page_icon = 'call.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Active%20Calls%20Graph'
    @graph = {refresh_period: session[:active_calls_refresh_interval].to_i}

    create_graph_data_file
  end

  def update_active_calls_graph
    create_graph_data_file unless session[:active_calls_graph].present? && session[:active_calls_graph][:last_count].present?

    last_count = session[:active_calls_graph][:last_count].in_time_zone(user_tz)
    new_data = ActiveCallsData.find_from_timestamp(last_count)

    begin
      f = File.open("/home/mor/public/tmp/active_calls.csv", 'r')
    rescue
      create_graph_data_file
      f = File.open("#{Actual_Dir}/public/tmp/active_calls.csv", 'r')
    end

    if !new_data.blank? and ((Time.now - f.atime) >= session[:active_calls_refresh_interval].to_i.seconds - 1.second)
      new_last_count = new_data.last.time.in_time_zone(user_tz)

      csv_lines = f.read.split("\n")
      f.close

      # Replace yesterday's data wtih today's data if a day has passed
      if new_last_count.day != last_count.day
        # In case of long refresh rate finish filling today's data
        end_of_day = last_count.end_of_day
        yesterday_data = new_data.select {|data| data.time.in_time_zone(user_tz) < end_of_day}
        new_data -= yesterday_data
        unless yesterday_data.blank?
          yesterday_data.collect! {|data| [data.time.in_time_zone(user_tz).strftime('%H:%M:%S'), data.count]}
          yesterday_data.each do |data|
            hour, minute, second = data[0].split(':')
            second = @round_seconds.call(second.to_i)
            index = (hour.to_i * 3600 + minute.to_i * 60 + second.to_i)/15
            new_line = csv_lines[index].split(';')
            new_line[1] = data[1]
            csv_lines[index] = new_line.join(';')
          end
        end

        #Switch yesterday's data with today's data
        csv_lines.map! do |line|
          element = line.split(';')
          element[2] = element[1].to_s
          element[1] = ''
          element.join(';')
        end
      end

      new_data.collect! {|data| [data.time.in_time_zone(user_tz).strftime('%H:%M:%S'), data.count]}

      new_data.each do |data|
        hour, minute, second = data[0].split(':')
        second = @round_seconds.call(second.to_i)
        index = (hour.to_i * 3600 + minute.to_i * 60 + second.to_i)/15
        new_line = csv_lines[index].split(';')
        new_line[1] = data[1]
        new_line[2] = new_line[2].to_s
        csv_lines[index] = new_line.join(';')
      end

      session[:active_calls_graph][:last_count] = new_last_count

      f = File.open("/home/mor/public/tmp/active_calls.csv", 'w')
      f.write(csv_lines.join("\n"))
      f.close
    end
    render nothing: true
  end

  #=================== DIDs ===============================
  def dids
    @page_title = _('DIDs')
    @page_icon = "did.png"

    #method change_date_time uses params values. view doesn't return hours or mins, but it must be initialized due to Time Zone settings
    if [:date_from, :date_time].all? {|key| params[key].present?}
      params[:date_from][:hour] = 0
      params[:date_from][:minute] = 0
      params[:date_till][:hour] = 23
      params[:date_till][:minute] = 59
    end
    change_date

    @searching = params[:search_on].to_i == 1

    #saving search values
    session[:stats_dids_search] ||= {}
    session[:stats_dids_search][:user_id] = params[:s_user_id] if params[:s_user_id]
    session[:stats_dids_search][:provider_id] = params[:provider_id] if params[:provider_id]

    if params[:clear]
      change_date_to_present
      session[:stats_dids_search][:user_id] = -2
      session[:stats_dids_search][:provider_id] = -1
    end

    @users = User.find_all_for_select(corrected_user_id)
    @providers = Provider.where(['hidden=?', 0]).order("name ASC")

    @search_user = params[:s_user]
    @user_id = params[:s_user_id]

    (session[:stats_dids_search][:user_id]) ? (@user_id = session[:stats_dids_search][:user_id].to_i) : (@user_id = -2)
    user_sql = ''
    @provider_id = -1
    provider_sql = ''

    if session[:usertype] == "admin"
      if params[:s_user_id]
        if params[:s_user_id].to_i != -2 || params[:s_user].present?
          user_sql = " AND dids.user_id = '#{@user_id}' "
        end
      end
      if session[:stats_dids_search][:user_id]
        if session[:stats_dids_search][:provider_id].to_i != -1
          @provider_id = params[:provider_id]
          provider_sql = " AND dids.provider_id = '#{@provider_id}' "
        end
      end
    end

    #if params[:direction]
    #if params[:direction].to_s == "outgoing"
    # dir = "Local"
    #else
    dir = "Outside"
    #end
    #@direction = params[:direction]
    direction = '' #" AND calls.callertype = '#{dir}'"
    # end
    sql = "SELECT dids.*, SUM(calls.did_price) as did_price , SUM(calls.did_prov_price) as did_prov_price, SUM(calls.did_inc_price) as did_inc_price, COUNT(calls.id) as 'calls_size', providers.name, users.username, users.first_name, users.last_name, actions.date FROM dids
    JOIN calls on (calls.did_id = dids.id)
    JOIN providers on (dids.provider_id = providers.id)
    JOIN users on (dids.user_id = users.id)
    LEFT JOIN (SELECT data, date FROM actions JOIN (SELECT MAX(id) as id FROM actions WHERE actions.action like 'did_assigned%' group by actions.data)p ON (p.id = actions.id))actions on (dids.id = actions.data)
    WHERE calls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{user_sql.to_s + provider_sql.to_s + direction.to_s}  GROUP BY dids.id ORDER BY dids.user_id"
    # my_debug sql
    @res = @searching ? ActiveRecord::Base.connection.select_all(sql) : []
    @page = 1
    @page = params[:page].to_i if params[:page]

    @total_pages = (@res.size.to_d / session[:items_per_page].to_d).ceil
    @all_res = @res
    @res = []

    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_res.size - 1 if iend > (@all_res.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @res << @all_res[i]
    end
    if @direction.to_s == "outgoing"
      @dids_total_price = 0
      @dids_total_price_provider = 0
      @dids_total_profit = 0
      @dids_total_calls = 0
      for r in @res
        @dids_total_price += r['did_price'].to_d
        @dids_total_price_provider += r['did_prov_price'].to_d
        @dids_total_profit += r['did_price'].to_d - r['did_prov_price'].to_d
        @dids_total_calls += r['calls_size'].to_i
      end
    else
      @dids_total_price = 0
      @dids_total_price_provider = 0
      @dids_total_inc_price = 0
      @dids_total_profit = 0
      @dids_total_calls = 0
      for r in @res
        @dids_total_price += r['did_price'].to_d
        @dids_total_price_provider += r['did_prov_price'].to_d
        @dids_total_inc_price += r['did_inc_price'].to_d
        @dids_total_profit += r['did_price'].to_d + r['did_prov_price'].to_d # + r['did_inc_price'].to_d
        @dids_total_calls += r['calls_size'].to_i
      end
    end
  end

  #======================== SYSTEM STATS ======================================

  def system_stats
    @page_title = _('System_stats')
    @page_icon = "chart_pie.png"


    sql = "SELECT COUNT(users.id) as \'users\' FROM users"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_users = res[0]["users"].to_i

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.usertype = 'admin'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_admin = res[0]["users"].to_i

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.usertype = 'reseller'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_resellers = res[0]["users"].to_i

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.usertype = 'accountant'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_accountant = res[0]["users"].to_i

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.usertype = 'user'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_t_user = res[0]["users"].to_i

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.postpaid = '1'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_pospaid = res[0]["users"].to_i

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.postpaid = '0'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_prepaid = res[0]["users"].to_i

    sql = "SELECT COUNT(devices.id) as \'devices\' FROM devices"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_devices = res[0]["devices"].to_i

    @device_types = Devicetype.all

    @dev_types = []
    for type in @device_types
      sql = "SELECT COUNT(devices.id) as \'devices\' FROM devices WHERE devices.device_type = '#{type.name.to_s}'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @dev_types[type.id] = res[0]["devices"].to_i
    end

    sql = "SELECT COUNT(devices.id) as \'devices\' FROM devices WHERE devices.device_type = 'FAX'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @dev_types_fax = res[0]["devices"].to_i

    sql = "SELECT COUNT(tariffs.id) as \'tariffs\' FROM tariffs"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_tariffs = res[0]["tariffs"].to_i

    sql = "SELECT COUNT(tariffs.id) as \'tariffs\' FROM tariffs WHERE tariffs.purpose = 'provider'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_tariffs_provider = res[0]["tariffs"].to_i

    sql = "SELECT COUNT(tariffs.id) as \'tariffs\' FROM tariffs WHERE tariffs.purpose = 'user'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_tariffs_user = res[0]["tariffs"].to_i

    sql = "SELECT COUNT(tariffs.id) as \'tariffs\' FROM tariffs WHERE tariffs.purpose = 'user_wholesale'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_tariffs_user_wholesale = res[0]["tariffs"].to_i


    sql = "SELECT COUNT(providers.id) as \'providers\' FROM providers"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_providers = res[0]["providers"].to_i


    @provider_types = Providertype.all

    @prov_type =[]
    for type in @provider_types
      sql = "SELECT COUNT(providers.id) as \'providers\' FROM providers WHERE providers.tech = '#{type.name.to_s}'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @prov_type[type.id] = res[0]["providers"].to_i
    end

    sql = "SELECT COUNT(lcrs.id) as \'lcrs\' FROM lcrs"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_lrcs = res[0]["lcrs"].to_i

    sql = "SELECT COUNT(dids.id) as \'dids\' FROM dids"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_dids = res[0]["dids"].to_i

    sql = "SELECT COUNT(dids.id) as \'dids\' FROM dids WHERE dids.status = 'free'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_dids_free = res[0]["dids"].to_i

    sql = "SELECT COUNT(dids.id) as \'dids\' FROM dids WHERE dids.status = 'active'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_dids_active = res[0]["dids"].to_i

    sql = "SELECT COUNT(dids.id) as \'dids\' FROM dids WHERE dids.status = 'reserved'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_dids_reserved = res[0]["dids"].to_i

    sql = "SELECT COUNT(dids.id) as \'dids\' FROM dids WHERE dids.status = 'closed'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_dids_closed = res[0]["dids"].to_i

    sql = "SELECT COUNT(dids.id) as \'dids\' FROM dids WHERE dids.status = 'terminated'"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_dids_terminated = res[0]["dids"].to_i

    sql = "SELECT COUNT(directions.id) as \'directions\' FROM directions"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_directions = res[0]["directions"].to_i

    sql = "SELECT COUNT(destinations.id) as \'destinations\' FROM destinations"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_destinations = res[0]["destinations"].to_i

    sql = "SELECT COUNT(destinationgroups.id) as \'destinationgroups\' FROM destinationgroups"
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_dg = res[0]["destinationgroups"].to_i

    sql = 'SELECT COUNT(calls.id) as \'calls\' FROM calls'
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_calls = res[0]["calls"].to_i

    sql = 'SELECT COUNT(calls.id) as \'calls\' FROM calls WHERE calls.disposition = \'ANSWERED\' '
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_calls_anws = res[0]["calls"].to_i

    sql = 'SELECT COUNT(calls.id) as \'calls\' FROM calls WHERE calls.disposition = \'BUSY\' '
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_calls_busy = res[0]["calls"].to_i

    sql = 'SELECT COUNT(calls.id) as \'calls\' FROM calls WHERE calls.disposition = \'NO ANSWER\' '
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_calls_no_answ = res[0]["calls"].to_i

    @total_failet = @total_calls - @total_calls_anws - @total_calls_busy - @total_calls_no_answ

    sql = 'SELECT COUNT(cards.id) as \'cards\' FROM cards'
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_cards = res[0]["cards"].to_i

    sql = 'SELECT COUNT(cardgroups.id) as \'cardgroups\' FROM cardgroups'
    res = ActiveRecord::Base.connection.select_all(sql)
    @total_cards_grp = res[0]["cardgroups"].to_i
  end

  def dids_usage

    @page_title = _('DIDs_usage')
    @page_icon = "did.png"
    change_date
    @searching = params[:search_on].to_i == 1

    if @searching
      sql = "SELECT COUNT(DISTINCT actions.id) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action = 'did_closed'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @did_closed = res[0]["actions"].to_i

      sql = "SELECT COUNT(DISTINCT actions.id) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action = 'did_made_available'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @did_made_available = res[0]["actions"].to_i

      sql = "SELECT COUNT(DISTINCT actions.id) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action = 'did_reserved' AND actions.data2 = '0'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @did_reserved = res[0]["actions"].to_i

      sql = "SELECT COUNT(DISTINCT actions.id) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action = 'did_created'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @did_created = res[0]["actions"].to_i

      sql = "SELECT COUNT(DISTINCT actions.data) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action ='did_assigned_to_dp'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @did_assigned1 = res[0]["actions"].to_i

      sql = "SELECT COUNT(DISTINCT actions.data) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action ='did_assigned'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @did_assigned2 = res[0]["actions"].to_i

      @did_assigned= @did_assigned1 + @did_assigned2

      sql = "SELECT COUNT(DISTINCT actions.data) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action ='did_deleted'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @did_deleted = res[0]["actions"].to_i

      sql = "SELECT COUNT(DISTINCT actions.data) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action ='did_terminated'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @did_terminated = res[0]["actions"].to_i
    end

    @free = Did.free.count
    @reserved = Did.reserved.count
    @active = Did.active.count
    @closed = Did.closed.count
    @terminated = Did.terminated.count
  end

  # Prefix Finder ################################################################
  def prefix_finder
    redirect_to :action => 'search' and return false
  end

  def search
    @page_title = _('Dynamic_Search')
    @page_icon = "magnifier.png"
  end

  def prefix_finder_find
    @phrase = params[:prefix].gsub(/[^\d]/, '') if params[:prefix]
    @callshop = params[:callshop].to_i
    @dest = Destination.where(prefix: @phrase).
                        order("LENGTH(destinations.prefix) DESC").first if @phrase != ''
    @flag = nil
    if @dest == nil
      @results = ''
    else
      @flag = @dest.direction_code
      direction = @dest.direction
      @dg = @dest.destinationgroup
      @results = @dest.subcode.to_s+" "+@dest.name.to_s
      @results = direction.name.to_s+" "+ @results if direction
      @flag2 = @dg.flag if @dg
      @results2 = "#{_('Destination_group')} : " + @dg.name.to_s if @dg

      if @callshop.to_i > 0
        sql = "SELECT position, user_id , users.tariff_id, gusertype from usergroups
               left join users on users.id = usergroups.user_id
                left join tariffs on tariffs.id = users.tariff_id where group_id = #{@callshop.to_i}"
        @booths = Usergroup.find_by_sql(sql)
        @rates = @dest.find_rates_and_tariffs(correct_owner_id, '', @callshop)
      else
        user_tariff = session[:tariff_id].to_i if user?
        @rates = @dest.find_rates_and_tariffs(correct_owner_id, user_tariff)
      end

    end
    render(:layout => false)
  end

  def prefix_finder_find_country
    @phrase = params[:prefix].gsub(/['"]/, '') if params[:prefix]
    @dirs = Direction.where(["SUBSTRING(name, 1, LENGTH(?)) = ?", @phrase, @phrase]) if @phrase and @phrase.length > 1
    render(:layout => false)
  end

  def rate_finder_find
    if params[:prefix]
      @phrase = params[:prefix].to_s.gsub(/[^\d]/, '') if params[:prefix]
      phrase = []
      arr = @phrase.to_s.split('') if @phrase
      arr.size.times { |i| phrase << arr[0..i].join() }

      @dest = Destination.where("prefix in (#{phrase.join(",")})").order("prefix desc") if phrase.size > 0
      id_string = []
      @dest.each { |d| id_string << d.id } if @dest
      user_tariff = session[:tariff_id].to_i if user?
      @rates = Stat.find_rates_and_tariffs_by_number(correct_owner_id, id_string, phrase, user_tariff) if id_string.size > 0
    end

    render(:layout => false)
  end

  def ip_finder_find
    if params[:ip]
      ip = params[:ip].to_s.strip

      if ip.present?
      valid_ip_format = ip.match(/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/) ? true : false

        if valid_ip_format
          @users_scope = ActiveRecord::Base.connection.select_values("SELECT id FROM users WHERE (owner_id = #{current_user.id} AND usertype != 'reseller') or id = #{current_user.id}")
          users_scope = @users_scope.collect(&:to_i).to_s.gsub("[", "(").gsub("]", ")")

          # searching devices
          conditions = "ipaddr LIKE '#{ip}%' AND user_id != -1"
          conditions += " AND user_id IN #{users_scope}"if reseller?
          @devices = Device.where(conditions).order('device_type, name').all

          # searching providers
          conditions = "server_ip LIKE '#{ip}%'"
          conditions += " AND user_id = #{current_user.id}" if reseller?
          @providers = Provider.where(conditions).order('name, device_id').all
        end
      end
    end

    render(:layout => false)
  end

  # GOOGLE MAPS ##################################################################
  def google_maps
    @page_title = _('Google_Maps')
    @page_icon = "world.png"

    @devices = Device.joins(:user).where("users.owner_id = #{current_user.id} AND name NOT LIKE 'mor_server%' AND ipaddr > 0 AND ipaddr != '0.0.0.0' AND user_id > -1
    AND '192.168.' != SUBSTRING(ipaddr, 1, LENGTH('192.168.'))
    AND '10.' != SUBSTRING(ipaddr, 1, LENGTH('10.'))
    AND ((CAST(SUBSTRING(ipaddr, 1,6) AS DECIMAL(6,3)) > 172.31)
    or (CAST(SUBSTRING(ipaddr, 1,6) AS DECIMAL(6,3)) < 172.16))").all
    @providers = Provider.where("user_id = #{current_user.id} AND server_ip > 0 AND server_ip != '0.0.0.0' AND hidden = 0").all
    @servers = Server.where("server_ip > 0 AND server_ip != '0.0.0.0'").all
    session[:google_active] = 0
  end

  def google_active
    if session[:usertype] == "admin"
      @calls = Activecall.includes(:provider).all
    else
      @calls = Activecall.includes(:provider).where("owner_id = #{current_user.id}").all
    end
  end

  def hangup_cause_codes_stats

    #ticket 5672 only if reseller pro addon is active, reseller that has own providers can access
    #hangup cause statistics page.
    if reseller? and !current_user.reseller_allowed_to_view_hgc_stats?
      dont_be_so_smart
      redirect_to :root and return false
    end

    @page_title = _('Hangup_cause_codes_stats')
    @page_icon = "chart_pie.png"

    change_date
    @searching = params[:search_on].to_i == 1

    session[:hour_from] = "00"
    session[:minute_from] = "00"
    session[:hour_till] = "23"
    session[:minute_till] = "59"

    if params[:back]
      @back = params[:back]
      if params[:back].to_i == 2
        @direction = Direction.where(["code=?", params[:country_code]]).first
        @country_id = @direction.id
      end
    end

    if params[:s_user].to_s == ''
      params[:s_user_id] = -1
    elsif %w[-2 -1].include?(params[:s_user_id].to_s)
      params[:s_user_id] = -2
    end

    @user_id = params[:s_user_id] ? params[:s_user_id].to_i : -1
    @device_id = params[:s_device] ? params[:s_device].to_i : -1
    @provider_id = params[:provider_id] ? params[:provider_id].to_i : -1
    @country_id = params[:country_id] ? params[:country_id].to_i : -1

    if params[:provider_id] and params[:provider_id].to_i != -1
      @provider = current_user.providers.where({:id => params[:provider_id]}).first
      unless @provider
        dont_be_so_smart
        redirect_to :root and return false
      end
    end

    if params[:s_user_id] && ![-2, -1].include?(params[:s_user_id].to_i)
      @user = User.where({:id => params[:s_user_id]}).first
      unless @user
        dont_be_so_smart
        redirect_to :root and return false
      end
    end

    @country = Direction.where(["id = ?", @country_id]).first if @country_id.to_i > -1
    if params[:direction_code]
      @country = Direction.where(["code = ?", params[:direction_code].strip]).first
    end
    @code = @country.code if @country

    @providers = current_user.load_providers({conditions: 'hidden=0', order: 'name ASC'})
    @countries = Direction.order("name ASC")
    search_from = limit_search_by_days
    @calls, @Calls_graph, @hangupcusecode_graph, @calls_size = @searching ? Call.hangup_cause_codes_stats({:provider_id => @provider_id, :device_id => @device_id, :country_code => @code, :user_id => @user_id, :current_user => current_user, :a1 => search_from, :a2 => session_till_datetime}) : {}
  end

  def calls_by_scr
    @page_title = _('Calls_by_src')
    @page_icon = "chart_pie.png"
    @searching = params[:search_on].to_i == 1

    cond=""
    des = ''
    descond=''
    descond1=''
    @prov = -1
    @coun = -1

    if params[:country_id]
      @country_id = params[:country_id]
    end

    if params[:provider_id]
      if params[:provider_id].to_i != -1
        @provider = Provider.find(params[:provider_id])
        cond +=" ((hcalls.provider_id = #{q params[:provider_id]} and hcalls.callertype = 'Local') OR (hcalls.did_provider_id = #{q params[:provider_id]} and hcalls.callertype = 'Outside')) AND "
        @prov = @provider.id
      end
    end
    @providers = Provider.where(['hidden=?', 0]).order('name ASC')


    if @country_id
      if @country_id.to_i != -1
        @country = Direction.find(@country_id)
        @coun = @country.id
        des+= 'destinations, '
        descond +=" AND directions.code ='#{@country.code}' "
        descond1 +=" AND destinations.direction_code ='#{@country.code}' "
      end
    end
    @countries = Direction.order("name ASC")

    change_date

    session[:hour_from] = "00"
    session[:minute_from] = "00"
    session[:hour_till] = "23"
    session[:minute_till] = "59"

    if @searching
      sql= "SELECT directions.name, des.direction_code, des.name as 'des_name',  des.prefix, des.subcode, count(hcalls.id) as 'calls' FROM directions
      JOIN destinations as des on (des.direction_code = directions.code)
      JOIN calls as hcalls on (hcalls.prefix = des.prefix)
      WHERE #{cond} hcalls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{descond} AND LENGTH(src) >= 10 group by des.id"
      @res = ActiveRecord::Base.connection.select_all(sql)

      sql= "SELECT directions.name, directions.code, count(hcalls.id) as 'calls' FROM directions
      JOIN destinations as des on (des.direction_code = directions.code)
      JOIN calls as hcalls on (hcalls.prefix = des.prefix)
      WHERE #{cond} hcalls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{descond} AND LENGTH(src) >= 10 group by directions.id"
      @res3 = ActiveRecord::Base.connection.select_all(sql)

      sql= "SELECT count(hcalls.id) as 'calls' FROM destinations
      JOIN calls as hcalls on (hcalls.prefix = destinations.prefix)
      WHERE #{cond} hcalls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{descond1} AND LENGTH(src) < 10 "
      @res2 = ActiveRecord::Base.connection.select_all(sql)
    end
  end

  def resellers
    @page_title = _('Resellers')
    @page_icon = "user_gray.png"

  #The following if statement is required for rs, rs_pro addons limitation. #8466
  order = 'ORDER BY nice_user ASC'
  if reseller_pro_active?
    conditions = order
  elsif not reseller_active?
    first_reseller = User.where(own_providers: 0, usertype: 'reseller').first
    first_reseller_pro = User.where(own_providers: 1).first

    conditions = []
    conditions << "users.id = #{first_reseller.id}" if first_reseller
    conditions << "users.id = #{first_reseller_pro.id}" if first_reseller_pro
    conditions = 'AND (' + conditions.join(' OR ') + ')' + order
    conditions = ' LIMIT 0 ' if not first_reseller and not first_reseller_pro
  else
    first_reseller_pro = User.where(own_providers: 1).first

    conditions = ["own_providers = 0"]
    conditions << "users.id = #{first_reseller_pro.id}" if first_reseller_pro
    conditions = 'AND (' + conditions.compact.join(' or ') + ')' + order
  end

  sql = "select users.id, users.username, users.first_name, users.last_name, s_calls.calls as 'f_calls', s_tariffs.tariffs as 'f_tariffs', s_cardgroups.cardgroups as 'f_cardgroups', s_cards.cards as 'f_cards', s_users.users as 'f_users', s_devices.devices as 'f_devices', acc_groups.name as 'group_name', acc_groups.id as 'group_id', s_dids.dids as f_dids, #{SqlExport.nice_user_sql}, own_providers
        from users
        LEFT JOIN acc_groups ON (users.acc_group_id = acc_groups.id)
        left join (SELECT COUNT(calls.id) as 'calls', reseller_id FROM calls group by calls.reseller_id) as s_calls on(s_calls.reseller_id = users.id)
        left join (SELECT COUNT(tariffs.id) as 'tariffs', owner_id FROM tariffs group by tariffs.owner_id) as s_tariffs on(s_tariffs.owner_id = users.id)
        left join (SELECT COUNT(cardgroups.id) as 'cardgroups', owner_id FROM cardgroups group by cardgroups.owner_id) as s_cardgroups on(s_cardgroups.owner_id = users.id)
        left join (SELECT COUNT(cards.id) as 'cards', owner_id FROM cards group by cards.owner_id) as s_cards on(s_cards.owner_id = users.id)
        left join (SELECT COUNT(users.id) as 'users', owner_id FROM users group by users.owner_id) as s_users on(s_users.owner_id = users.id)
        left join (SELECT COUNT(devices.id) as 'devices', users.owner_id FROM devices
                          left join users on (devices.user_id = users.id)
                          where users.owner_id > 0 group by users.owner_id) as s_devices on(s_devices.owner_id = users.id)
        left join (SELECT COUNT(dids.id) AS 'dids', reseller_id FROM dids GROUP BY dids.reseller_id) AS s_dids ON(s_dids.reseller_id = users.id)
        where users.usertype = 'reseller' and users.hidden = 0
        #{conditions}"
  #my_debug sql
    @resellers = User.find_by_sql(sql)
  end


  def calls_per_day
    @page_title = _('Calls_per_day')
    @page_icon = "chart_bar.png"
    @searching = params[:search_on].to_i == 1

    cond=''
    des = ''
    des2 = ''
    des3 = ''
    @prov = -1
    @coun = -1
    @user_id = -1
    @directions = -1

    up, rp, pp = current_user.get_price_calculation_sqls
    if params[:country_id]
      @country_id = params[:country_id]
    end

    if params[:provider_id]
      if params[:provider_id].to_i != -1
        @provider = Provider.where(:id => params[:provider_id]).first
        @prov = @provider.id
        cond +=" (calls.provider_id = '#{params[:provider_id].to_i}' OR calls.did_provider_id = '#{params[:provider_id].to_i}') AND "
      end
    end
    @providers = Provider.where(:hidden => 0).order('name ASC').all

    if params[:s_user_id]
      # -1 find all users, -2 find nothing
      if params[:s_user].to_s == ''
        params[:s_user_id] = -1
      elsif %w[-2 -1].include?(params[:s_user_id].to_s)
        params[:s_user_id] = -2
      end

      if params[:s_user_id].to_i != -1
        @user = User.where(:id => params[:s_user_id]).first
        cond +=" calls.user_id = '#{@user.try(:id) || -2}' AND "
        @user_id = @user.try(:id) || -2
      end
    end

    if params[:reseller_id]
      if params[:reseller_id].to_i != -1
        @reseller = User.where(:id => params[:reseller_id]).first
        cond +=" calls.reseller_id = '#{@reseller.id}' AND "
        @reseller_id = @reseller.id
      end
    end
    @resellers = User.where(:usertype => "reseller").order('first_name ASC').all

    if params[:direction]
      if params[:direction].to_i != -1
        if params[:direction].to_s == "Incoming"
          cond +=" calls.did_id > 0 AND "
        else
          cond +=" calls.did_id = 0 AND "
        end
        @direction = params[:direction]
      end
    end
    owner_id = correct_owner_id
    if owner_id != 0
      cond += " reseller_id ='#{owner_id}' AND "
    end

    if @country_id
      if @country_id.to_i != -1
        @country = Direction.where(:id => @country_id).first
        @coun = @country.id
        des3 += "destinations JOIN"
        des2 += "ON (calls.prefix = destinations.prefix)"
        des +=" AND destinations.direction_code ='#{@country.code}' "
      end
    end
    @countries = Direction.order("name ASC").all

    change_date

    calldate = "(calls.calldate + INTERVAL #{current_user.time_offset} SECOND)"

    session[:hour_from] = "00"
    session[:minute_from] = "00"
    session[:hour_till] = "23"
    session[:minute_till] = "59"

    if @searching
      sql = "SELECT EXTRACT(YEAR FROM #{calldate}) as year, EXTRACT(MONTH FROM #{calldate}) as month, EXTRACT(day FROM #{calldate}) as day, Count(calls.id) as 'calls' , SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) as 'duration', SUM(#{up}) as 'user_price', SUM(#{rp}) as 'resseler_price', SUM(#{pp} - calls.did_prov_price) as 'provider_price', SUM(IF(disposition!='ANSWERED',1,0)) as 'fail'  FROM
      #{des3} calls #{des2} #{SqlExport.left_join_reseler_providers_to_calls_sql}
      WHERE #{cond} calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{des}
      GROUP BY year, month, day"
      @res = ActiveRecord::Base.connection.select_all(sql)

      sql_total = "SELECT  Count(calls.id) as 'calls' , SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) as 'duration', SUM(#{up}) as 'user_price', SUM(#{rp}) as 'resseler_price', SUM(#{pp} - calls.did_prov_price) as 'provider_price', SUM(IF(disposition!='ANSWERED',1,0)) as 'fail'  FROM
      #{des3} calls #{des2} #{SqlExport.left_join_reseler_providers_to_calls_sql}
      WHERE #{cond} calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{des}"
      @res_total = ActiveRecord::Base.connection.select_all(sql_total)
    end
  end

  def first_activity
    @page_title = _('First_activity')
    @page_icon = "chart_bar.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/First_Activity"

    change_date

    @size = Action.set_first_call_for_user(session_from_date, session_till_date)

    @total_pages = (@size.to_d / session[:items_per_page].to_d).ceil

    @page = 1
    @page = params[:page].to_i if params[:page]
    @page = @total_pages.to_i if params[:page].to_i > @total_pages
    @page = 1 if params[:page].to_i < 0

    @fpage = ((@page -1) * session[:items_per_page]).to_i


=begin
    sql = "SELECT calldate, user_id, card_id, c.sb, users.first_name, users.last_name, users.username
           FROM calls
              LEFT JOIN
                (SELECT COUNT(subscriptions.id) AS sb, subscriptions.user_id AS su_id
                  FROM subscriptions WHERE ((activation_start < '#{a1}' AND activation_end BETWEEN '#{a1}' AND '#{a2}') OR (activation_start BETWEEN '#{a1}' AND '#{a2}' AND activation_end < '#{a2}') OR (activation_start > '#{a1}' AND activation_end < '#{a2}') OR (activation_start < '#{a1}' AND activation_end > '#{a2}')) GROUP BY subscriptions.user_id) AS c on (c.su_id = calls.user_id )
              LEFT JOIN users on (users.id = calls.user_id)
           WHERE calldate < '#{session_till_datetime}' AND calls.user_id != -1
           GROUP BY user_id
           ORDER BY calldate ASC
           LIMIT #{@fpage}, #{@tpage}"
=end
    #my_debug sql

    #    sql3 = "SELECT actions.date as 'calldate', actions.data2 as 'card_id', c.sb, users.first_name, users.last_name, users.username, users.id, actions.user_id FROM users
    #              JOIN actions ON  (actions.user_id = users.id)
    #              LEFT JOIN
    #                (SELECT COUNT(subscriptions.id) AS sb, subscriptions.user_id AS su_id
    #                  FROM subscriptions WHERE ((activation_start < '#{a1}' AND activation_end BETWEEN '#{a1}' AND '#{a2}') OR (activation_start BETWEEN '#{a1}' AND '#{a2}' AND activation_end < '#{a2}') OR (activation_start > '#{a1}' AND activation_end < '#{a2}') OR (activation_start < '#{a1}' AND activation_end > '#{a2}')) GROUP BY subscriptions.user_id) AS c on (c.su_id = users.id )
    #              WHERE actions.action = 'first_call' and actions.date BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'
    #              GROUP BY user_id
    #           ORDER BY date ASC
    #           LIMIT #{@fpage}, #{session[:items_per_page].to_i}"

    sql3= "SELECT actions.date as 'calldate', actions.data2 as 'card_id', users.first_name, users.last_name, users.username, users.id, actions.user_id FROM users
                  JOIN actions ON  (actions.user_id = users.id)
           WHERE actions.action = 'first_call' and actions.date BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'
           GROUP BY user_id
           ORDER BY date ASC
           LIMIT #{@fpage}, #{session[:items_per_page].to_i}"
    @res = ActiveRecord::Base.connection.select_all(sql3)


    #    @all_res = @res
    #    @res = []
    #
    #    iend = ((session[:items_per_page] * @page) - 1)
    #    iend = @all_res.size - 1 if iend > (@all_res.size - 1)
    #    for i in ((@page - 1) * session[:items_per_page])..iend
    #      @res << @all_res[i]
    #    end
    #
    #
    #    @subscriptions = 0
    #    @user = []
    #    for r in @res
    #      @subscriptions+= r['sb'].to_i
    #      if (r['user_id'].to_i != -1) and (r['user_id'].to_s != "") and (r['card_id'].to_i == 0 )
    #        user = User.find(:first, :conditions => "id = #{r['user_id']}") if r['user_id'].to_s.length >= 0
    #        @user[r['user_id'].to_i] = user if r['user_id'].to_i >= 0
    #      end
    #    end
  end


  def subscriptions_stats
    @page_title = _('Subscriptions')
    @page_icon = "chart_bar.png"

    session[:subscriptions_stats_options] ? @options = session[:subscriptions_stats_options] : @options = {}
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (@options[:order_by] = 'user' if !@options[:order_by])
    @options[:order] = Subscription.subscriptions_stats_order_by(@options)

    change_date
    a1 = session_from_date
    a2 = session_till_date
    @date_from = session_from_date
    sql = "SELECT COUNT(subscriptions.id) AS sub_size  FROM subscriptions
    WHERE ((activation_start < '#{a1}' AND activation_end BETWEEN '#{a1}' AND '#{a2}') OR (activation_start BETWEEN '#{a1}' AND '#{a2}' AND activation_end < 'a2') OR (activation_start > '#{a1}' AND activation_end < '#{a2}') OR (activation_start < '#{a1}' AND activation_end > '#{a2}'))"
    @res = ActiveRecord::Base.connection.select_all(sql)
    sql = "SELECT COUNT(subscriptions.id) AS sub_size  FROM subscriptions
    WHERE activation_start = '#{a1}'"
    @res2 = ActiveRecord::Base.connection.select_all(sql)
    @res3 = Subscription.select("users.id, users.username, users.first_name, users.last_name, CONCAT(users.first_name, ' ', users.last_name) AS nice_user, activation_start, activation_end, added, subscriptions.id AS subscription_id, memo, services.name, services.name AS service_name, services.price AS service_price, services.servicetype AS servicetype, services.quantity, subscriptions.no_expire AS no_expire,  #{SqlExport.nice_user_sql}").where("((activation_start < '#{a1}' AND activation_end BETWEEN '#{a1}' AND '#{a2}') OR (activation_start BETWEEN '#{a1}' AND '#{a2}' AND activation_end < 'a2') OR (activation_start > '#{a1}' AND activation_end < '#{a2}') OR (activation_start < '#{a1}' AND activation_end > '#{a2}'))").joins("JOIN users on (subscriptions.user_id = users.id) JOIN services on (services.id = subscriptions.service_id)").order(@options[:order])

    params[:page] ? @page = params[:page].to_i : (@options[:page] ? @page = @options[:page] : @page = 1)
    @total_pages = (@res3.size.to_d / session[:items_per_page].to_d).ceil

    @all_res = @res3
    @res3 = []

    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_res.size - 1 if iend > (@all_res.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @res3 << @all_res[i]
    end
    @options[:page] = @page
    session[:subscriptions_stats_options] = @options
  end

  def subscriptions_first_day
    @page_title = _('First_day_subscriptions')
    @page_icon = "chart_bar.png"

    @date = session_from_date
    sql = "SELECT users.id, users.username, users.first_name, users.last_name FROM users
    JOIN (SELECT users.id AS suser_id, subscriptions.id as sub_id FROM users
    JOIN subscriptions ON (subscriptions.user_id = users.id AND subscriptions.activation_start BETWEEN '#{@date} 01:01:01' AND '#{@date} 23:59:59')
    GROUP BY users.id) as a on (users.id != a.suser_id )
    where users.owner_id='#{session[:user_id]}' and users.hidden = 0"
    @res = ActiveRecord::Base.connection.select_all(sql)
    if @res.size.to_i == 0
      sql = "SELECT users.id, users.username, users.first_name, users.last_name FROM users
      where users.owner_id='#{session[:user_id]}' and users.hidden = 0"
      @res = ActiveRecord::Base.connection.select_all(sql)
    end
    @page = 1
    @page = params[:page].to_i if params[:page]

    @total_pages = (@res.size.to_d / session[:items_per_page].to_d).ceil

    @all_res = @res
    @res = []

    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_res.size - 1 if iend > (@all_res.size - 1)
    for i in ((@page - 1) * session[:items_per_page])..iend
      @res << @all_res[i]
    end

  end

  def action_log
    @page_title = _('Action_log')
    @page_icon = "chart_bar.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Action_log"
    @searching = params[:search_on].to_i == 1
    @reviewed_labels = [[_('All'), -1], [_('Reviewed').downcase, 1], [_('Not_reviewed').downcase, 0]]

    if session[:usertype] == 'user'
      dont_be_so_smart
      redirect_to :root and return false
    end

    change_date

    a1 = session_from_datetime
    a2 = session_till_datetime

    session[:action_log_stats_options] ? @options = session[:action_log_stats_options] : @options = {:order_by => "action", :order_desc => 0, :page => 1}

    # search paramaters
    params[:page] ? @options[:page] = params[:page].to_i : (params[:clean]) ? @options[:page] = 1 : (@options[:page] = 1 if !@options[:page])
    params[:action_type] ? @options[:s_type] = params[:action_type].to_s : (params[:clean]) ? @options[:s_type] = "all" : (@options[:s_type]) ? @options[:s_type] = session[:action_log_stats_options][:s_type] : @options[:s_type] = "all"

    # -1 find all users; -2 find nothing
    if params[:s_user].to_s == ''
      params[:s_user_id] = -1
    elsif %w[-2 -1].include?(params[:s_user_id].to_s)
      params[:s_user_id] = -2
    end
    (params[:s_user_id] and !params[:s_user_id].blank?) ? @options[:s_user] = params[:s_user_id].to_s : (params[:clean]) ? @options[:s_user] = -1 : (@options[:s_user]) ? @options[:s_user] = session[:action_log_stats_options][:s_user] : @options[:s_user] = -1

    params[:processed] ? @options[:s_processed] = params[:processed].to_s : (params[:clean]) ? @options[:s_processed] = -1 : (@options[:s_processed]) ? @options[:s_processed] = session[:action_log_stats_options][:s_processed] : @options[:s_processed] = -1
    #params[:s_int_ch]   ? @options[:s_int_ch] = params[:s_int_ch].to_i     : (params[:clean]) ? @options[:s_int_ch] = 0   : (@options[:s_int_ch])? @options[:s_int_ch] = session[:action_log_stats_options][:s_int_ch] : @options[:s_int_ch] = 0
    params[:target_type] ? @options[:s_target_type] = params[:target_type].to_s : (params[:clean]) ? @options[:s_target_type] = '' : (@options[:s_target_type]) ? @options[:s_target_type] = session[:action_log_stats_options][:s_target_type] : @options[:s_target_type] = ''
    params[:target_id] ? @options[:s_target_id] = params[:target_id].to_s : (params[:clean]) ? @options[:s_target_id] = '' : (@options[:s_target_id]) ? @options[:s_target_id] = session[:action_log_stats_options][:s_target_id] : @options[:s_target_id] = ''
    params[:did] ? @options[:s_did] = params[:did].to_s : (params[:clean]) ? @options[:s_did] = '' : (@options[:s_did]) ? @options[:s_did] = session[:action_log_stats_options][:s_did] : @options[:s_did] = ''

    change_date_to_present if params[:clean]

    t = current_user.user_time(Time.now)
    year, month, day = t.year.to_s, t.month.to_s, t.day.to_s
    from = session_from_datetime_array != [year, month, day, "0", "0", "00"]
    till = session_till_datetime_array != [year, month, day, "23", "59", "59"]

    @options[:search_on] = (from or till) ? 1 : 0

    # order
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 1 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : @options[:order_by] == "acc"
    order_by = Action.actions_order_by(@options)

    @res = Action.select("DISTINCT(actions.action)").order("actions.action").all
    @did = Did.where("did = '#{@options[:s_did]}'").first if !@options[:s_did].blank?
    @options[:s_did] = @did.id  if !@did.blank?

    if @searching
      cond, cond_arr, join = Action.condition_for_action_log_list(current_user, a1, a2, params[:s_int_ch], @options)
      # page params
      @ac_size = Action.count(:all, :conditions => [cond.join(" AND ")] + cond_arr, :joins => join, :select => "actions.id")
      @not_reviewed_actions = Action.where([(['processed = 0'] + cond).join(" AND ")] + cond_arr).joins(join).limit(1).size.to_i == 1
      @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
      @total_pages = (@ac_size.to_d / session[:items_per_page].to_d).ceil
      @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
      fpage = ((@options[:page] -1) * session[:items_per_page]).to_i
      @search = 1
      # search
      @actions = Action.select(" actions.*, users.username, users.first_name, users.last_name ").
                        where([cond.join(" AND ")] + cond_arr).
                        joins(join).
                        order(order_by).
                        limit("#{fpage}, #{session[:items_per_page].to_i}")
    end
    @options[:s_did] = @did.did  if !@did.blank?
    session[:action_log_stats_options] = @options
  end

  def action_log_mark_reviewed
    a1 = session_from_datetime
    a2 = session_till_datetime
    session[:action_log_stats_options] ? @options = session[:action_log_stats_options] : @options = {:order_by => "action", :order_desc => 0, :page => 1}
    cond, cond_arr, join = Action.condition_for_action_log_list(current_user, a1, a2, 0, @options)
    @actions = Action.select(" actions.*").
                      where([cond.join(" AND ")] + cond_arr).
                      joins(join)

    if @actions
      @actions.each { |a|
        if a.processed == 0
          a.processed = 1
          a.save
        end
      }
    end
    flash[:status] = _('Actions_marked_as_reviewed')
    redirect_to :action => :action_log, :search_on => 1
  end

  def action_processed
    action = Action.find(params[:id])
    action.toggle_processed
    @user = params[:user].to_s
    @action = params[:s_action]
    @processed = params[:procc]
    flash[:status] = _('Action_marked_as_reviewed')
    redirect_to :action => "action_log", :user_id => @user, :processed => @processed, :action_type => @action, :search_on => 1
  end

  def load_stats
    @page_title = _('Load_stats')
    @page_icon = "chart_bar.png"
    @searching = params[:search_on].to_i == 1

    @providers = current_user.providers.where(['hidden=?', 0])
    @resellers = User.where('usertype = "reseller"')
    if current_user.usertype != 'reseller'
      @dids = Did.all
      @servers = Server.all
    end

    @default = {:s_user => -1, :s_provider => -1, :s_device => -1, :s_direction => -1, :s_server => -1, :s_reseller => -1}
    session[:stats_load_stats_options] ? @options = session[:stats_load_stats_options] : @options = @default

    # -1 find all users, -2 find nothing
    if params[:s_user].to_s == ''
      params[:s_user_id] = -1
    elsif %w[-2 -1].include?(params[:s_user_id].to_s)
      params[:s_user_id] = -2
    end
    @options[:s_user] = params[:s_user_id] if params[:s_user_id]
    @devices = Device.where(user_id: params[:s_user_id]).all if params[:s_user_id].to_i >= 0
    @options[:s_reseller] = params[:s_reseller] if params[:s_reseller]
    @options[:s_did] = params[:s_did] if params[:s_did] and current_user.usertype != 'reseller'
    @options[:s_device] = params[:device_id] if params[:device_id]
    @options[:s_provider] = params[:s_provider] if params[:s_provider]
    @options[:s_direction] = params[:s_direction] if params[:s_direction]
    @options[:s_server] = params[:s_server] if params[:s_server] and current_user.usertype != 'reseller'

    if @searching

      change_date_from

      session[:year_till] = session[:year_from]
      session[:month_till] = session[:month_from]
      session[:day_till] = session[:day_from]
      session[:hour_from] = "00"
      session[:minute_from] = "00"
      session[:hour_till] = "23"
      session[:minute_till] = "59"

      @options[:a1] = limit_search_by_days
      @options[:a2] = session_till_datetime

      @options[:current_user] = current_user

      @calls_answered, @calls_all, highest_duration = Call.calls_for_laod_stats(@options)

      n = 1440
      min1 =[]
      min2 =[]
      (0..n).each do |i|
        min1[i]=0
        min2[i]=0
      end

      if @calls_all.count >0
        @calls_all.each do |call|
          h = call.calldate.strftime("%H")
          m = call.calldate.strftime("%M")
          h = h.to_i * 60
          m = h.to_i + m.to_i
          min2[m.to_i]+=1
        end
      end

      if @calls_answered.count >0
        @calls_answered.each do |call|
          h = call.calldate.strftime("%H")
          m = call.calldate.strftime("%M")
          h = h.to_i * 60
          m = h.to_i + m.to_i
          #min2[m]+=1
          d = call.duration.to_i / 60
          if (call.duration.to_i % 60) > 0
            d += 1
          end
          from = m.to_i
          to = from + d
          to = 1339 if to >= 1440
          (from..to).each do |index|
            min1[index] += 1
          end
        end
      end


      @Call_answered_graph= ''
      (0..n).each do |minute|
        h2 = (minute / 60)
        m2 = (minute % 60)
        time = Time.mktime(session[:year_from], session[:month_from], session[:day_from], h2, m2, 0).strftime("%H:%M")
        @Call_answered_graph << "#{time};#{min1[minute]};#{min2[minute]}\\n"
      end

      if highest_duration.to_i > 36000
        flash[:notice] = _('db_error_broken_call_duration')
      end
    end
  end

  def truncate_active_calls
    if admin?
      Activecall.delete_all
      redirect_to :controller => "stats", :action => "active_calls" and return false
    else
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def server_load

    @page_title = _('server_load_stats')
    @page_icon  = 'chart_bar.png'
    @help_link  = 'http://wiki.kolmisoft.com/index.php/Server_load_stats'

    @cache = Proc.new do |param|
      if params[:date].blank?
        Time.now.send(param).to_i
      else
        params[:date].try(:[], param).to_i
      end
    end

    @common_stats = ['hdd_util','cpu_general_load','cpu_loadstats1']

    params[:id] = params[:server] if params[:server]
    @server     = params[:id].blank? ? Server.first : Server.where(id: params[:id]).first

    redirection_notice = ''

    unless @server
      redirection_notice = _('Server_not_found')
    end

    unless @server.try(:db).to_i == 1 || @server.try(:gui).to_i == 1
      redirection_notice = _('Dont_be_so_smart')
    end

    if redirection_notice != ''
      flash[:notice] = redirection_notice
      redirect_to :root and return false
    end

    time = Time.mktime(@cache[:year],@cache[:month],@cache[:day]).strftime('%F')
    group_rule = 'year(datetime), month(datetime), day(datetime), hour(datetime), minute(datetime)'

    raw_data  = @server.server_loadstats.where("datetime like '#{time}%'").group(group_rule)
    @data     = Hash.new(('00:00'..'23:59').to_a.join("\\n"))

    @common_stats.each do |stat_name|
      results = raw_data.collect { |stat| stat.csv_line(stat_name) }.join("\\n")
      @data[stat_name.intern] = results unless results.blank?
    end

    varied_result = raw_data.collect { |stat| stat.csv_line(*@server.which_loadstats?) }.join("\\n")
    @data[:db_gui_core] = varied_result unless varied_result.blank?
  end

  private

  def no_cache
    response.headers["Last-Modified"] = Time.now.httpdate
    response.headers["Expires"] = '0'
    # HTTP 1.0
    response.headers["Pragma"] = "no-cache"
    # HTTP 1.1 'pre-check=0, post-check=0' (IE specific)
    response.headers["Cache-Control"] = 'no-store, no-cache, must-revalidate, max-age=0, pre-check=0, post-check=0'
  end

  def active_calls_longer_error(calls)
    for call in calls
      ba = Thread.new { active_calls_longer_error_send_email(call['user_id'].to_s, call['provider_id'].to_s, call['server_id'].to_s); ActiveRecord::Base.connection.close }
      # ba.join #kam ji cia joininti?
      MorLog.my_debug 'active_calls_longer_error'
    end
  end

  def active_calls_longer_error_send_email(user, provider, server)
    address = Confline.get_value("Exception_Support_Email").to_s
    subject = "Active calls longer error on : #{Confline.get_value("Company")}"
    message = "URL:            #{Web_URL}\n"
    message += "User ID:        #{user.to_s}\n"
    message += "Provider ID:    #{provider.to_s}\n"
    message += "Server ID:      #{server.to_s}\n"
    message += "----------------------------------------\n"

    # disabling for now
    #`/usr/local/mor/sendEmail -f 'support@kolmisoft.com' -t '#{address}' -u '#{subject}' -s 'smtp.gmail.com' -xu 'crashemail1' -xp 'crashemail199' -m '#{message}' -o tls='auto'`
    MorLog.my_debug('Crash email sent')
  end

  def check_authentication
    redirect_to :root if current_user.nil?
  end

  def check_reseller_in_providers
    if reseller? and (current_user.own_providers.to_i == 0 or !reseller_pro_active?)
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def find_user_from_id_or_session
    params[:id] ? user_id = params[:id] : user_id = session[:user_id]
    @user=User.where(["id = ?", user_id]).first

    unless @user
      flash[:notice] = _('User_was_not_found')
      redirect_to :root and return false
    end

    if session[:usertype] == 'reseller'
      if @user.id != session[:user_id] and @user.owner_id != session[:user_id]
        dont_be_so_smart
        redirect_to :root and return false
      end
    end

    if session[:usertype] == 'user' and @user.id != session[:user_id]
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def last_calls_stats_parse_params(old = false, hide_non_answered_calls_for_user = false)
    default = {
        :items_per_page => session[:items_per_page].to_i,
        :page => "1",
        :s_direction => "outgoing",
        :s_call_type => "all",
        :s_device => "all",
        :s_provider => "all",
        :s_did_provider => "all",
        :s_hgc => 0,
        :search_on => 0,
        :s_user => '',
        :s_user_id => '-2',
        :user => nil,
        :s_did => "all",
        :s_did_pattern => "",
        :s_destination => "",
        :order_by => "time",
        :order_desc => 1,
        :s_country => '',
        :s_reseller => "all",
        :s_source => nil,
        :s_reseller_did => nil,
        :s_card_number => nil,
        :s_card_pin => nil,
        :s_card_id => nil,
        :show_device_and_cid => 0
    }

    options = ((params[:clear] || !session[:last_calls_stats]) ? default : session[:last_calls_stats])
    options[:items_per_page] = session[:items_per_page] if session[:items_per_page].to_i > 0
    default.each { |key, value| options[key] = params[key] if params[key] }

    change_date_to_present if params[:clear]

    if params[:s_user_id]
      options[:s_user_id] = ((params[:s_user_id] == '-2') && params[:s_user].present?) ? '' : params[:s_user_id]
    end

    options[:from] = old ? session_from_datetime : limit_search_by_days
    options[:till] = session_till_datetime
    options[:order_by_full] = options[:order_by] + (options[:order_desc] == 1 ? " DESC" : " ASC")
    options[:order] = old ? OldCall.calls_order_by(params, options) : Call.calls_order_by(params, options)
    options[:direction] = options[:s_direction]
    options[:call_type] = hide_non_answered_calls_for_user ? "answered" : options[:s_call_type]
    options[:destination] = (options[:s_destination].to_s.strip.match(/\A[0-9%]+\Z/) ? options[:s_destination].to_s.strip : "")
    options[:source] = options[:s_source] if  options[:s_source]

    exchange_rate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency]).to_d
    options[:exchange_rate] = exchange_rate
    options[:show_device_and_cid] = params[:action].to_s == "last_calls_stats" ? Confline.get_value('Show_device_and_cid_in_last_calls', correct_owner_id) : 0

    options
  end

  def last_calls_stats_user(user, options)
    devices = user.devices(:conditions => "device_type != 'FAX'")
    device = Device.where(:id => options[:s_device]).first if options[:s_device] != "all" and !options[:s_device].blank?
    return devices, device
  end

  def last_calls_stats_reseller(options)
    user = User.where(id: options[:s_user_id]).first if options[:s_user_id].present? && (options[:s_user_id] != '-2')

    if user
      device = Device.where(:id => options[:s_device]).first if options[:s_device] != "all" and !options[:s_device].blank?
      devices = user.devices(:conditions => "device_type != 'FAX'")
    else
      device, devices = [[], []]
    end

    if Confline.get_value('Show_HGC_for_Resellers').to_i == 1
      hgcs = Hangupcausecode.find_all_for_select
      hgc = Hangupcausecode.where(:id => options[:s_hgc]).first if options[:s_hgc].to_i > 0
    end

    if current_user.reseller_allow_providers_tariff?
      providers = current_user.load_providers({select: "id, name", order: 'providers.name ASC'})

      if options[:s_provider].to_i > 0
        #KRISTINA ticket number 3276
        #provider = Provider.find(:first, :conditions => ["providers.id = ? OR common_use = 1", options[:s_provider]])
        provider = Provider.where(["providers.id = ?", options[:s_provider]]).first
        unless provider
          dont_be_so_smart
          redirect_to :root and return false
        end
      end
      if options[:s_did_provider].to_i > 0
        did_provider = Provider.where(["providers.id = ?", options[:s_did_provider]]).first
        unless did_provider
          dont_be_so_smart
          redirect_to :root and return false
        end
      end
    else
      providers = nil; provider = nil; did_provider = nil
    end
    did = Did.where(:id => options[:s_did]).first if options[:s_did] != "all" and !options[:s_did].blank?

    return user, devices, device, hgcs, hgc, providers, provider, did, did_provider
  end

  def last_calls_stats_admin(options)
    user = User.where(id: options[:s_user_id]).first if options[:s_user_id].present? && (options[:s_user_id] != '-2')

    if user
      device = Device.where(:id => options[:s_device]).first if options[:s_device] != "all" and !options[:s_device].blank?
      devices = user.devices(:conditions => "device_type != 'FAX'")
    else
      device, devices = [[], []]
    end

    did = Did.where(:id => options[:s_did]).first if options[:s_did] != "all" and !options[:s_did].blank?
    hgc = Hangupcausecode.where(:id => options[:s_hgc]).first if options[:s_hgc].to_i > 0
    hgcs = Hangupcausecode.find_all_for_select
    providers = Provider.find_all_for_select
    provider = Provider.where(:id => options[:s_provider]).first if options[:s_provider].to_i > 0
    did_provider = Provider.where(:id => options[:s_did_provider]).first if options[:s_did_provider].to_i > 0
    resellers = User.where(:usertype => "reseller").all
    resellers_with_dids = User.joins('JOIN dids ON (users.id = dids.reseller_id)').where('usertype = "reseller"').group('users.id')
    resellers = [] if !resellers
    reseller = User.where(:id => options[:s_reseller]).first if options[:s_reseller] != "all" and !options[:s_reseller].blank?
    return user, devices, device, hgcs, hgc, did, providers, provider, reseller, resellers, resellers_with_dids, did_provider
  end

  def last_calls_stats_set_variables(options, values)
    options.merge(values.reject { |key, value| value.nil? })
  end

  def get_price_exchange(price, cur)
    exrate = Currency.count_exchange_rate(cur, current_user.currency.name)
    rate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [price.to_d]})
    return rate_cur.to_d
  end

  def no_users
    if user?
      dont_be_so_smart and redirect_to :root
    end
  end

  def lambda_round_seconds
    @round_seconds = lambda do |seconds|
      mod = seconds % 15
      if mod.zero?
        seconds
      else
        seconds - mod
      end
    end
  end

  def create_graph_data_file
    # Find the data for the current and the previous day
    data_today = ActiveCallsData.find_by_day(Time.zone.now)
    data_yesterday = ActiveCallsData.find_by_day(Time.zone.now - 1.day)

    session[:active_calls_graph] = {
      last_count: data_today.blank? ? Time.zone.now.midnight : data_today.last.time
    }

    time = Time.now.midnight

    #Prepare array for graph data, interval - 15 seconds
    graph_array = []
    ((24*3600)/15).times do
     graph_array.push [time.strftime('%H:%M'), '', '']
     time += 15.seconds
    end

    data_yesterday.collect! {|data| [data.time.in_time_zone(user_tz).strftime('%H:%M:%S'), data.count]}
    data_today.collect! {|data| [data.time.in_time_zone(user_tz).strftime('%H:%M:%S'), data.count]}

    data_yesterday.each do |data|
      hour, minute, second = data[0].split(':')
      second = @round_seconds.call(second.to_i)
      graph_array[(hour.to_i * 3600 + minute.to_i * 60 + second)/15][2] = data[1]
    end

    data_today.each do |data|
      hour, minute, second = data[0].split(':')
      second = @round_seconds.call(second.to_i)
      graph_array[(hour.to_i * 3600 + minute.to_i * 60 + second)/15][1] = data[1]
    end

    #Generate the CSV data for the Graph to read
    csv = ''
    graph_array.each do |element|
      csv << element.join(';')
      csv << "\n"
    end

    #The graph reads its data from this file
    f = File.new("#{Actual_Dir}/public/tmp/active_calls.csv", 'w')
    f.write(csv)
    f.close
  end

  def show_user_stats_clear_search(params)
    current_time_from = {year: Time.current.year.to_s, month: Time.current.month.to_s, day: Time.current.day.to_s, hour: '00', minute: '00'}
    current_time_till = {year: Time.current.year.to_s, month: Time.current.month.to_s, day: Time.current.day.to_s, hour: '23', minute: '59'}
    params[:date_from] = current_time_from
    params[:date_till] = current_time_till

    return params
  end

  def show_user_stats_check_searching_params(time_from, time_till)
    time_now_from = Time.current.strftime("%Y-%m-%d 00:00")
    time_now_till = Time.current.strftime("%Y-%m-%d 23:59")
    time_from = Time.parse(time_from).strftime("%Y-%m-%d %H:%M")
    time_till = Time.parse(time_till).strftime("%Y-%m-%d %H:%M")

    return ((time_now_from != time_from) || (time_now_till != time_till))
  end

  def clear_country_stats_search
    @options[:user_id] = -1
    change_date_to_present
  end

  def country_stats_parse_params
    @options = session[:country_stats] || {}

    if params[:s_user].to_s == ''
      params[:s_user_id] = -1
    elsif %w[-2 -1 0].include?(params[:s_user_id].to_s)
      params[:s_user_id] = -2
    end
    clear, user_id, order_by, params_user_id = params[:clear], @options[:user_id], params[:order_by], params[:s_user_id]

    clear_country_stats_search if clear
    if params[:search_pressed] || @options[:start].blank? || clear
      @options[:start] = Time.parse(session_from_datetime)
      @options[:end] = Time.parse(session_till_datetime)
      @options[:user_id] = params_user_id.to_i if params_user_id
    end
    if order_by
      @options[:order_desc] = params[:order_desc]
      @options[:order_by] = order_by
    end
    @options[:test] = params[:test].to_i

    time_not_curent = [[:start, '00'], [:end, '23']].any? do |key, hour|
      @options[key].strftime("%Y-%m-%d %H") != Time.current.strftime("%Y-%m-%d #{hour}")
    end

    @options[:show_clear] = time_not_curent || (user_id && user_id != -1)
  end

  def country_stats_file
    filename = "Country_stats-#{@options[:start].to_s.gsub(" ", "_").gsub(":", "_")}-#{@options[:end].to_s.gsub(" ", "_").gsub(":", "_")}-#{Time.now().to_i}"
    csv_string = Aggregate.country_stats_csv(@calls, @sep)

    if @options[:test] != 1
      require 'csv'
      CSV.open("/tmp/" + filename + '.csv', 'w', {:col_sep => @sep}) do |csv|
        csv_string.each do |line|
          csv << line
        end
      end
    end

    return filename
  end

  def find_csv_separator
    @sep, @dec = current_user.csv_params
  end

  def generate_country_stats_csv
    if params[:test].to_i != 1
      filename = country_stats_file
      if filename
        filename = archive_file_if_size(filename, "csv", Confline.get_value("CSV_File_size").to_d)
        send_data(File.open(filename).read, :filename => filename.sub('/tmp/', ''))
      else
        flash[:notice] = _("Cannot_Download_CSV_File_From_DB_Server")
        redirect_to :root and return false
      end
    else
      render :text => @calls.to_json
    end
  end

  def check_if_searching
    @searching = params[:search_on].to_i == 1
  end

  def is_devices_for_sope_present
    devices_for_sope = Device.find_all_for_select(corrected_user_id, {count: true})
    @devices_for_sope_present = devices_for_sope[0].count_all.to_i > 0
  end
end
