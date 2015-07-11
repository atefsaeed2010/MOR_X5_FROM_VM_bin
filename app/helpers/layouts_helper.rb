# -*- encoding : utf-8 -*-
module LayoutsHelper
  def current_user_permission
    current_user.usertype == 'user' and (current_user.owner and current_user.owner.reseller_allow_providers_tariff?)
  end

  def ad_active_and_user_permissions
    return (
      ad_active? and
      (!current_user.owner.is_reseller? or
      (current_user.owner.is_reseller? and current_user.owner.reseller_right("autodialer").to_i == 2))
      )
  end

  def user_permissions
    return (
      !current_user.owner.is_reseller? or
      (current_user.owner.is_reseller? and current_user.owner.reseller_right("autodialer").to_i == 2 and ad_active?)
      )
  end

  def res_campaigns?
    (current_user and current_user.reseller_right('autodialer').to_i == 2)
  end

  def b_user_log
    image_tag('icons/report_user.png', :title => _('User_log')) + " "
  end

  def currency_selector(diff = nil)
    currs = Currency.get_active
    out = "<table width='100%' class='simple'><tr><td align='right'>"

    for curr in currs
      out += "<b>" if curr.name == session[:show_currency]
      out += link_to("#{curr.name}", :currency => curr.name, :search_on => params[:search_on])
      out += "</b>" if curr.name == session[:show_currency]
    end

    out += "</td></tr></table>"
    out
  end

  def flag_list
    fl = ''

    if session[:tr_arr] and session[:tr_arr].size > 1
      for tr in session[:tr_arr]
        title = tr.name
        title += "/#{tr.native_name}" if tr.native_name.length > 0
        fl += "<a href='?lang=" + tr.short_name + "'> " + image_tag("/images/flags/#{tr.flag}.jpg", :style => 'border-style:none', :title => title) + "</a>"
      end
    end

    fl
  end

  def gateways_enabled_for(user)
    payment_gateway_active? and user and ["reseller", "admin"].include?(user.usertype)
  end

  def show_rates_for_users
    session[:show_rates_for_users].to_i == 1
  end
end
