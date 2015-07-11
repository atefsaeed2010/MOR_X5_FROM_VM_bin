# controller to show aggregate statistics in GUI
class AggregatesController < ApplicationController

  layout 'callc'

  include UniversalHelpers
  before_filter :check_localization
  before_filter :access_denied, if: -> { user? }
  before_filter :reset_min_sec, only: [:list]

  def list
    # this method is a stub
    @page_title = _('calls_aggregate')
    @help_link = 'http://wiki.kolmisoft.com/index.php/Last_Calls#Call_information_representation'
    @searching = params[:search_on].to_i == 1
    @export_to_csv = params[:csv].to_i == 1
    clean = params[:clean].to_i == 1
    search_pressed = params[:search_pressed]
    aggregate_options = session[:aggregate_options]

    change_date
    reset_min_sec

    if @searching && Time.parse(session_from_datetime) > Time.parse(session_till_datetime)
      redirect_to(action: :list) && (return false)
    end

    if aggregate_options
      @options = aggregate_options
    else
      @options = {}
    end

    if @options.blank? || search_pressed || clean
      @default = !@searching
      set_checkboxes
      # unless search_pressed
	   if !search_pressed
        @options[:originator] = ''
        @options[:originator_id] = 'any'
        @options[:terminator] = '0'
        @options[:country]    = '0'
        @options[:prefix]     = ''
        @options[:use_real_billsec]      = 0
        @options[:from_user_perspective] = 0
        @options[:answered_calls] = 1
        change_date_to_present
      end
    end

    time = current_user.user_time(Time.now)
    year = time.year
    month = time.month
    day = time.day
    @from = (session_from_datetime_array.map(&:to_i) != [year, month, day, 0, 0, 0])
    @till = (session_till_datetime_array.map(&:to_i) != [year, month, day, 23, 59, 59])

    @terminators = current_user.load_terminators
    @countries   = Direction.all
    order_by = params[:order_by]
    order_desc = params[:order_desc]
    page = params[:page]

    # page ? @options[:page] = page.to_i : (@options[:page] = 1 unless @options[:page])
    # order_by ? @options[:order_by] = order_by : (@options[:order_by] = 'direction' unless @options[:order_by])
    # order_desc ? @options[:order_desc] = order_desc.to_i : (@options[:order_desc] = 0 unless @options[:order_desc])

	  page ? @options[:page] = page.to_i : (@options[:page] = 1 if !@options[:page])
    order_by ? @options[:order_by] = order_by : (@options[:order_by] = 'direction' if !@options[:order_by])
    order_desc ? @options[:order_desc] = order_desc.to_i : (@options[:order_desc] = 0 if !@options[:order_desc])

    if search_pressed
      @search_values = params.select { |key, _|
        ['terminator', 'prefix', 'country', 'use_real_billsec', 'from_user_perspective', 'answered_calls'].member?(key)
      }.symbolize_keys!

      params_originator, params_originator_id = [params[:s_originator],
        params[:s_originator_id]]

      case params_originator.downcase
      when 'any'
        params_originator_id = 'any'
      when 'none'
        params_originator_id = 'none'
      end

      @search_values[:originator], @search_values[:originator_id] = [params_originator, params_originator_id]
      @not_correct_params = params_originator.present? && (params_originator_id == '-2')

      @options.merge!(@search_values) if @search_values.present?

      @options[:exchange_rate] = current_user.currency.try(:exchange_rate).to_d
      @options[:aggregation_variant], @options[:group_by] = get_aggregation_variant
      @counting = true
      total_aggregates = search_aggregates
      @counting = false
      @options[:total_records] = total_aggregates.count_all
      @options[:total_user_billed] = total_aggregates.total_user_billed
      @options[:total_user_billed_with_tax] = total_aggregates.total_user_billed_with_tax
      @options[:total_terminator_billed] = total_aggregates.total_terminator_billed
      @options[:total_user_billed_billsec] = total_aggregates.total_user_billed_billsec
      @options[:total_terminator_billed_billsec] = total_aggregates.total_terminator_billed_billsec
      @options[:total_answered_calls] = total_aggregates.total_answered_calls
      @options[:total_calls] = total_aggregates.total_calls
      @options[:total_asr] = total_aggregates.total_asr
      @options[:total_acd] = total_aggregates.total_acd
      @options[:total_billsec] = total_aggregates.total_billsec
    end

    @order_by = Aggregate.agregate_order_by(@options)
    @total_records = @options[:total_records]

    @aggregates, aggregates_for_csv = if @searching || @export_to_csv
                                        search_aggregates
                                      else
                                        [[], []]
                                      end
    export_to_csv(aggregates_for_csv, aggregate_options) if @export_to_csv && !aggregates_for_csv.blank?
    session[:aggregate_options] = @options
  end

  private

  def get_aggregation_variant
    terminator, originator, country, prefix = @search_values[:terminator].to_i != -1,
                                              @search_values[:originator_id].to_s != 'none',
                                              @search_values[:country].to_i != -1,
                                              @search_values[:prefix].present?

    variant = if originator && terminator && (prefix || (country && prefix))
      11
    elsif terminator && country && prefix
      10
    elsif originator && (prefix || (country && prefix))
      9
    elsif originator && terminator && country
      8
    elsif prefix
      7
    elsif terminator && country
      6
    elsif originator && country
      5
    elsif originator && terminator
      4
    elsif country
      3
    elsif terminator
      2
    elsif originator
      1
              end

    grouping = []

    grouping << 'aggregates.prefix' if prefix
    grouping << 'aggregates.direction' if country
    grouping << 'nice_user' if originator
    grouping << 'terminators.name' if terminator

    return variant, grouping
  end

  def set_checkboxes
    checkboxes = ['price_orig_show',
                  'price_term_show',
                  'billed_time_orig_show',
                  'billed_time_term_show',
                  'duration_show',
                  'acd_show',
                  'calls_answered_show',
                  'asr_show',
                  'calls_total_show']

    checkboxes.each do |check|
      check = check.to_sym
      @options[check] = if @default
        1
      else
        if params[:search_pressed].present? && params[:date_from].blank?
          @options[check]
        else
          params[check].to_i
        end
      end
    end
  end

  def search_aggregates
    start_time = Time.parse(session_from_datetime)
    end_time   = Time.parse(session_till_datetime)
    cond = Aggregate.find_aggregates(start_time, end_time)
    country, check_country, group_by, ex  = @options[:country].to_s,
                                            !['0', '-1'].member?(country),
                                            @options[:group_by],
                                            @options[:exchange_rate]

    billsec_use = @options[:use_real_billsec].to_i == 0 ? 'SUM(billsec)' : 'SUM(real_billsec)'
    total_calls_use = @options[:from_user_perspective].to_i == 0 ? 'SUM(total_calls)' : 'SUM(total_calls_for_user)'
    asr_use = "SUM(answered_calls) / #{total_calls_use}"
    acd_use = "#{billsec_use} / SUM(answered_calls)"

    joins =  'JOIN time_periods ON aggregates.time_period_id = time_periods.id '
    joins << 'LEFT JOIN terminators ON aggregates.terminator_id = terminators.id '
    joins << 'LEFT JOIN users ON aggregates.user_id = users.id '

    group = ''
    group = "GROUP BY #{group_by.join(',')}" if group_by.present?
    terminator = @options[:terminator].to_i
    originator = @options[:originator_id].to_i
    country    = Direction.where(id: country).first.try(:name) if check_country
    prefix     = @options[:prefix].to_s.strip
    #2nd try
	#answered_calls_opt = @options[:answered_calls]
    #answered_calls = is_number?(answered_calls_opt.to_s.strip) && answered_calls_opt.to_i >= 0 ?
    #    answered_calls_opt.to_i : 0

  	answered_calls = is_number?(@options[:answered_calls].to_s.strip) && @options[:answered_calls].to_i >= 0 ?
    @options[:answered_calls].to_i : 0

    count_total_answered_calls_condition = "WHERE total_answered_calls >= #{answered_calls}"
    total_answered_calls_condition = "WHERE answered_calls >= #{answered_calls}"

    if @options[:from_user_perspective].to_i == 1
      count_total_answered_calls_condition << ' AND total_calls > 0'
      total_answered_calls_condition << ' AND total_calls > 0'
    end

    condition  = "(#{cond.join(' OR ')}) AND aggregates.variation = #{@options[:aggregation_variant].to_i}"
    condition << " AND aggregates.terminator_id = #{terminator}" if terminator > 0
    condition << " AND aggregates.user_id = #{originator}" if originator.to_i > 0
    condition << " AND aggregates.direction LIKE '#{country}%'" if check_country
    condition << " AND aggregates.prefix LIKE '#{prefix}'" if prefix.present?
    condition << " AND aggregates.id = ''" if @not_correct_params

    nice_user_sql = SqlExport.nice_user_sql

    if @counting
      select_columns  = "COUNT(aggregates.id) AS count_all" +
                    ", SUM(total_user_billed) * #{ex} AS total_user_billed" +
                    ", SUM(total_user_billed_with_tax) * #{ex} AS total_user_billed_with_tax" +
                    ", SUM(total_terminator_billed) * #{ex} AS total_terminator_billed" +
                    ", SUM(total_user_billed_billsec) AS total_user_billed_billsec" +
                    ", SUM(total_terminator_billed_billsec) AS total_terminator_billed_billsec" +
                    ", SUM(total_answered_calls) AS total_answered_calls" +
                    ", SUM(total_calls) AS total_calls" +
                    ", SUM(total_billsec) AS total_billsec" +
                    ", SUM(total_answered_calls) / SUM(total_calls) AS total_asr" +
                    ", SUM(total_billsec) / SUM(total_answered_calls) AS total_acd"

      sub_select  = "aggregates.id" +
                    ", SUM(user_billed) AS total_user_billed" +
                    ", SUM(user_billed_with_tax) AS total_user_billed_with_tax" +
                    ", SUM(terminator_billed) AS total_terminator_billed" +
                    ", SUM(user_billed_billsec) AS total_user_billed_billsec" +
                    ", SUM(terminator_billed_billsec) AS total_terminator_billed_billsec" +
                    ", SUM(answered_calls) AS total_answered_calls" +
                    ", #{total_calls_use} AS total_calls" +
                    ", #{billsec_use} AS total_billsec" +
                    ", #{nice_user_sql}"
      from = "(SELECT #{sub_select} FROM aggregates #{joins} WHERE #{condition} #{group}) aggregates #{count_total_answered_calls_condition}"

      sql = "SELECT #{select_columns} FROM #{from}"
    else
      fpage, @total_pages, @options = Application.pages_validator(session, @options, @options[:total_records])
      order = "ORDER BY #{@order_by}" if @order_by.present?
      select_columns = "aggregates.prefix, aggregates.direction" +
                       ", SUM(user_billed) * #{ex} AS user_billed" +
                       ", SUM(user_billed_with_tax) * #{ex} AS user_billed_with_tax" +
                       ", SUM(terminator_billed) * #{ex} AS terminator_billed" +
                       ", SUM(user_billed_billsec) AS user_billed_billsec" +
                       ", SUM(terminator_billed_billsec) AS terminator_billed_billsec" +
                       ", #{billsec_use} AS billsec" +
                       ", SUM(answered_calls) AS answered_calls" +
                       ", #{total_calls_use} AS total_calls" +
                       ", #{asr_use} AS asr" +
                       ", #{acd_use} AS acd" +
                       ", users.id AS user_id" +
                       ", terminators.name, #{nice_user_sql}"
      from = "aggregates #{joins} WHERE #{condition} #{group} #{order.to_s}"
      sql = "SELECT * FROM (SELECT #{select_columns} FROM #{from}) aggregates #{total_answered_calls_condition}"
    end
    session_items_per_page = session[:items_per_page]
    if @counting || @export_to_csv
      aggregates_for_csv = Call.find_by_sql(sql)
      aggregates = aggregates_for_csv[fpage.to_i, session_items_per_page]
	else
      aggregates_for_csv = []
	    limit = " LIMIT #{fpage}, #{session[:items_per_page]}"
      sql = "SELECT * FROM (SELECT #{select_columns} FROM #{from}) aggregates #{total_answered_calls_condition} #{limit}"
      aggregates = Call.find_by_sql(sql) # here
    end

    if @counting
      return aggregates.first
    else
      return aggregates, aggregates_for_csv
    end
  end

  def export_to_csv(aggregates, aggregate_options)
    sep, dec = current_user.csv_params
    csv_string, headers = generate_csv(aggregates, aggregate_options)

    require 'csv'
    filename = '/tmp/Aggregates.csv'

    CSV.open(filename, 'wb', col_sep: sep) do |csv|
      csv_string.each { |line| csv << line }
     end

    if filename
      filename = archive_file_if_size('Aggregates', 'csv', Confline.get_value('CSV_File_size').to_d)
      if params[:test].to_i.zero?
        send_data(File.open(filename).read, filename: filename.gsub('/tmp/', ''))
      else
        csv_for_test = csv_for_test(csv_string, headers)
        render text: csv_for_test
      end
    end
  end

  def generate_csv(aggregates, aggregate_options)
    csv_string = []

    # removing atrributes not needed in csv
    aggregates_cleaned = []
    aggregates.each do |aggregates|
      attributes_to_delete = ["'id'", "'user_id'", "'prefix'"]
      attributes_to_delete = attributes_to_delete.join(", ")
      show_originator = aggregate_options[:originator_id].to_s != 'none'
      show_terminator = aggregate_options[:terminator].to_i != -1
      show_price_orig = aggregate_options[:price_orig_show].to_i == 0
      aggregates_cleaned_array = aggregates.attributes.except!('id', 'user_id', 'prefix').
                                            except!( !show_originator ? 'nice_user' : '').
                                            except!( !show_terminator ? 'name' : '').
                                            except!(show_price_orig ? 'user_billed' : '').
                                            except!(show_price_orig ? 'user_billed_with_tax' : '').
                                            except!(aggregate_options[:price_term_show].to_i == 0 ? 'terminator_billed' : '').
                                            except!(aggregate_options[:billed_time_orig_show].to_i == 0 ? 'user_billed_billsec' : '').
                                            except!(aggregate_options[:billed_time_term_show].to_i == 0 ? 'terminator_billed_billsec' : '').
                                            except!(aggregate_options[:duration_show].to_i == 0 ? 'billsec' : '').
                                            except!(aggregate_options[:calls_answered_show].to_i == 0 ? 'answered_calls' : '').
                                            except!(aggregate_options[:calls_total_show].to_i == 0 ? 'total_calls': '').
                                            except!(aggregate_options[:asr_show].to_i == 0 ? 'asr' : '').
                                            except!(aggregate_options[:acd_show].to_i == 0 ? 'acd' : '').
                                            to_a
      positions = []
      positions << 1 if show_originator || show_terminator
      positions << 2 if show_originator && show_terminator

      # putting nice_user to second position and name to third position
      positions.each do |position|
        last_member = aggregates_cleaned_array.last
        aggregates_cleaned_array.insert(position, last_member).pop
      end

      aggregates_cleaned << Hash[aggregates_cleaned_array]
    end

    # making headers for csv
    headers = []

    aggregates_cleaned.first.keys.each do |key|
      headers << _("aggregates_#{key}")
    end

    csv_string << headers

    # making csv values
    aggregates_cleaned.each do |aggregates|
      line = []

      aggregates.each do |key, value|
        # nice_time method for billsecs
        value = nice_time(value) if ['user_billed_billsec', 'terminator_billed_billsec', 'billsec'].include?(key.to_s)
        line << value
      end

    csv_string << line
    end

    return csv_string, headers
  end

  def csv_for_test(csv_string, headers)
    csv_string_for_test = ''
    csv_string.shift()

    csv_string.each do |arr|
      arr.each_with_index do |value, position|
        header = headers[position].to_s
        if ['Billed Originator', 'Billed Originator Price with Tax', 'Billed Terminator', 'ASR', 'ACD'].include?(header)
          value = Application.nice_number(value)
        end
        csv_string_for_test += '"' + header + '":"' + value.to_s + '",'
      end
    end

    csv_string_for_test = csv_string_for_test.chomp(',')
    return csv_string_for_test
  end

  def reset_min_sec
    session[:minute_from], session[:minute_till] = '00', '59'
  end
end
