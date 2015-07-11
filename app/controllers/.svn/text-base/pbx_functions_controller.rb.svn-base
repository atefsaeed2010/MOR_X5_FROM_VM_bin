# -*- encoding : utf-8 -*-
class PbxFunctionsController < ApplicationController

  require "yaml"
  layout "callc"
  before_filter :authorize
  before_filter :check_post_method, only: [:destroy, :create, :update, :set_allow, :pbx_pool_destroy, :pbx_pool_create, :pbx_pool_update]
  before_filter :access_denied, :only => [:pbx_pools_list, :pbx_pool_new, :pbx_pool_create, :pbx_pool_edit,
                                          :pbx_pool_update, :pbx_pool_users, :pbx_pool_user_update, :pbx_pool_destroy],
                :if => lambda { not ((admin? or reseller?) and x6_functionality(4)) }
  before_filter :check_localization
  before_filter :find_pbx_function, only: [:edit, :update, :set_allow]
  before_filter :check_pbx_addon, only: [:edit, :list]
  #before_filter :find_pbx_number, only: [:pbx_pool_destroy]

  pbx_pool_read = [:pbx_pools_list, :pbx_pool_new, :pbx_pool_create, :pbx_pool_edit,
                   :pbx_pool_update, :pbx_pool_users, :pbx_pool_user_update, :pbx_pool_destroy]

  before_filter(:only => pbx_pool_read) {|action|
    allow_read, allow_edit = action.check_read_write_permission(pbx_pool_read, [], {:role => 'reseller', :right => :res_pbx_functions, :ignore => true})
    action.instance_variable_set(:@allow_pbx_pool_read, allow_read)
    action.instance_variable_set(:@allow_pbx_pool_edit, allow_edit)
    true
  }

  before_filter :find_pbx_pool, only: [:pbx_pool_edit, :pbx_pool_update, :pbx_pool_destroy, :pbx_pool_users]

  def list
    @page_title = _('Pbx_functions')

    @pbx_functions = Pbxfunction.order("pf_type ASC")
  end

  def edit
    @page_title = _('Pbx_functions_edit')
  end

  def update
    @pbx_function.update_attributes(params[:pbx_function])
    if @pbx_function.save
      flash[:status] = _('Pbx_function_updated')
      redirect_to :action => :list and return false
    else
      flash[:notice] = _('Pbx_function_not_updated')
      redirect_to :action => :list and return false
    end
  end


  def set_allow
    @pbx_function.allow_resellers = @pbx_function.allow_resellers.to_i == 1 ? 0 : 1
    if @pbx_function.save
      flash[:status] = _('Pbx_function_updated')
      redirect_to :action => :list and return false
    else
      flash[:notice] = _('Pbx_function_not_updated')
      redirect_to :action => :list and return false
    end
  end

  def pbx_pools_list
    @page_title = _('Pbx_pools')
    @page_icon = "details.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/PBX_Pools"

    # Ordering
    session[:pbx_pools_order_by_options] ? @options = session[:pbx_pools_order_by_options] : @options = {}

    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])

    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (@options[:order_by] ?  @options[:order_by]  : @options[:order_by] = 'id')
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] ? @options[:order_desc] : @options[:order_desc] = 0)

    order_by = PbxPool.pbx_pools_order_by(params, @options)

    # Pagination
    @pbx_pools_size = PbxPool.where(owner_id: current_user.id).count
    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @total_pages = (@pbx_pools_size.to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    @page = @options[:page]
    @fpage = ((@options[:page] -1) * session[:items_per_page]).to_i

    @pbx_pools = PbxPool.select('pbx_pools.*, COUNT(users.id) AS user_count').where(owner_id: current_user.id).joins('LEFT JOIN users ON (pbx_pools.id = users.pbx_pool_id)').group('pbx_pools.id').order(order_by).limit("#{@fpage}, #{session[:items_per_page].to_i}").all
    # atkomentuoti, kai bus sukurtas numbers pridėjimas ir ištrinti virš esančią eilutę
    #@pbx_pools = PbxPool.select("pbx_pools.*, COUNT(users.id) AS user_count, COUNT(n.id) AS num")
    #                    .where(owner_id: current_user.id).order(order_by)
    #                    .joins('LEFT JOIN users ON (pbx_pools.id = users.pbx_pool_id)')
    #                    .joins("LEFT JOIN pbx_numbers n ON (n.pbx_pool_id = pbx_pools.id)")
    #                    .group("pbx_pools.id")
    #                    .order(order_by)

    session[:pbx_pools_order_by_options] = @options
  end

  def pbx_pool_new
    @page_title = _('pbx_pool_new')
    @page_icon = "add.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/PBX_Pools"

    @pbx_pool = PbxPool.new
  end

  def pbx_pool_create
    pbx_pool_new

    params[:pbx_pool].update({owner_id: current_user.id}) unless params[:pbx_pool].blank?

    @pbx_pool.assign_attributes(params[:pbx_pool])

    if @pbx_pool.save
      flash[:status] = _('pbx_pool_successfully_created')
      redirect_to :action => 'pbx_pools_list'
    else
      flash_errors_for(_('pbx_pool_not_created'), @pbx_pool)
      render :pbx_pool_new
    end
  end

  def pbx_pool_edit
    @page_title = _('pbx_pool_edit')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/PBX_Pools"
  end

  def pbx_pool_update
    pbx_pool_edit

    @pbx_pool.assign_attributes(params[:pbx_pool])

    if @pbx_pool.save
      flash[:status] = _('pbx_pool_successfully_updated')
      redirect_to :action => 'pbx_pools_list'
    else
      flash_errors_for(_('pbx_pool_not_updated'), @pbx_pool)
      render :pbx_pool_edit
    end
  end

  def pbx_pool_destroy
    if @pbx_pool.destroy
      flash[:status] = _('pbx_pool_successfully_deleted')
      redirect_to action: 'pbx_pools_list' and return false
    else
      flash_errors_for(_('pbx_pool_not_deleted'), @pbx_pool)
      redirect_to action: 'pbx_pools_list' and return false
    end
  end

  def pbx_pool_users
    @page_title = _('pbx_pool_users')
    @page_icon = "details.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/PBX_Pools"

    @users = User.where(owner_id: current_user.id, usertype: 'user', pbx_pool_id: 0).all
  end

  def pbx_pool_user_update
    pbx_pool = PbxPool.where(id: params[:id]).first
    user = User.where(id: params[:user_id], owner_id: current_user.id).first

    if user
      case params[:operation].to_s
        when 'assign'
          if !user.pbx_pool
            user.pbx_pool = pbx_pool
            flash[:status] = _('user_was_successfully_assigned') if user.save
          else
            flash[:notice] = _('user_already_assigned_to_other_pbx_pool')
          end
        when 'unassign'
          user.pbx_pool = nil
          flash[:status] = _('user_was_successfully_unassigned') if user.save
      end
    else
      flash[:notice] = _('user_must_be_selected')
    end
    redirect_to action: :pbx_pool_users, id: params[:id].to_i
  end

  private

  def find_pbx_function
    @pbx_function = Pbxfunction.where({:id => params[:id]}).first
    unless @pbx_function
      flash[:notice] = _('Pbx_functions_was_not_found')
      redirect_to :controller => "pbx_functions", :action => 'pbx_functions' and return false
    end
  end

  def check_pbx_addon
    if !pbx_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to :root and return false
    end
  end

  def find_pbx_pool
    @pbx_pool = PbxPool.where(id: params[:id], owner_id: current_user.id).first
    unless @pbx_pool
      flash[:notice] = _('pbx_pool_was_not_found')
      redirect_to action: 'pbx_pools_list' and return false
    end
  end
end
