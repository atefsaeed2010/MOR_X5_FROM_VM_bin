# -*- encoding : utf-8 -*-
# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include SqlExport
  include UniversalHelpers
  #    def ApplicationHelper::reset_values
  #      @nice_number_digits = nil
  #    end

  def tooltip(title, text)
    raw "onmouseover=\"Tip(\' #{text.to_s.gsub('"', '&quot;')} \', WIDTH, -600, TITLE, '#{title}', TITLEBGCOLOR, '#494646', FADEIN, 200, FADEOUT, 200 )\" onmouseout = \"UnTip()\"".html_safe
  end

  def draw_flag(country_code)
    unless country_code.blank?
      image_tag("/images/flags/" + country_code.to_s.downcase + ".jpg", :style => 'border-style:none', :title => country_code.to_s.upcase)
    end
  end

  def draw_flag_by_code(flag)
    unless flag.blank?
      image_tag("/images/flags/" + flag + ".jpg", :style => 'border-style:none', :title => flag.upcase)
    end
  end

  def nice_time2(time)
    format = session[:time_format].to_s.blank? ? "%H:%M:%S" : session[:time_format].to_s
    t = time.respond_to?(:strftime) ? time : ('2000-01-01 ' + time.to_s).to_time
    t.strftime(format.to_s) if time
  end

  def nice_user_timezone(datetime)
    time = Time.zone.parse(datetime.to_s)
    format = session[:date_time_format].to_s.blank? ? "%Y-%m-%d %H:%M:%S" : session[:date_time_format].to_s
    d = time.strftime(format.to_s)
    return d
  end

  def nice_date_time(time, options={})
    if time
      if options
        format = options[:date_time_format].to_s.blank? ? "%Y-%m-%d %H:%M:%S" : options[:date_time_format].to_s
      else
        format = session[:date_time_format].to_s.blank? ? "%Y-%m-%d %H:%M:%S" : session[:date_time_format].to_s
      end
      t = time.respond_to?(:strftime) ? time : time.to_time
      d = t.strftime(format.to_s)
    end
    d
  end

  def nice_user_time_string(user)
    user_zone = ActiveSupport::TimeZone.new(user.time_zone.to_s)
    "(GMT#{user_zone.now.formatted_offset}) #{user_zone.name}" if user_zone.present?
  end

  def nice_system_time_string
    Time.now.zone.include?('(GMT') ? ActiveSupport::TimeZone[Time.now.zone] : "(GMT#{Time.now.formatted_offset}) #{Time.now.zone}"
  end

  def nice_date(date, options={})
    if date
      if options
        format = options[:date_format].to_s.blank? ? "%Y-%m-%d" : options[:date_format].to_s
      else
        format = session[:date_format].to_s.blank? ? "%Y-%m-%d" : session[:date_format].to_s
      end
      t = date.respond_to?(:strftime) ? date : date.to_time
      if format.to_s.include?("H")
        @date = format.to_s.split(" ")
        format = @date[0] == "00:00:00" ? @date[1].to_s : @date[0].to_s
      end
      d = t.strftime(format.to_s)
    end
    d
  end

  def nice_number(number, options = {})
    n = "0.00"
    if options[:nice_number_digits]
      n = sprintf("%0.#{options[:nice_number_digits]}f", number.to_d) if number
      if options[:change_decimal]
        n = n.gsub('.', options[:global_decimal])
      end
    else
      nice_number_digits = (session and session[:nice_number_digits]) or Confline.get_value("Nice_Number_Digits")
      nice_number_digits = 2 if nice_number_digits == ''
      n = sprintf("%0.#{nice_number_digits}f", number.to_f) if number
      if session and session[:change_decimal]
        n = n.gsub('.', session[:global_decimal])
      end
    end
    n
  end

  def nice_bytes(bytes = 0, sufix_stop = "")
    bytes = bytes.to_d
    sufix_pos = 0
    sufix = ["b", "Kb", "Mb", "Gb", "Tb"]
    if  sufix_stop == "" or !sufix.include?(sufix_stop)
      while bytes >= 1024 do
        bytes = bytes/1024
        sufix_pos += 1
      end
    else
      while sufix[sufix_pos] != sufix_stop
        bytes = bytes/1024
        sufix_pos += 1
      end
    end
    session[:nice_number_digits] ||= Confline.get_value("Nice_Number_Digits").to_i
    session[:nice_number_digits] ||= 2
    bytes = 0 unless bytes
    n = sprintf("%0.#{session[:nice_number_digits]}f", bytes.to_d) + " " + sufix[sufix_pos].to_s
    if session[:change_decimal]
      n = n.gsub('.', session[:global_decimal])
    end
    n
  end

  def nice_number_currency(number, exchange_rate = 1)
    number = number * exchange_rate.to_d if number
    n = ""
    n = sprintf("%0.#{session[:nice_number_digits]}f", number) if number
    if session[:change_decimal]
      n = n.gsub('.', session[:global_decimal])
    end
    n
  end

  # shows nice
  def nice_src(call, options={})
    value = Confline.get_value("Show_Full_Src")
    srt = call.clid.split(' ')
    name = srt[0..-2].join(' ').to_s.delete('"')
    number = call.src.to_s
    if options[:pdf].to_i == 0
      session[:show_full_src] ||= value
    end
    if value.to_i == 1 and name.length > 0
      return "#{number} (#{name})"
    else
      return "#{number}"
    end
  end

  # converting caller id like "name" <11> to 11
  def cid_number(cid)
    if cid and cid.index('<') and cid.index('>')
      cid = cid[cid.index('<')+1, cid.index('>') - cid.index('<') - 1]
    else
      cid = ''
    end
    cid
  end

  def session_from_datetime
    sfd = session[:year_from].to_s + "-" + good_date(session[:month_from].to_s) + "-" + good_date(session[:day_from].to_s) + " " + good_date(session[:hour_from].to_s) + ":" + good_date(session[:minute_from].to_s) + ":00"
  end

  def session_till_datetime
    sfd = session[:year_till].to_s + "-" + good_date(session[:month_till].to_s) + "-" + good_date(session[:day_till].to_s) + " " + good_date(session[:hour_till].to_s) + ":" + good_date(session[:minute_till].to_s) + ":59"
  end

  # ================ BUTTONS - ICONS =============
  def b_comment_edit(title)
    image_tag('icons/comment_edit.png', :title => title) + " "
  end

  def b_sort_desc
    image_tag('icons/bullet_arrow_down.png') + " "
  end

  def b_sort_asc
    image_tag('icons/bullet_arrow_up.png') + " "
  end

  def b_server
    image_tag('icons/server.png') + " "
  end

  def b_arrow_down_blue
    image_tag('icons/arrow_down_blue.png') + " "
  end

  def b_arrow_up_blue
    image_tag('icons/arrow_up_blue.png') + " "
  end

  def b_add
    image_tag('icons/add.png', :title => _('Add')) + " "
  end

  def b_down
    image_tag('icons/arrow_down.png', :title => _('Down')) + " "
  end

  def b_delete(options={})
    opts = {:title => _('Delete')}.merge(options)
    image_tag('icons/delete.png', :title => opts[:title]) + " "
  end

  def b_unassign(options={})
    opts = {:title => _('Unasssign user')}.merge(options)
    #TODO:get sutable icon, maybe user_delete
    image_tag('icons/user_delete.png', :title => opts[:title]) + " "
  end

  def b_hangup
    image_tag('icons/delete.png', :title => _('Hangup')) + " "
  end

  def b_edit
    image_tag('icons/edit.png', :title => _('Edit')) + " "
  end

  def b_back
    image_tag('icons/back.png', :title => _('Back')) + " "
  end

  def b_view
    image_tag('icons/view.png', :title => _('View')) + " "
  end

  def b_payments
    image_tag('icons/view.png', :title => _('Payments')) + " "
  end

  def b_details(txt = " ")
    image_tag('icons/details.png', :title => _('Details')) + txt
  end

  def b_user
    image_tag('icons/user.png', :title => _('User')) + " "
  end

  def b_reseller
    image_tag('icons/user_gray.png', :title => _('Reseller')) + " "
  end

  def b_user_gray(options = {})
    opts = {:title => _('User')}.merge(options)
    image_tag('icons/user_gray.png', :title => opts[:title]) + " "
  end

  def b_members
    image_tag('icons/group.png', :title => _('Members')) + " "
  end

  def b_chart_bar(options = {})
    opts = {:title => _('Info')}.merge(options)
    image_tag('icons/chart_bar.png', :title => opts[:title]) + " "
  end

  def b_info(options = {})
    opts = {:title => _('Info')}.merge(options)
    image_tag('icons/information.png', :title => opts[:title]) + " "
  end

  def b_forward
    image_tag('icons/forward.png', :title => "") + " "
  end

  def b_play
    image_tag('icons/play.png', :title => _('Play')) + " "
  end

  def b_download
    image_tag('icons/download.png', :title => _('Download')) + " "
  end

  def b_music
    image_tag('icons/music.png', :title => _('Recording')) + " "
  end

  def b_record
    image_tag('icons/music.png', :title => _('Recording')) + " "
  end

  def b_device
    image_tag('icons/device.png', :title => _('Device')) + " "
  end

  def b_check(options ={})
    options[:id] = "icon_chech_"+options[:id].to_s if options[:id]
    image_tag('icons/check.png', {:title => "check"}.merge(options)) + " "
  end

  def b_csv
    image_tag('icons/excel.png', :title => _('CSV')) + " "
  end

  def b_pdf
    image_tag('icons/pdf.png', :title => _('PDF')) + " "
  end

  def b_cross(options = {})
    options[:id] = "icon_cross_"+options[:id].to_s if options[:id]
    image_tag('icons/cross.png', {:title => "cross"}.merge(options)) + " "
  end

  def b_cart_go
    image_tag('icons/cart_go.png', :title => "") + " "
  end

  def b_cart_empty
    image_tag('icons/cart_delete.png', :title => "") + " "
  end

  def b_cart_checkout
    image_tag('icons/cart_edit.png', :title => "") + " "
  end

  def b_help
    image_tag('icons/help.png', :title => "") + " "
  end

  def b_money
    image_tag('icons/money.png', :title => _('Add_manual_payment')) + " "
  end

  def b_groups
    image_tag('icons/groups.png', :title => _('Groups')) + " "
  end

  def b_subscriptions
    image_tag('icons/layers.png', :title => _('Subscriptions')) + " "
  end

  def b_rates
    image_tag('icons/coins.png', :title => _('Rates')) + " "
  end

  def b_crates
    image_tag('icons/coins.png', :title => _('Custom_rates')) + " "
  end

  def b_actions(options = {})
    image_tag('icons/actions.png', {:title => _('Actions')}.merge(options)) + " "
  end

  def b_undo
    image_tag('icons/undo.png', :title => _('Undo')) + " "
  end

  def b_generate
    image_tag('icons/application_go.png', :title => _('Generate')) + " "
  end

  def b_providers
    image_tag('icons/provider.png', :title => _('Providers')) + " "
  end

  def b_provider_ani
    image_tag('icons/provider_ani.png', :title => _('Provider_with_ANI')) + " "
  end

  def b_date
    image_tag('icons/date.png', :title => "") + " "
  end

  def b_call
    image_tag('icons/call.png', :title => "") + " "
  end

  def b_call_info
    image_tag('icons/information.png', :title => _('Call_info')) + " "
  end

  def b_trunk
    image_tag('icons/trunk.png', :title => _('Trunk')) + " "
  end

  def b_trunk_ani
    image_tag('icons/trunk_ani.png', :title => _('Trunk_with_ANI')) + " "
  end

  def b_rates_delete
    image_tag('icons/coins_delete.png', :title => _('Rates_delete')) + " "
  end

  def b_provider
    image_tag('icons/provider.png', :title => _('Provider')) + " "
  end

  def b_currency
    image_tag('icons/money_dollar.png', :title => _('Currency')) + " "
  end

  def b_cli
    image_tag('icons/cli.png', :title => _('CLI')) + " "
  end

  def b_lcr
    image_tag('icons/arrow_switch.png', :title => _('LCR')) + " "
  end

  def b_exclamation(options = {})
    image_tag('icons/exclamation.png', options) + " "
  end

  def b_extlines
    image_tag('icons/asterisk.png', :title => _('Extlines')) + " "
  end

  def b_online
    image_tag('icons/status_online.png', :title => _('Logged_in_to_GUI')) + " "
  end

  def b_offline
    image_tag('icons/status_offline.png', :title => _('Not_Logged_in_to_GUI')) + " "
  end

  def b_search(options = {})
    opts = {:title => _('Search')}.merge(options)
    image_tag('icons/magnifier.png', opts) + " "
  end

  def b_callflow
    image_tag('icons/cog_go.png', :title => _('Call_Flow')) + " "
  end

  def b_voicemail
    image_tag('icons/voicemail.png', :title => _('Voicemail')) + " "
  end

  def b_warning
    image_tag('icons/error.png', :title => _('Warning')) + " "
  end

  def b_rules
    image_tag('icons/page_white_gear.png', :title => _('Provider_rules')) + " "
  end

  def b_login_as(options = {})
    opts = {:title => _('Login_as')}.merge(options)
    image_tag('icons/application_key.png', opts) + " "
  end

  def b_call_tracing
    image_tag('icons/lightning.png', :title => _('Call_Tracing')) + " "
  end

  def b_test
    image_tag('icons/lightning.png', :title => _('Test')) + " "
  end

  def b_primary_device
    image_tag('icons/star.png', :title => _('Primary_device')) + " "
  end

  def b_email_send
    image_tag('icons/email_go.png', :title => _('Send')) + " "
  end

  def b_fax
    image_tag('icons/printer.png', :title => _('Fax')) + " "
  end

  def b_email(options = {})
    opts = {:title => _('Email')}.merge(options)
    image_tag('icons/email.png', opts) + " "
  end

  def b_refresh
    image_tag('icons/arrow_refresh.png', :title => _('Refresh')) + " "
  end

  def b_refresh_print
    image_tag('icons/arrow_refresh_and_printer.png', :title => _('Refresh_with_Invoice')) + " "
  end

  def b_view_colums
    image_tag('icons/application_view_columns.png', :title => _('View_Coulmns')) + " "
  end

  def b_hide
    image_tag('icons/contrast.png', :title => _('Hide')) + " "
  end

  def b_unhide
    image_tag('icons/contrast.png', :title => _('Unhide')) + " "
  end

  def b_call_stats
    image_tag('icons/chart_bar.png', :title => _('Call_Stats')) + " "
  end

  def b_fix
    image_tag('icons/wrench.png', :title => _('Fix')) + " "
  end

  def b_virtual_device
    image_tag('icons/virtual_device.png', :title => _('Virtual_Device')) + " "
  end

  def b_book
    image_tag('icons/book.png', :title => _('Phonebook')) + " "
  end

  def b_restore
    image_tag('icons/database_refresh.png', :title => _('Restore')) + " "
  end

  def b_download
    image_tag('icons/database_go.png', :title => _('Download')) + " "
  end



  def print_tech(tech)
    if tech
      tech = Confline.get_value("Change_dahdi_to") if tech.downcase == "dahdi" and Confline.get_value("Change_dahdi").to_i == 1
    else
      tech = ""
    end
    tech
  end

  # draws correct picture of device
  def nice_device_pic(device, options = {})
    provider = device.provider
    d = ""
    d = b_device if device.device_type == "SIP" or device.device_type == "IAX2" or device.device_type == "H323" or device.device_type == "dahdi"
    d = b_trunk if device.istrunk == 1 and device.ani and device.ani == 0
    d = b_trunk_ani if device.istrunk == 1 and device.ani and device.ani == 1
    d = b_fax if device.device_type == "FAX"
    d = b_virtual_device if device.device_type == "Virtual"
    d = b_provider if provider
    d.html_safe
  end

  def nice_device_type(device, options = {})
    opts = {
        :image => true,
        :tach => true
    }.merge(options)
    d = []
    d << nice_device_pic(device) if opts[:image] == true
    d << print_tech(device.device_type) if opts[:tech] == true
    d.join("\n").html_safe
  end


  def nice_device(device, options = {})
    opts = {
        :image => true,
        :tech => true
    }.merge(options)
    d = ""
    if device
      d = nice_device_type(device, opts) + "/"
      d += device.name.to_s.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') if !device.username.blank? and device.device_type != "FAX"
      d += device.extension.to_s if device.device_type == "FAX"  or !device.name or device.name.length == 0 or device.username.blank?
    end

    d.html_safe
  end

  def nice_device_no_pic(device)
    d = ""
    if (device)
      d = print_tech device.device_type.to_s + "/"
      d += device.name if device.device_type != "FAX"
      d += device.extension if device.device_type == "FAX" or device.name.length == 0
    end
    d
  end

  def link_nice_device(device)
    if device
      if device.user_id != -1
        raw link_to nice_device(device).html_safe, :controller => "devices", :action => "device_edit", :id => device.id
      else

        provider = device.provider
        if provider
          link_to nice_device(device), :controller => "providers", :action => "edit", :id => provider.id
        end

      end
    else
      ''
    end
  end

  def to_utf(str = nil)
    if str
      str.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '?') if str.is_a? String
    else
      self.force_encoding('UTF-8').
          encode('UTF-8', invalid: :replace, undef: :replace, replace: '?') if self.is_a? String
    end
  end

  # Removes invalid characters for filename
  def validate_filename(filename, delimiter = '')
    filename.to_s.gsub(/[<,>,:,",|,?,*,\\,\/]/, delimiter)
  end

  def nice_user_by_id(user_id)
    user = User.where(id: user_id).first
    nice_user(user)
  end

  def link_nice_user_if_own(user)
    user = User.where(id: user).first if user.class != User
    if user
      (user.owner_id == correct_owner_id and user.usertype != 'admin') ? link_nice_user(user) : nice_user(user)
    else
      ''
    end
  end

  def nice_group(group)
    nu = group.name
    nu
  end

  def link_nice_user(user, options = {})
    raw link_to nice_user(user).html_safe, {controller: :users, action: :edit, id: user.id}.merge(options)
  end

  def link_nice_user_by_id(user_id)
    user = User.where(id: user_id).first
    link_nice_user(user)
  end

  def link_user_gray(user, options = {})
    link_to(b_user_gray({title: options[:title]}),
            {controller: :users, action: :edit, id: user.id}.merge(options.except(:title)))
  end

  def link_nice_group(group)
    link_to nice_group(group), controller: :cardgroups, action: :edit, id: group.id
  end

  def nice_server(server)
    if server
      _('Server') + '_' + server.id.to_s + ': ' + server.server_ip.to_s + '|' + server.hostname.to_s
    end
  end

  def confline(name, id = 0)
    MorLog.my_debug("confline from application_helper.rb is deprecated. Use Confline.get_value")
    MorLog.my_debug("Called_from :: #{caller[0]}")
    Confline.get_value(name, id)
  end

  # ================ DEBUGGING =============

  #put value into file for debugging
  def my_debug(msg)
    File.open(Debug_File, "a") { |f|
      f << msg.to_s
      f << "\n"
    }
  end

  def clean_value(value)
    #cv = value
    #remove columns from start and end
    #cv = cv[1..cv.length] if cv[0,1] == "\""
    #cv = cv[0..cv.length-2] if cv[cv.length-1,1] == "\""
    cv = value.to_s.gsub("\"", "")
    cv
  end

  # Returns HangupCauseCode message by code
  def get_hangup_cause_message(code)
    if session["hangup#{code.to_i}".intern]
      return session["hangup#{code.to_i}".intern].html_safe
    else
      line = Hangupcausecode.where(:code => code).first
      if line
        session["hangup#{code.to_i}".intern] = line.description.html_safe
      else
        session["hangup#{code.to_i}".intern] = ("<b>"+_("Unknown_Error")+"</b><br />").html_safe
      end
      return session["hangup#{code.to_i}".intern].html_safe
    end
  end

=begin rdoc
 Creates link with arrow image representing table sort header.

 *Params*

 * <tt>true_col_name</tt> - true field name of sql order by. E.g. users.first_name.
 * <tt>col_header_name</tt> - String to name the field in link. "User".
 * <tt>options</tt> - options hash

 * <tt>options[:order_desc]</tt> - 1 : order descending     2 : order ascending
 * <tt>options[:order_by]</tt> - string simmilar to true_col_name.
 *Returns*

 link_to with params for ordering.
=end

  def sortable_list_header(true_col_name, col_header_name, options)
    link_to(
        ((b_sort_desc if options[:order_by].to_s == true_col_name.to_s and options[:order_desc].to_i == 1).to_s+
            (b_sort_asc if options[:order_by].to_s == true_col_name.to_s and options[:order_desc].to_i == 0).to_s+
            col_header_name).html_safe, :action => params[:action], :search_on => 1, :order_by => true_col_name.to_s, :order_desc => (options[:order_by].to_s == true_col_name ? 1 - options[:order_desc].to_i : 1))
  end

  def nice_list_order(user_col_name, col_header_name, options, params_sort={})
    order_dir = (options[:order_desc].to_i == 1 ? 0 : 1)
    raw link_to(
            ((b_sort_desc if options[:order_desc].to_i== 1 and user_col_name.downcase == options[:order_by].to_s).to_s.html_safe+
                (b_sort_asc if options[:order_desc].to_i== 0 and user_col_name.downcase == options[:order_by].to_s).to_s.html_safe+
                col_header_name.to_s.html_safe).html_safe, {:action => params[:action], :order_by => user_col_name, :order_desc => order_dir, :search_on => params[:search_on]}.merge(params_sort), {:id => "#{user_col_name}_#{order_dir}"})
  end

  def nice_tariff(tariff)
    tariff.name
  end

  def nice_provider(provider)
    [provider.name, provider.id].join("/")
  end

  def link_nice_provider(provider)
    link_to(nice_provider(provider), :controller => :providers, :action => :edit, :id => provider.id)
  end

  def link_nice_tariff(tariff)
    out = "#{b_details} <b>#{_('Tariff')}: </b>"
    out << link_to(tariff.name, :controller => "tariffs", :action => "rates_list", :id => tariff.id, :st => "A")
  end

  def nice_lcr(lcr)
    lcr.name
  end

  def link_nice_lcr(lcr)
    link_to(nice_lcr(lcr), :controller => :lcrs, :action => :edit, :id => lcr.id)
  end

  def sanitize_to_id(name)
    name.to_s.gsub(']', '').gsub(/[^-a-zA-Z0-9:.]/, "_")
  end

  def ordered_list_header(true_col_name, user_col_name, col_header_name, options)
    raw link_to(
      (b_sort_desc if options[:order_by].to_s == true_col_name.to_s and options[:order_desc]== 1).to_s.html_safe+
      (b_sort_asc if options[:order_by].to_s == true_col_name.to_s and options[:order_desc]== 0).to_s.html_safe+
      _(col_header_name.to_s.html_safe), :action => params[:action], :search_on => 1, :order_by => user_col_name.to_s,
      :order_desc => (options[:order_by].to_s == true_col_name ? (1 - options[:order_desc].to_i) : 1)).html_safe
  end

  def gateway_logo(gateway, html_options = {})
    value = gateway.get(:config, "logo_image")
    url = (value.to_s.blank?) ? "/images/logo/#{gateway.name}_logo.gif" : "/images/logo/#{value}"
    image_tag(url, html_options)
  end

  def select_sound_file(object, method, value = nil, html_options = {})
    html_options.delete(:include_blank) ? select_options = [[_('None'), '']] : select_options = []
    if reseller? and !current_user.reseller_allow_providers_tariff?
      select_options += IvrSoundFile.includes(:ivr_voice).all.
          collect { |sf| ["#{sf.ivr_voice.voice}/#{sf.path}", sf.id] }.sort
    else
      select_options += IvrSoundFile.includes(:ivr_voice).where(user_id: correct_owner_id).all.
          collect { |sf| ["#{sf.ivr_voice.voice}/#{sf.path}", sf.id] }.sort
    end
    select(object.class.to_s.downcase, method, select_options,
           {selected: (value) ? value : object.send(method)}, html_options)
  end

  def hide_device_passwords_for_users
    session[:usertype] != 'admin' and session[:hide_device_passwords_for_users].to_i == 1
  end

 #  Generic settings group line. Can hold any helpers or HTML.
 # *Params*
 # +block+
  def settings_group_line(name, tip='', &block)
    cont = ["<tr #{tip}>"]
    cont << "<td width='30%'><b>#{name}:</b></td>"
    cont << "<td>"
    cont << block.call
    cont << "</td>"
    cont << "</tr>"
    cont.join("\n").html_safe
  end

  def settings_group_line(name, tip='', &block)
    "<tr #{tip}>\n<td width='30'></td>\n<td><b>#{name}:</b></td>\n<td>#{block.call}</td>\n</tr>"
  end

=begin
name -      text that will be dislpayed near checkbox
prop_name - form variable name
conf_name - name of confline that will be represented by checkbox.
=end

  def setting_boolean(name, prop_name, conf_name, owner_id = 0, html_options = {})
    settings_group_line(name, html_options[:tip]) {
      check_box_tag(prop_name.to_s, '1', Confline.get_value(conf_name.to_s, owner_id).to_i == 1, html_options)
    }
  end

  def settings_field(type, name, owner_id = 0, html_options = {})
    case type
      when :boolean then
        setting_boolean(_(name), name.downcase, name, owner_id, html_options)
      else
        settings_group_line("UNKNOWN TYPE", html_options[:tip]) {}
    end
  end

  def icon(name, options = {})
    opts = {:class => "icon " + name.to_s.downcase}.merge(options)
    content_tag(:span, "", opts)
  end

  # Optional parameter `currency` should be supplied if you want to convert users credit
  # to some particular currency. Note that currency is actualy currency name, not currency object
  def nice_credit(user, currency=nil)
    if user.credit and user.postpaid?
      if user.credit_unlimited?
        credit = _('Unlimited')
      else
        exchange_rate = currency ? Currency.count_exchange_rate(user.currency.name, currency) : 1
        credit = nice_number(exchange_rate * user.credit)
      end
    else
      credit = 0
    end
    credit
  end

  # if not user returns nil
  # if user returns tooltip that contains information about user tariff, lcr, credit,,
  # country and city.
  # referencial integrity may be broken hence if user.address
  def nice_user_tooltip(user)
    if user
      if reseller? and Lcr.where(:id => user.try(:lcr_id)).first.try(:user_id) != current_user.id
        user_details = raw "<b>#{_('Tariff')}:</b> #{user.try(:tariff_name)} <br> <b>#{_('Credit')}:</b> #{nice_credit(user)}".html_safe
      else
        user_details = raw "<b>#{_('Tariff')}:</b> #{user.try(:tariff_name)} <br> <b>#{_('LCR')}:</b> #{user.try(:lcr_name)}<br> <b>#{_('Credit')}:</b> #{nice_credit(user)}".html_safe
      end
      address_details = raw "<br> <b>#{_('Country')}:</b> #{user.try(:county)}<br> <b>#{_('City')}:</b> #{user.try(:city)}".html_safe
      tooltip('User details', (user_details + address_details).html_safe)
    end
  end

  def nice_tariff_rates_tolltip(tariff, dest_id, dest_id_d)
    if dest_id and dest_id.size.to_i > 0
      unless tariff.purpose == 'user'
        rates = Rate.includes([:ratedetails, :destination]).where(tariff_id: tariff, destination_id: dest_id).all
        string = ''
        rates.each { |r|
          r.ratedetails.each { |rr|
            string << "#{r.destination.prefix} : #{nice_time2 rr.start_time} - #{nice_time2 rr.end_time} => #{rr.rate} (#{tariff.currency}) <br />" }
        }
      else
        if dest_id_d and dest_id_d.size.to_i > 0
          rates = Rate.includes([:aratedetails, :destinationgroup]).where(tariff_id: tariff, destinationgroup_id: dest_id_d).all
          string = ''
          rates.each { |r|
            r.aratedetails.each { |rr|
              string << "#{r.destinationgroup.name} : #{nice_time2 rr.start_time} - #{nice_time2 rr.end_time}, #{rr.artype} => #{rr.price} (#{tariff.currency}) <br />" }
          }
        end
      end
      tooltip(tariff.name, string)
    end
  end

  def nice_rates_tolltip(rate)
    string = ""
    unless rate.tariff.purpose == 'user'
      rate.ratedetails.each { |rr|
        if rate.destination
          string << "#{rate.destination.prefix} : #{nice_time2 rr.start_time} - #{nice_time2 rr.end_time} => #{rr.rate} (#{rate.tariff.currency}) <br />"
        end
      }
    else
      rate.aratedetails.each { |rr|
        if rate.destinationgroup
          string << "#{rate.destinationgroup.name} : #{nice_time2 rr.start_time} - #{nice_time2 rr.end_time}, #{rr.artype} => #{rr.price} (#{rate.tariff.currency}) <br />"
        end
      }
    end
    tooltip(rate.tariff.name, string)
  end

  def nice_end_ivr_tooltip
    tooltip(_('End_IVR'), _('End_ivr_explanation'))

  end

  def nice_card(card)
    _('Card') + "/#" + card.number.to_s
  end

  def link_nice_card(card, options={})
    #returns a link to card, that should have been passed as parameter.
    #link text will be nice_card
    link_to_card(card, nice_card(card), options)
  end

  def link_to_card(card, value=nil, options={})
    #returns a link to card, that should have been passed as parameter.
    #link text will be whatever you passed as value or if nothing was
    #passed it'll be nice_card
    if value
      link = link_to value, {:controller => "cards", :action => "show", :id => card.id}.merge(options)
    else
      link = link_nice_card(card, options)
    end
    return link
  end

  def priority_table(items, object, type = "lcr")
    out = ""

    out << "<table style='border:1px solid #cccccc;'>"
    items.each{|item|
      out << "<tr id='item_" + item.id.to_s + "'>"
      if type == "lcr"
        out << "<td>"
          out << (object.provider_active(item.id) ? (image_tag 'icons/check.png', :title => _('Disable')) : (image_tag 'icons/cross.png', :title => _('Enable'))) + item.name.to_s
          unless current_user.usertype == 'reseller' and item.common_use == 1
            out << ":" + item.tech.to_s + ":" + (item.tariff ? item.tariff.name.to_s : "")
          end
        out << "</td>"
      elsif type == "queue"
        out << "<td id='agent_device_#{item.id}' style='width: 100px;'>#{nice_device(Device.where(:id => item.device_id).first)}</td>"
        out << "<td id='agent_penalty_#{item.id}' style='width: 100px;'>#{_('Penalty') + ": " + item.penalty.to_s}</td>"
        out << "<td id='agent_edit_#{item.id}'>"
        out <<   "<span onclick='Edit_agents(#{item.id}, #{item.penalty.to_s})'>#{b_edit}</span>"
        out << "</td>"
        out << "<td id='agent_delete_#{item.id}'>"
        out <<   "<span onclick='Delete_agents(#{item.id})'>#{b_delete}</span>"
        out << "</td>"
      elsif type == "queue_announcements"
        out << "<td>#{b_music + " " + item.path.to_s}</td>"
        out << "<td id='queue_announcement_delete_#{item.id}' align='center' style='width:25px;'>"
        out <<   "<span onclick='Delete_queue_announcement(#{item.id})'>#{b_delete}</span>"
        out << "</td>"
      end
      out << "<td align='center' style='width: 45px;'>"

      if type == "lcr"
        updating_place = "/lcrs/change_position?id=" + object.id.to_s + "&item_id=" + item.lcr_prov_id.to_s + "' + "
      elsif type == "queue"
        updating_place = "/ast_queues/change_position?agent_id=" + item.id.to_s + "&penalty=' + $('queue_agent_penalty').value +"
      elsif type == "queue_announcements"
        updating_place = "/ast_queues/change_announcement_position?id=" + item.id.to_s + "&queue_id=" + object.id.to_s + "' + "
      end

      td_id_to_update = (type == "queue_announcements" ? "sortable_table2" : "sortable_table")

      if items.size > 1
        if !items.first.eql?(item)
          out << "<a onClick=\"new Ajax.Updater('#{td_id_to_update}', '" + Web_Dir + updating_place + "'&direction=up', {asynchronous:false, evalScripts:true, onComplete:function(request){Element.hide('spinner');}, onLoading:function(request){Element.show('spinner');}})\">" + b_arrow_up_blue + "</a>"
        end
        if !items.last.eql?(item)
          out << "<a onClick=\"new Ajax.Updater('#{td_id_to_update}', '" + Web_Dir + updating_place + "'&direction=down', {asynchronous:false, evalScripts:true, onComplete:function(request){Element.hide('spinner');}, onLoading:function(request){Element.show('spinner');}})\">" + b_arrow_down_blue + "</a>"
        end
      end
      out << "</td>"
      out << "</tr>"
    }
    out << "</table>"
    out
  end

  def hide_gui_dst?
    settings = current_user.hide_destination_end.to_i
    if not admin? and [1,3,5,7].member? settings.to_i
      return true
    else
      return false
    end
  end

  def local_variables_for_partial(object)
    other_variables = [:@view_renderer, :@current_user, :@page_title, :@page_icon, :@view_flow, :@output_buffer,
                       :@virtual_path, :@asset_paths, :@javascript_include]
    Hash[object.instance_variables.delete_if{|var| var.to_s.include?('@_') || other_variables.member?(var)}.collect{|var| [var.to_s.sub('@', '').downcase.to_sym, eval(var.to_s)]}]
  end

  def nice_separator(value)
    @separator ||= Confline.get_value('Global_Number_Decimal')
    @separator = '.' if @separator.blank?
    value.to_s.try(:sub, /[\,\.\;]/, @separator)
  end

  # Renders email for current user
  def render_email(email_to_render, user)
    bin = binding()
    Email.email_variables(user).each { |key, value| Kernel.eval("#{key} = '#{value.gsub("'", "&#8216;")}'", bin) }
    ERB.new(email_to_render.body).result(bin).to_s
  end

  def show_recordings?
    Confline.get_value("Hide_recordings_for_all_users", 0).to_i == 0
  end

  def is_hebrew?(string)
    string[/[\u0591-\u06FF]+/]
  end

  def fix_hebrew(string)
    regex = /[\u0591-\u06FF]+([\"\'\;\:\.\,\?\!\@\$\%\^\&\*\(\)\-\_\+\=\\\/ ]*[\u0591-\u06FF]+)*/
    hebrew = string.match(regex)
    start, the_end = hebrew.begin(0), hebrew.end(0)

    (start.zero? ? '' : string[0..start-1]) + hebrew.to_s.reverse! + (the_end.eql?(string.to_s.length - start) ? '' : string[the_end..-1])
  end
end
