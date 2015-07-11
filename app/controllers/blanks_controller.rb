# Blank page for code example
# -*- encoding : utf-8 -*-
class BlanksController < ApplicationController
  layout "callc"

  before_filter :access_denied, if: lambda { not session[:usertype] == 'admin' }
  before_filter :check_post_method, only: [:destroy, :create, :update]
  before_filter :check_localization

  before_filter :find_blank, only: [:edit, :update, :destroy, :value3_change_status]
  before_filter :number_separator

  before_filter :change_separator, only: [:create, :update]
  before_filter :init_help_link, only: [:list, :new, :create, :edit, :update]
  before_filter :strip_params, only: [:list]
  before_filter :change_currency, only: [:list]

  def list
    @page_title, @page_icon = [_('Blanks'), 'details.png']
    @show_currency_selector = true

    @options = initialize_options
    @blanks, @total_pages, @options = nice_list(@options, session[:items_per_page].to_i)
    # CSV Export
    export_to_csv unless params[:csv].to_i.zero?
    Application.change_separators(@options, @nbsp)
    session[:blanks_options] = @options
  end

  def new
    @page_title, @page_icon = [_('Blank_new'), 'add.png']

    # Creating new Blank and getting/updating time for Blank.time
    @blank = Blank.new
    @blank.date = Time.zone.now
  end

  def create
    @page_title, @page_icon = [_('Blank_new'), 'add.png']

    # Creating new Blank by getting params(values) from already filled forms
    @blank = Blank.new(blank_attributes)
    if @blank.save
      flash[:status] = _('Blank_successfully_created')
      redirect_to :action => 'list'
    else
      flash_errors_for(_('Blank_not_created'), @blank)
      Application.change_separators(params[:blank], @nbsp)
      render :new
    end
  end

  def edit
    @page_title, @page_icon = [_('Blank_edit'), 'edit.png']

    @blank.value2 = @blank.value2.to_s.sub(/[\,\.\;]/, "#{@nbsp}")
    @blank.balance = @blank.balance.to_s.sub(/[\,\.\;]/, "#{@nbsp}")
  end

  def update
    @page_title, @page_icon = [_('Blank_edit'), 'edit.png']

    # If update fails this will get params(values) from already edited forms
    # When returning to his page, 'render' method must be used instead of 'redirect_to', (render :action => 'edit')
    if @blank.update_attributes(blank_attributes)
      flash[:status] = _('Blank_successfully_updated')
      redirect_to :action => 'list'
    else
      flash_errors_for(_('Blank_not_updated'), @blank)
      Application.change_separators(params[:blank], @nbsp)
      render :edit
    end
  end

  def destroy
    if @blank.destroy
      flash[:status] = _('Blank_deleted')
    else
      dont_be_so_smart
    end
    redirect_to :action => 'list'
  end

  # Change 'value3' in 'list'
  def value3_change_status
    @blank.value3, flash[:status] = if @blank.value3.to_s == 'yes'
                                      ['no', _('Value3_disabled')]
                                    else
                                      ['yes', _('Value3_enabled')]
                                    end
    @blank.save
    redirect_to :action => 'list'
  end

  private

  # Find and select 'Blank' by 'id'
  def find_blank
    @blank = Blank.where(:id => params[:id]).first
    unless @blank
      flash[:notice] = _('Blank_not_found')
      redirect_to :action => 'list' and return false
    end
  end

  def generate_csv(blanks, sep)
    csv_string = "#{_('ID')}#{sep}#{_('Name')}#{sep}#{_('Date')}#{sep}#{_('Description')}#{sep}#{_('Value1')}#{sep}#{_('Value2')}#{sep}#{_('Value3')}\n"
    blanks.each do |blank|
      id, name, date, description, first_value, second_value, third_value = blank.attributes.values
      csv_string += "\"#{id.to_i}\"#{sep}\"#{name.to_s}\"#{sep}\"#{date}\"#{sep}\"#{description}\"#{sep}\"#{first_value.to_i}\"#{sep}\"#{nice_number(second_value.to_d)}\"#{sep}\"#{third_value.to_s}\"\n"
    end
    return csv_string
  end

  def change_separator
    # Change user's number separator to MOR's
    [:value2, :balance].each do |key|
      params[:blank][key].try(:sub!, /[\,\.\;]/, ".")
    end
  end

  def export_to_csv
    sep, dec = current_user.csv_params
    csv_string = generate_csv(@blanks, sep.first)
    filename = "Blanks.csv"

    if params[:test].to_i.zero?
      send_data(csv_string, :type => 'text/csv; charset=utf-8; header=present', :filename => filename)
    else
      render :text => csv_string
    end
  end

  def init_help_link
    @help_link = "http://wiki.kolmisoft.com/index.php/Main_Page"
  end

  def blank_attributes
    params[:blank].merge({date: user_time_from_params(*params[:date].values).localtime})
  end

  def nice_list(options, items_per_page)
    fpage, total_pages, options = Application.pages_validator(session, options, Blank.count)
    selection = Blank.filter(options, session_from_datetime, session_till_datetime).order_by(options, fpage, items_per_page)
    return selection, total_pages, options
  end

  def get_time
    time = current_user.user_time(Time.now)
    year = time.year
    month = time.month
    day = time.day
    from = (session_from_datetime_array.map(&:to_i) != [year, month, day, 0, 0, 0])
    till = (session_till_datetime_array.map(&:to_i) != [year, month, day, 23, 59, 59])
    return from, till
  end

  def show_clear_button(options)
    from, till = get_time
    ([:s_name, :s_min_value2, :s_max_value2].any? {|key| options[key].present?} or from or till)
  end

  def clear_options(options)
    change_date_to_present
    [:s_name, :s_min_value2, :s_max_value2].each do |key|
      options[key] = ''
    end

    options
  end

  def initialize_options
    options = session[:blanks_options] || {}

    change_date
    param_keys = ['order_by', 'order_desc', 'search_on', 'page', 's_name', 's_min_value2', 's_max_value2']
    params.select{|key, _| param_keys.member?(key)}.each do |key, value|
      options[key.to_sym] = value.to_s
    end
    Application.change_separators(options, '.')
    options[:csv] = params[:csv].to_i

    options = clear_options(options) if params[:clear]
    options[:clear] = show_clear_button(options)
    options[:exchange_rate] = change_exchange_rate

    options
  end


end
