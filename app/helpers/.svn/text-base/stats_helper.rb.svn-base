# -*- encoding : utf-8 -*-
module StatsHelper
  def show_call_dst(call, text_class)
    dest = Destination.where(prefix: call.prefix).first
    dest_txt = []
    if dest
      @direction_cache ||= {}
      direction = @direction_cache[dest.direction_code.to_s] ||= dest.direction
      dest_txt << "#{direction.name.to_s + " " if direction }#{dest.subcode} #{dest.name}"
    end
    dest_txt << _('User_dialed') + ': ' + (hide_gui_dst? ? call.dst[0..-4] + 'XXX' : call.dst)
    dest_txt << _('Prefix_used') + ': ' + call.prefix.to_s if call.prefix.to_s.length > 0

    rez = ["<td id='dst_#{call.id}'
                class='#{text_class}'
                align='left'
                onmouseover=\"Tip(\'#{ dest_txt.join('<br>') }\')\"
                onmouseout = \"UnTip()\">"]
    rez << (hide_gui_dst? ? call.localized_dst[0..-4] + 'XXX' : call.localized_dst)
    rez << '</td>'
    rez.join('').html_safe
  end

  def call_duration(call, text_class, call_type, own = false)
    rez = ["<td id='duration_#{call.id}' class='#{text_class}' align='center'>"]
    unless ['missed', 'missed_inc', 'missed_inc_all'].include?(call_type)
      rez << nice_time((own ? call.user_billsec : call.nice_billsec))
    else
      rez << nice_time(call.duration)
    end
    rez << '</td>'
    rez.join.html_safe
  end

  def active_calls_tooltip(call)
    lega = ''
    legb = ''
    pdd = ''

    if @ma_active
      lega = _('LegA_Codec') + ': ' + call['lega_codec'].to_s
      if call['answer_time']
        legb = _('LegB_Codec') + ': ' + call['legb_codec'].to_s
        pdd = _('PDD') + ': ' + call['pdd'].to_f.to_s + ' s'
      end
    end

    [
        _('Server') + ': ' + call['server_id'].to_s,
        _('UniqueID') + ': ' + call['uniqueid'].to_s,
        _('User_rate') + ': ' + call['user_rate'].to_s + ' ' + current_user.currency.name, lega, legb, pdd
    ].reject(&:blank?).join('<br />')
  end

  def Subscription.subscriptions_stats_order_by(options)
    case options[:order_by].to_s.strip
      when 'user'
        order_by = 'nice_user'
      when 'service'
        order_by = 'service_name'
      when 'price'
        order_by = 'service_price'
      when 'memo'
        order_by = 'memo'
      when 'added'
        order_by = 'added'
      when 'activation_start'
        order_by = 'activation_start'
      when 'activation_end'
        order_by = 'activation_end'
      else
        order_by = options[:order_by]
    end
    if order_by != ''
      order_by += (options[:order_desc].to_i == 0 ? ' ASC' : ' DESC')
    end
    return order_by
  end

  def graph_legend(labels = [])
    nice_legend = labels.each_with_index.map do |name, i|
      "<graph gid='#{i}'><title>#{_(name)}</title><line_width>2</line_width><fill_alpha>30</fill_alpha><bullet>round</bullet></graph>"
    end
    return nice_legend.join.gsub("\n", '')
  end

  def max(name = nil)
    case name
      when 'cpu_loadstats1'
        nil
      else
        120
    end
  end

  def unit(name = nil)
    case name
      when 'cpu_loadstats1'
        nil
      else
        '%'
    end
  end

  def time_untill_expire(record)
    time = Time.now
    out = 0
    if time > record.activation_start && (record.activation_end.blank? || time < record.activation_end || record.no_expire == 1)
      year_month = time.strftime('%Y-%m')
      data = FlatrateData.where(year_month: year_month, subscription_id: record.id).first
      out = data.seconds.to_i if data
      out = record.quantity.to_i * 60 - out
    end
    out
  end

  def limited_number(reseller)
    users_number = reseller.f_users.to_i
    if users_number > 2 && ((reseller.own_providers == 0 && !reseller_active?) || (reseller.own_providers == 1 && !reseller_pro_active?))
      return 2
    else
      return users_number
    end
  end

  def clear_stats_dids_search
    date_from = DateTime.new(session[:year_from].to_i, session[:month_from].to_i, session[:day_from].to_i, 0, 0, 0).strftime('%Y-%m-%d %H:%M:%S')
    date_till = DateTime.new(session[:year_till].to_i, session[:month_till].to_i, session[:day_till].to_i, 23, 59, 59).strftime('%Y-%m-%d %H:%M:%S')
    user_date_from = Time.current.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
    user_date_till = Time.current.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
    s = session[:stats_dids_search]
    return (date_from != user_date_from || date_till != user_date_till || s[:user_id].to_i != -2 || s[:provider_id].to_i != -1)
  end

  def show_device_and_callerid(call)
    device = Device.where(id: call.src_device_id).first
    if device
      device_provider = Provider.where(device_id: device.id).first
      if device_provider
        if device_provider.user_id == correct_owner_id
          link_to call.nice_src_device, {controller: 'providers', action: 'edit', id: device_provider.id}, {id: "device_edit_link_#{call.id}"}
        else
          call.nice_src_device
        end
      else
        device_user = device.user
        if device_user
          if [device_user.owner_id, device_user.id].member? correct_owner_id
            link_to call.nice_src_device, {controller: 'devices', action: 'device_edit', id: call.src_device_id}, {id: "device_edit_link_#{call.id}"}
          else
            call.nice_src_device
          end
        end
      end
    end
  end

  def device_with_owner(device)
    user = User.where(id: device.user_id).first
    user = User.where(id: user.owner_id).first if !user.is_reseller?
    nice_device(device) + ' (' + link_nice_user(user) + ')'
  end

  def provider_owner(provider)
    user = User.where(id: provider.user_id).first
    link_nice_user(user)
  end

  def distributor?
    Card.select("DISTINCT user_id").map(&:user_id).include?(session[:user_id].to_i)
  end

  def show_user_billsec?
    (user? and Confline.get_value("Invoice_user_billsec_show", current_user.owner.id).to_i == 1)
  end

  def reseller_pro?
    reseller? && (current_user.own_providers == 1)
  end

  def action_with_type(action)
    target_type, target_id = action['target_type'].to_s, action['target_id'].to_s
    if (target_type + target_id).strip.length > 0
      target_type + ' (' + target_id + ')'
    end
  end

  def session_from_date
    sfd = session[:year_from].to_s + "-" + good_date(session[:month_from].to_s) + "-" + good_date(session[:day_from].to_s)
  end

  def session_till_date
    sfd = session[:year_till].to_s + "-" + good_date(session[:month_till].to_s) + "-" + good_date(session[:day_till].to_s)
  end

  def b_logins
    image_tag('icons/chart_pie.png', :title => _('Logins')) + " "
  end

  def nice_device_from_data(dev_type, dev_name, dev_extension, dev_istrunk, dev_ani, options = {})
    d = ''
    d = b_device if dev_type == "SIP" or dev_type == "IAX2" or dev_type == "H323" or dev_type == "dahdi"
    d = b_trunk if dev_istrunk == 1 and dev_ani == 0
    d = b_trunk_ani if dev_istrunk == 1 and dev_ani == 1
    d = b_fax if dev_type == "FAX"
    d = b_virtual_device if dev_type == "Virtual"

    d += print_tech dev_type + "/"
    d += dev_name if dev_type != "FAX"
    d += dev_extension if dev_type == "FAX" or dev_name.length == 0

    if options[:link] == true and options[:device_id].to_i > 0
      d = link_to d, :controller => "devices", :action => "device_edit", :id => options[:device_id].to_i
    end

    d
  end

 # Sanitized provider name and link to provider edit if  required.
  def nice_provider_from_data(provider, options = {})
    np = h(provider.to_s)

    if options[:link] and options[:provider_id].to_i > 0
      np = link_to np, :controller => :providers, :action => :edit, :id => options[:provider_id].to_i
    end

    np
  end

  def nice_did_from_data(did, options = {})
    nd = h(did.to_s)

    if options[:link] and options[:did_id].to_i > 0
      nd = link_to nd, :controller => :dids, :action => :edit, :id => options[:did_id].to_i
    end

    nd
  end

  def nice_server_from_data(server, options = {})
    ns = h(server.to_s)

    if options[:link] and options[:server_id].to_i > 0
      ns = link_to ns, :controller => :servers, :action => :edit, :id => options[:server_id].to_i
    end

    ns
  end

  # Helper tha formats call debug info to be shown on a tooltip.
  def format_debug_info(hash)
    debug_text = 'PeerIP: ' + hash['peerip'].to_s + '<br>'
    debug_text += 'RecvIP: ' + hash['recvip'].to_s + '<br>'
    debug_text += 'SipFrom: ' + hash['sipfrom'].to_s + '<br>'
    debug_text += 'URI: ' + hash['uri'].to_s + '<br>'
    debug_text += 'UserAgent: ' + hash['useragent'].to_s + '<br>'
    debug_text += 'PeerName: ' + hash['peername'].to_s + '<br>'
    debug_text += 'T38Passthrough: ' + hash['t38passthrough'].to_s + '<br>'
    debug_text
  end

  def remote_sortable_list_header(true_col_name, col_header_name, options)
    # x5 rework needed
    # Previous prototype helper code that used to generate pretty much the same.
    #{:update => options[:update],
    #:url => {:controller => options[:controller].to_s, :action => options[:action].to_s, :order_by => true_col_name.to_s, :order_desc => (options[:order_by].to_s == true_col_name ? 1 - options[:order_desc] : 1)},
    #:loading => "Element.show('spinner');",
    #:complete => "Element.hide('spinner');"}
    raw link_to_function(
        (b_sort_desc.html_safe if options[:order_by].to_s == true_col_name.to_s and options[:order_desc]== 1).to_s.html_safe +
        (b_sort_asc.html_safe if options[:order_by].to_s == true_col_name.to_s and options[:order_desc]== 0).to_s.html_safe +
        col_header_name.html_safe,
        "new Ajax.Updater('#{options[:update]}',
                          '/billing/#{options[:controller].to_s}/#{options[:action].to_s}',
                          {asynchronous:true, evalScripts:true, onComplete:function(request){Element.hide('spinner');},
                          onLoading:function(request){Element.show('spinner');},
                          parameters:'order_by=#{true_col_name.to_s}&order_desc=#{options[:order_by].to_s == true_col_name ? 1 - options[:order_desc] : 1}'}
        );
        return false;",
        {:class => "sortable_column_header"}).html_safe
  end

  def active_call_bullet(call)
    if call.class == Call
      icon(call.answer_time.blank? ? 'bullet_yellow' : 'bullet_green')
    else
      icon(call['answer_time'].blank? ? 'bullet_yellow' : 'bullet_green')
    end
  end

  def spy_channel_icon(channel, id)
    return (
      link_to image_tag('icons/sound.png', :title => _('Spy_Channel')),
      {:controller => 'functions', :action => 'spy_channel', :id => id, :channel => channel},
      :onclick => "window.open(this.href,'new_window','height=40,width=300');return false;".html_safe
      )
  end

  def get_link_to_rate(rate)
    purpose = rate['purpose'].to_s
    if purpose == 'provider' || purpose == 'user_wholesale'
      'ratedetail_edit/' + rate['ratedetails_id'].to_s
    elsif purpose == 'user'
      'user_arates/' + rate['rate_id'].to_s + '?dt=' + rate['arate_daytype'].to_s + '&st=' +
      rate['arate_start_time'].try(:strftime, '%H:%M:%S').to_s
    end
  end

  def correct_providers_name(provider)
    if provider
      if provider.user_id == 0 && provider.common_use == 0
        _('admin')
      else
        provider.name
      end
    else
      ''
    end
  end
end
