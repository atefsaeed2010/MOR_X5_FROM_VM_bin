# -*- encoding : utf-8 -*-
class NumberPoolsController < ApplicationController

  layout 'callc'

  before_filter :access_denied, :if => lambda { not admin? }
  before_filter :check_post_method, only: [:pool_create, :pool_update, :pool_destroy, :number_create, :number_destroy]
  before_filter :find_number_pool, only: [:pool_edit, :pool_update, :pool_destroy, :number_list, :number_import, :destroy_all_numbers, :bad_numbers]
  before_filter :find_number, only: [:number_destroy]

  # ------ Number Pools Begin ------ #
  def pool_list
    @page_title = _('Number_Pools')
    @page_icon = 'number_pool.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Number_Pool"

    session[:number_pool_list] ? @options = session[:number_pool_list] : @options = {}

    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (@options[:order_by] = "id" if !@options[:order_by])

    order_by = NumberPool.number_pools_order_by(@options)

    # page params
    @total_pools_size = NumberPool.count
    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @total_pages = (@total_pools_size.to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    @page = @options[:page]
    @fpage = ((@options[:page] -1) * session[:items_per_page]).to_i

    @number_pools = NumberPool.select("number_pools.*, COUNT(n.id) AS num")
                              .joins("LEFT JOIN numbers n ON (n.number_pool_id = number_pools.id)")
                              .group("number_pools.id")
                              .order(order_by)
                              .limit("#{@fpage}, #{session[:items_per_page].to_i}").all


    session[:number_pool_list] = @options
  end

  def pool_new
    @page_title = _('New_number_pool')
    @page_icon = "add.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Number_Pool"
  end

  def pool_create
    @number_pool = NumberPool.new(params[:number_pool])
    if @number_pool.save
      flash[:status] = _('number_pool_successfully_created')
      redirect_to action: 'pool_list' and return false
    else
      flash_errors_for(_('number_pool_was_not_created'), @number_pool)
      render :pool_new
    end
  end

  def pool_edit
    @page_title = _('number_pool_edit')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Number_Pool"
  end

  def pool_update
    @number_pool.attributes = @number_pool.attributes.merge(params[:number_pool])
    if @number_pool.save
      flash[:status] = _('number_pool_successfully_updated')
      redirect_to action: 'pool_list' and return false
    else
      flash_errors_for(_('number_pool_was_not_updated'), @number_pool)
      render :pool_edit
    end
  end

  def pool_destroy
    if @number_pool.destroy
      flash[:status] = _('number_pool_successfully_deleted')
      redirect_to action: 'pool_list' and return false
    else
      flash_errors_for(_('number_pool_was_not_deleted'), @number_pool)
      redirect_to action: 'pool_list' and return false
    end
  end

  # ------ Number Pools End ------ #

  # ------ Numbers Start ------ #

  def number_list
    @page_title = _('Number_Pools')
    @page_icon = 'details.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Number_Pool"

    session[:number_list] ? @options = session[:number_list] : @options = {}

    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (@options[:order_by] = "id" if !@options[:order_by])

    order_by = Number.numbers_order_by(@options)

    # page params
    @total_numbers_size = @number_pool.numbers.count
    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @total_pages = (@total_numbers_size.to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    @page = @options[:page]
    @fpage = ((@options[:page] -1) * session[:items_per_page]).to_i

    @numbers = @number_pool.numbers.order(order_by).limit("#{@fpage}, #{session[:items_per_page].to_i}").all


    session[:number_list] = @options
  end

  def number_destroy
    if @number.destroy
      flash[:status] = _('number_successfully_deleted')
      redirect_to action: 'number_list', id: @number.number_pool_id and return false
    else
      flash_errors_for(_('number_was_not_deleted'), @number_pool)
      redirect_to action: 'number_list', id: @number.number_pool_id and return false
    end
  end

  def destroy_all_numbers
    @number_pool.numbers.where("").delete_all
    flash[:status] = _('all_numbers_successfully_deleted')
    redirect_to action: 'number_list', id: @number_pool.id and return false
  end

  def number_import
    @page_title = _('Number_import')
    @page_icon = 'details.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Number_Pool"

    @step = 1
    @step = params[:step].to_i if params[:step]

    if @step == 2
      if params[:file]
        @file = params[:file]
        if @file.size > 0

          if !@file.respond_to?(:original_filename) or !@file.respond_to?(:read) or !@file.respond_to?(:rewind)
            flash[:notice] = _('Please_select_file')
            redirect_to :action => "number_import", :id => @campaign.id, :step => "0" and return false
          end
          @imported_numbers = 0
          @bad_numbers_quantity = 0
          array_for_sql = []
          bad_numbers = []
          begin
            @file.rewind
            file = @file.read
            session[:file_size] = file.size

            file.each_line { |f|
              if is_number?(f.to_s.strip.chomp)
                @imported_numbers += 1
                array_for_sql << "('#{f.chomp}', #{@number_pool.id})"
              elsif not f.blank?
                @bad_numbers_quantity += 1
                bad_numbers << f.to_s.strip
              end
            }
            sql = "INSERT INTO numbers (number, number_pool_id) VALUES #{array_for_sql.join(", ")}"
            ActiveRecord::Base.connection.execute(sql) if @imported_numbers > 0
            @total_numbers = @imported_numbers + @bad_numbers_quantity

            # file for bad numbers
            File.open("/tmp/bad_numbers.txt", "w+") do |f|
              f.write(bad_numbers.join("\n"))
            end
            `chmod 777 /tmp/bad_numbers.txt`

            if @total_numbers == @imported_numbers
              flash[:status] = _('Numbers_successfully_imported')
            else
              flash[:status] = _('M_out_of_n_numbers_imported', @imported_numbers, @total_numbers)
            end
          rescue
            flash[:notice] = _('Invalid_file_format')
            redirect_to :action => "number_import", :id => @number_pool.id and return false
          end
        else
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "number_import", :id => @number_pool.id and return false
        end
      else
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "number_import", :id => @number_pool.id and return false
      end
    end
  end

  def bad_numbers
    @page_title = _('Bad_numbers_from_file')
    @page_icon = 'details.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Number_Pool"

    @rows = []
    File.open("/tmp/bad_numbers.txt", "r").each_line do |f|
      @rows << f
    end
  end


  # ------ Numbers End ------ #

  private

  def find_number_pool
    @number_pool = NumberPool.where(id: params[:id]).first
    unless @number_pool
      flash[:notice] = _('number_pool_was_not_found')
      redirect_to action: 'pool_list' and return false
    end
  end

  def find_number
    @number = Number.where(id: params[:id]).first
    unless @number
      flash[:notice] = _('number_was_not_found')
      redirect_to action: 'number_list' and return false
    end
  end
end
