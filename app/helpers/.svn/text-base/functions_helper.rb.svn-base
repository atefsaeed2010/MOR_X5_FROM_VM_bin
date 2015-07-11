# -*- encoding : utf-8 -*-
module FunctionsHelper
  def signup_url
    Web_URL.to_s + Web_Dir + "/callc/signup_start/" + current_user.get_hash
  end

  def homepage_url
    Web_URL.to_s + Web_Dir + "/callc/login/" + current_user.get_hash
  end

 # Wrapper to create settings grouping.

 # *Params*

 # +name+ - ID for group. Every group must have unique ID in HTML page. Othevise
 # it would be impossible to create gruop.
 # +height+ - height of the box.
 # +width+ - width of the box.
 # +block+ - HTML code to be wraped inside block.

 # *Helpers*

 # It is designed to be used with other settings helpers.
 # * setting_group_boolean - true/false settings
 # * settings_group_text - text field with numeric
 # * settings_group_number - text field with text value

  def settings_group(nice_name, id, width, height, &block)
    res = ["<div id='#{id}'>"]
    res << "<div class='dhtmlgoodies_aTab'>"
    res << "<table class='simple' width='100%'>"
    res << capture(&block)
    res << "</table>"
    res << "</div>"
    res << "</div>"
    dtree_group_script(nice_name, id, width, height)
    concat(res.join("\n").html_safe).html_safe
  end

 # Simple helper to generate script yhat shows tabs.
  def dtree_group_script(name, div_name, width, height)
    content_for :scripts do
      content_tag(:script, raw("initTabs('#{div_name}', Array('#{name}'),0,#{width},#{height});"), :type => "text/javascript").html_safe
    end
  end

 #  Boolean setting.

 # *Params*

 # +name+ - nice name. It will be displayed as a text near checkbox.
 # +prop_name+ - HTML name value. This will be sent to params[:prop_name] when you submit the form.
 # +conf_name+ - Confline name. This value will be selected when form is being generated.
  def setting_group_boolean(name, prop_name, conf_name, options = {})
    opts ={}.merge(options)
    settings_group_line(name, options[:tip]) {
      "#{check_box_tag prop_name, "1", Confline.get_value(conf_name, session[:user_id]).to_i == 1}#{opts[:sufix]}"
    }
  end

 #  Text setting.

 # *Params*

 # +name+ - nice name. It will be displayed as a text near text field.
 # +prop_name+ - HTML name value. This will be sent to params[:prop_name] when you submit the form.
 # +conf_name+ - Confline name. This value will be selected when form is being generated.
  def settings_group_text(name, prop_name, conf_name, options = {}, html_options = {})
    opts = {:sufix => ""}.merge(options)
    html_opts ={
        :class => "input",
        :size => "35",
        :maxlength => "50"}.merge(html_options)
    settings_group_line(name, html_options[:tip]) {
      "#{text_field_tag(prop_name, Confline.get_value(conf_name, session[:user_id]), html_opts)}#{opts[:sufix]}"
    }
  end

 #  numeric setting.

 # *Params*

 # +name+ - nice name. It will be displayed as a text near text field.
 # +prop_name+ - HTML name value. This will be sent to params[:prop_name] when you submit the form.
 # +conf_name+ - Confline name. This value will be selected when form is being generated.
  def settings_group_number(name, prop_name, conf_name, options = {}, html_options = {})
    opts = {:sufix => ""}.merge(options)
    html_opts ={
        :class => "input",
        :size => "35",
        :maxlength => "50"}.merge(html_options)
    settings_group_line(name, html_options[:tip]) {
      "#{text_field_tag(prop_name, Confline.get_value(conf_name, session[:user_id]).to_i, html_opts)}#{opts[:sufix]}"
    }
  end

  def limit_reseller
    if reseller?
      !(((User.where(owner_id: current_user.id).count < 2) or (current_user.own_providers == 0 and reseller_active?) or (current_user.own_providers == 1 and reseller_pro_active?)))
    end
  end

  def options_for_res_paypal_confirmation(paypal_payment_confirmation)
    options_for_select([[_('gateway_not_required'), 'none'],
                        [_('gateway_required_for_suspicious_payments'), 'suspicious'],
                        [_('gateway_required_for_all_payments'), 'all']],
                        paypal_payment_confirmation)
  end

  def options_for_webmoney_gateway(webmoney_gateway)
    options_for_select([[_("Russian"), 0], [_("English"), 1]], webmoney_gateway)
  end

  def find_data(current_user_id, prov_id)
    data = CommonUseProvider.includes(:tariff).where(reseller_id: current_user_id, provider_id: prov_id).first
  end

  def link_to_user(dialplan_data5)
    user = User.where(id: dialplan_data5).first
    user.present? ? link_nice_user(user) : ''
  end

  def check_role_name(role_name)
    ['admin', 'accountant', 'reseller', 'user'].include?(role_name)
  end

  def check_user_for_status(user)
    return (
      (user.postpaid == 1) && (user.credit != -1) && (user.balance + user.credit <= 0)
      )
  end

  def show_balance_line_setting?
    Confline.get_value("Show_balance_line_setting").to_i == 1 or Confline.get_value("Show_balance_line_setting").blank?
  end

  def long_nice_number(number)
    n = number ? sprintf("%0.6f", number) : ''

    if session[:change_decimal]
      n = n.gsub('.', session[:global_decimal])
    end

    n
  end

  def nice_month_name(i)
    {"1" => _('January'), "2" => _('February'), "3" => _('March'), "4" => _('April'),
      "5" => _('May'), "6" => _('June'), "7" => _('July'), "8" => _('August'),
      "9" => _('September'), "10" => _('October'), "11" => _('November'), "12" => _('December')}[i.to_s].to_s
  end

  def b_help_grey
    image_tag('icons/help_grey.png', :title => "") + " "
  end

  def dial_string(prov, dst, cut, add)
    cut = '' if not cut
    add = '' if not add
    ds = dst
    ds = '1234567890' if dst.length == 0

    if prov.device
      ds = print_tech(prov.tech) + "\\" + prov.device.name + "\\" + add + ds[cut.length..-1]
    else
      ds = print_tech(prov.tech).to_s + "\\" + prov.channel.to_s + "\\" + prov.add_a.to_s + ds[cut.length..-1].to_s
    end

    ds
  end

  def clean_value_all(value)
    cv = value.to_s

    while cv[0, 1] == "\"" or cv[0] == "'" do
      cv = cv[1..cv.length]
    end

    while cv[cv.length-1, 1] == "\"" or cv[cv.length-1, 1] == "'" do
      cv = cv[0..cv.length-2]
    end

    cv
  end

  def link_nice_tariff_if_own(tariff)
    if tariff
      tariff.owner_id == correct_owner_id ? link_nice_tariff_simple(tariff) : nice_tariff(tariff)
    else
      ''
    end
  end

  def link_nice_provider_if_own(provider)
    if provider
      provider.user_id == correct_owner_id ? link_nice_provider(provider) : nice_provider(provider)
    else
      ''
    end
  end

  def link_nice_lcr_if_own(lcr)
    if lcr
      lcr.user_id == correct_owner_id ? link_nice_lcr(lcr) : nice_lcr(lcr)
    else
      ''
    end
  end

  # suformuoja tabų pavadinimus javascriptui
  def gateway_tabs(gateway_names)
    gateway_names.collect { |gw| gw.inspect }.join(",").html_safe
  end

  # Empty line to be used *NOT* inside a group.
  def settings_empty_row
    "<tr><td width='30'></td><td>&nbsp;</td><td></td></tr>"
  end

 # name -      text that will be dislpayed near text field
 # prop_name - form variable name
 # conf_name - name of confline that will be represented by text field.
  def settings_string(name, prop_name, conf_name, owner_id = 0, html_options = {})
    settings_group_line(name, html_options[:tip]) {
      text_field_tag(prop_name.to_s, Confline.get_value(conf_name.to_s, owner_id).to_s,
        {"class" => "input", :size => "35", :maxlength => "50"}.merge(html_options))
    }
  end

  def link_show_devices_if_own(user, options = {})
    options[:text] ||= nice_user(user)

    if user.owner_id == correct_owner_id
      link_to(options[:text], :controller => :devices, :action => :show_devices, :id => user.id)
    else
      options[:text]
    end
  end
end
