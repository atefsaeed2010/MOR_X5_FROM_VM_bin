# -*- encoding : utf-8 -*-
module DidsHelper
  def did_user_info(did, user)
    user_info = ''
    if user and did
      unless did.reseller_id > 0 and user.id == 0
        if user.owner_id == correct_owner_id
          user_info = link_to(nice_user(user), {:controller => "users", :action => "edit", :id => did.user_id}, {:id => "user_link"+ did.id.to_s})
        else
          user_info = nice_user(user)
        end
      end
    end
    return user_info
  end

  def did_reseller_info(did)
    if did and did.reseller_id.to_i > 0 and did.reseller and ["admin", "accountant"].include?(current_user.usertype)
      b_user_gray(:title => nice_user(did.reseller)) + "\n" + nice_user(did.reseller)
    end
  end

  def format_dialplan(did)
    did.dialplan_id != 0 ? dialplan = did.dialplan : dialplan = nil
    if dialplan
      dp = did.dialplan
      case dp.dptype
        when 'pbxfunction'
          link_to dp.name + " (" + dp.dptype + ")", {:controller => :functions, :action => :pbx_function_edit, :id => dp.id}
        when 'quickforwarddids'
          dp.name + " (" + dp.dptype + ")"
        when 'ringgroup'
          link_to dp.name + " (" + dp.dptype + ")", {:controller => :ringgroups, :action => :edit, :id => dp.data1}
        when 'queue'
          link_to dp.name + " (" + dp.dptype + ")", {:controller => :ast_queues, :action => :edit, :id => dp.data1}
        else
          link_to dp.name + " (" + dp.dptype + ")", {:controller => :dialplans, :action => :edit, :id => dp.id}
      end
    end
  end

  def show_call_limit(did)
    did.call_limit.to_i == 0 ? _('Unlimited') : did.call_limit
  end

  def format_device(did, device, link = 1)
    cont = []
    if device
      if link == 1
        cont << link_nice_device(device)
      else
        cont << nice_device(device)
      end
      if not (accountant? or link == 0) and pbx_active?
        cont << link_to(b_callflow, :controller => "devices", :action => "callflow", :id => did.device_id)
      end
    end
    cont.join("\n")
  end

  def limited_number_of_dids(dial_plan)
    if (dial_plan.dptype == 'callback') and not callback_active?
      dial_plan.dids.limit(1)
    else
      dial_plan.dids
    end
  end

  def dids_summary_clear_search_on
    date_from = DateTime.new(session[:year_from].to_i, session[:month_from].to_i, session[:day_from].to_i, 0, 0, 0).strftime("%Y-%m-%d %H:%M:%S")
    date_till = DateTime.new(session[:year_till].to_i, session[:month_till].to_i, session[:day_till].to_i, 23, 59, 59).strftime("%Y-%m-%d %H:%M:%S")
    user_date_from = Time.current.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
    user_date_till = Time.current.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
    s = session[:dids_summary_list_options]

    return (
      date_from != user_date_from or date_till != user_date_till or
      s[:d_search] != 1 or s[:did].present? or s[:did_search_from].present? or
      s[:did_search_till].present? or s[:provider] != 'any' or s[:user_id] != 'any' or
      s[:device_id] != 'all' or s[:sdays] != 'all' or s[:period] != '-1' or
      s[:dids_grouping] != 1
    )
  end

  def see_providers_in_dids?
    return (
      (current_user.reseller_allow_providers_tariff? && current_user.usertype == 'reseller') ||
      ['admin', 'accountant'].include?(current_user.usertype)
      )
  end

  def iwantto_list(links)
    out = []

    if links && (links.size > 0) && (session[:hide_iwantto].to_i == 0)
      out << "<br><br>"
      out << b_help + _('I_want_to')+ ":" + "<br>".html_safe
      out << "<ul class='iwantto_help'>"
      links.each { |arr| out << "<li><a href='#{arr[1].to_s}' target='_blank'>#{_(arr[0])}</a></li>" }
      out << "</ul>"
    end

    out.join("\n")
  end
end
