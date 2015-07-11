# -*- encoding : utf-8 -*-
# Did rates
class DidRatesController < ApplicationController
  layout 'callc'
  before_filter :check_post_method, only: [:destroy, :create, :update, :owner_rate_save]
  before_filter :check_localization
  before_filter :authorize

  before_filter { |controller|
    view = [:index]
    edit = [:edit]
    allow_read, allow_edit = controller.check_read_write_permission(view, edit, {role: 'accountant',
                                                                                 right: :acc_manage_dids_opt_1,
                                                                                 ignore: true})
    controller.instance_variable_set :@allow_read, allow_read
    controller.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter :check_reseller
  before_filter :find_did, only: [:index, :owner_rate_save]
  before_filter :find_did_rate, only: [:edit, :update, :manage]

  def index
    @page_title = _('Did_rates')
    @page_icon = 'coins.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/DID_Billing'

    @did.check_did_rates

    @did_prov_rates_c, @did_incoming_rates_c, @did_owner_rates_c,
        @did_prov_rates_f, @did_incoming_rates_f, @did_owner_rates_f,
        @did_prov_rates_w, @did_incoming_rates_w, @did_owner_rates_w = Did.did_rates_index(@did)

    # DID Owner Rate by CallerID from Tariff
    @dids = Did.where(id: params[:id]).first
    @tariffs = Tariff.where(owner_id: correct_owner_id, purpose: 'user_wholesale').order('purpose ASC, name ASC')
    #######################################

    store_location
  end

  def edit
    @did = @did_rate.did
    @page_title = _('Edit_Did_rates') + ': ' + @did.did
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/DID_Billing'
  end

  def update
    did_rate_id = @did_rate.id
    did_rate_did_id = @did_rate.did_id
    if (params[:did_rate] and params[:did_rate][:end_time]) && ((nice_time2(@did_rate.start_time) > params[:did_rate][:end_time]) || (params[:did_rate][:end_time] > '23:59:59'))
      flash[:notice] = _('Bad_time')
      redirect_to action: 'edit', id: did_rate_id and return false
    end

    rdetails = @did_rate.did_rate_details
    if @did_rate.update_attributes(params[:did_rate])

      # we need to create new rd to cover all day
      if (nice_time2(@did_rate.end_time) != '23:59:59') && ((rdetails[(rdetails.size - 1)] == @did_rate))
        nrd = Didrate.create_by(@did_rate, start_time: @did_rate.end_time + 1.second, end_time: '23:59:59')
        if nrd.save
          Action.add_action_hash(current_user, action: 'did_rate_created', target_id: nrd.id, target_type: 'Didrate', data: nrd.did_id)
        end
      end

      Action.add_action_hash(current_user, action: 'did_rate_edited', target_id: did_rate_id, target_type: 'Didrate', data: did_rate_did_id)
      flash[:status] = _('Rate_details_was_successfully_updated')
      redirect_to action: 'index', id: did_rate_did_id
    else
      render :edit
    end
  end

  def manage
    rdetails = @did_rate.did_rate_details_all

    rdaction = params[:rdaction]

    if rdaction == 'COMB_WD'
      for rd in rdetails
        rd.update_daytype('WD')
      end
      flash[:status] = _('Rate_details_combined')
    end

    if rdaction == 'COMB_FD'
      for rd in rdetails
        rd.update_daytype('FD')
      end
      flash[:status] = _('Rate_details_combined')
    end

    if rdaction == 'SPLIT'

      for rd in rdetails
        nrd = Didrate.create_by(rd, daytype: 'FD')
        nrd.save

        rd.daytype = 'WD'
        rd.save
      end

      flash[:status] = _('Rate_details_split')
    end

    redirect_to action: 'index', id: @did_rate.did_id
  end

  def owner_rate_save
    params_did = params[:did]
    @dids = Did.where(id: params[:id]).first if params_did.present?
    if params_did.blank? || @dids.blank?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
    Didrate.owner_rate_save(@dids, params_did)
    flash[:status] = _('did_owner_tariff_changed')
    redirect_to action: :index, id: @did.id
  end

  def get_periods_for_search
    @periods = Didrate.find_hours_for_select(params)
    render(layout: false)
  end

  private

  def find_did
    @did = Did.where(id: params[:id].to_i).first
    if !@did || (@did.reseller_id != session[:user_id] && session[:usertype].to_s == 'reseller')
      flash[:notice] = _('DID_was_not_found')
      redirect_to(controller: :dids, action: :list) && (return false)
    end
  end

  def check_reseller
    if current_user.usertype == 'reseller'
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def find_did_rate
    @did_rate = Didrate.where(['id = ?', params[:id]]).first
    unless @did_rate
      flash[:notice] = _('Rate_was_not_found')
      redirect_to :root and return false
    end
  end
end
