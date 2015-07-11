# -*- encoding : utf-8 -*-
# for test
module AlertsHelper

  def alerts_new_contact_timezone(cache = {})
    if cache.try(:[], :timezone).blank?
      Time.zone.formatted_offset
    else
      cache[:timezone]
    end
  end

  def alerts_edit_selected_timezone(offset = nil)
    if offset
      if offset.to_s.include?('-')
        offset = offset.to_s.insert(1, ((offset.to_s.size < 3) ? '0' : ''))
        "#{offset}:00"
      else
        offset = offset.to_s.insert(0, ((offset.to_s.size < 2) ? '0' : ''))
        "+#{offset}:00"
      end
    end
  end

  def nice_alert_timezone(offset = nil)
    if offset
      offset = offset.to_s.insert(0, ((offset.to_s.size < 2) ? '0' : ''))
      _('gmt') + offset.insert(0, (offset.to_i >= 1 ? ' +' : ' ')) + ":00"
    end
  end

  def periods_order
    return "CASE day_type WHEN 'all days' THEN 1 WHEN 'monday' THEN 2 WHEN 'tuesday' THEN 3 WHEN 'wednesday' THEN 4 " +
           "WHEN 'thursday' THEN 5 WHEN 'friday' THEN 6 WHEN 'saturday' THEN 7 WHEN 'sunday' THEN 8 END"
  end

  def fetch_periods(periods = [], local = false)
    buffer = String.new
    if periods.any?
      periods.each do |period|
        buffer << (
          _(period.day_type.gsub(' ','_').capitalize) +
          ' ' +
          period.start.strftime("%H:%M") +
          " - " +
          period.end.strftime("%H:%M") +
          (local ? '' : '<br />')
        )
      end
    end
    return buffer.html_safe
  end

  def nice_schedule_period(period, blank = false, day_type = nil)
    buffer = String.new
    buffer << (
      "<div id=\"periods_#{period.id}_#{period.day_type}\" style=\"width: 230px;\">".html_safe +
      ( day_type ? hidden_field_tag("periods[#{period.id}][day_type]", period.day_type) : '' ) +
      select_hour(period.start.try(:hour), { prefix: "periods[#{period.id}][start]", include_blank: blank}) +
      ' : ' +
      select_minute(period.start.try(:min), { prefix: "periods[#{period.id}][start]", include_blank: blank}) +
      ' - ' +
      select_hour(period.end.try(:hour), { prefix: "periods[#{period.id}][end]", include_blank: blank}) +
      ' : ' +
      select_minute(period.end.try(:min), { prefix: "periods[#{period.id}][end]", include_blank: blank}) +
      link_to(b_delete, 'javascript:void(0)', onclick: "drop_period(#{period.id}, '#{period.day_type}');") +
      '</div>'.html_safe
    )
    return buffer
  end

  def generate_parameters(alert_type, alert_type_parameters)
    return raw (select_tag('alert[alert_type]', options_for_select(alert_type_parameters.map {|a_type| [_(a_type.upcase), a_type]}, alert_type), :id => 'alert_type_parameters').squish)
  end

  def generate_check_data(alert)
    return _('All') if alert.check_data == 'all'
    if alert.check_type == "user"
      if is_numeric?(alert.check_data)
        u = User.where(id: alert.check_data.to_i).first
        link_nice_user(u).to_s.html_safe
      else
        alert.check_data
      end
    elsif alert.check_type == "device"
      d = Device.where(id: alert.check_data.to_i).first
      link_nice_device(d).to_s.html_safe if d
    elsif alert.check_type == "provider"
      p = Provider.where(id: alert.check_data.to_i).first
      link_nice_provider(p).to_s.html_safe if p
    elsif alert.check_type == "destination"
      alert.check_data.to_s
    elsif alert.check_type == "destination_group"
      dg = Destinationgroup.select("id, CONCAT(name, ' ', desttype) as gname").where(id: alert.check_data.to_i).order("name ASC, desttype ASC").first
      link_to(dg.gname, :controller => :destination_groups, :action => :edit, :id => dg.id) if dg
    end
  end

  def count_group_contacts(group_id)
    AlertContactGroup.where(:alert_group_id => group_id).size
  end

  def nice_group_schedule(schedule)
    if schedule.blank?
      return _('no_schedule_selected')
    else
      return schedule.name
    end
  end

  def reject_with_circles(alerts)
    alerts.reject do |alert|
      dependency = AlertDependency.new(owner_alert_id: session[:current_alert_id], alert_id: alert.id)
      AlertDependency.cycle_exists?(dependency)
    end
  end

  def nice_alert(alert)
    name = (alert.name.to_s.length > 0) ? alert.name : 'Alert_' + alert.id.to_s

    return link_to name, {:controller => "alerts", :action => "alert_edit", :id => alert.id}
  end
end
