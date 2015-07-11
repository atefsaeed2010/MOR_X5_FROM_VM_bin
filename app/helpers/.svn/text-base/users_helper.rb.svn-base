# -*- encoding : utf-8 -*-
module UsersHelper
  def allow_add_rs_user?
    user_limit = 2;
    not reseller? or ((User.where(owner_id: current_user.id).count < user_limit) or (reseller_active? and current_user.own_providers != 1) or reseller_pro_active?)
  end

  def show_reseller_users_restriction
    reseller? and (not reseller_active? or ((current_user.own_providers == 1) and not reseller_pro_active?))
  end

  def options_for_billing_period(billing_period)
    options_for_select( [[_('weekly_mon_sun'), 'weekly'], [_('bi_weekly'), 'bi-weekly'], [_('monthly_1_end'), 'monthly']], billing_period )
  end

  def user_invoice_grace_period(user, invoice_grace_period)
    user_invoice_grace_period = invoice_grace_period ? invoice_grace_period : user.invoice_grace_period.to_i
  end

  def user_permission(user, params)
  	return (
      (admin? or accountant?) and
      (params[:action] == 'default_user' or
      	((user.is_user? or user.is_reseller?) and user.owner_id.to_i == 0))
      )
  end

  def global_blacklist_threshold(user)
    if (user.routing_threshold.to_s == '-1') && (user.routing_threshold_2.to_s == '-1') &&
      (user.routing_threshold_3.to_s == '-1')
      radio_button = 'checked'
    else
      radio_button = 'false'
    end

    return radio_button
  end

  def not_global_blacklist_threshold(user)
    if global_blacklist_threshold(user) == 'checked'
      radio_button = 'false'
    else
      radio_button = 'checked'
    end

    return radio_button
  end

  def global_blacklist_lcrs(user)
    if (user.blacklist_lcr.to_s == '-1') && (user.blacklist_lcr_2.to_s == '-1') && (user.blacklist_lcr_3.to_s == '-1')
      radio_button = 'checked'
    else
      radio_button = 'false'
    end

    return radio_button
  end

  def not_global_blacklist_lcrs(user)
    if global_blacklist_lcrs(user) == 'checked'
      radio_button = 'false'
    else
      radio_button = 'checked'
    end

    return radio_button
  end

  def nice_agreement_date(user)
    ad = user.agreement_date
    ad = Time.now if !ad
    ad = ad.to_date if ad.class != Date
    earliest_date = (Time.now - 1000.year + 6.year).to_date
    latest_date  = (Time.now + 1000.year + 6.year).to_date
    ad = earliest_date if ad < earliest_date
    ad = latest_date if ad > latest_date
    ad
  end
end
