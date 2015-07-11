# -*- encoding : utf-8 -*-
module DevicesHelper
  def draw_callflows(cfs)
    output = ''
    for cf in cfs
      case cf.action
        when 'empty'
          output << '-<br>'
        when 'forward'
          dev = Device.where(id: cf.data).first if cf.data2 == 'local'
          if cf.data2 == 'local'
            if dev
              output << _('Forward') << ' ' << b_forward << ' ' << dev.device_type << '/' << dev.name << '<br>'
            else
              output << _('Device_not_found')
            end
          end
          output << _('Forward') << ' ' << b_forward << ' ' << cf.data << '<br>' if cf.data2 == 'external'
          output << b_cross << _('Forward_not_functional_please_enter_dst') << '<br>' if cf.data2 == ''
        when 'voicemail'
          output << b_voicemail << _('VoiceMail') << '<br>'
        when 'fax_detect'
          dev = Device.where(id: cf.data).first if cf.data2 == 'fax'
          if dev and cf.data2 == 'fax'
            output << _('Fax_detect') << ': ' << b_fax << ' ' << dev.device_type << '/' << dev.extension << '<br>'
          else
            output << _('Fax_device_not_found')
          end
          output << b_cross << _('Fax_detect_not_functional_please_select_fax_device') << '<br>' if cf.data2 == ''
      end
    end
    output.html_safe
  end

  def print_cf_type(cft)
    o = ''
    case cft
      when 'before_call'
        o += _('Before_Call')
      when 'answered'
        o += _('Answered')
      when 'no_answer'
        o += _('No_Answer')
      when 'busy'
        o += _('Busy')
      when 'failed'
        o += _('Failed')
    end
    o
  end

  def b_bullet_white(title='')
    image_tag('icons/bullet_white.png', :title => title) + " "
  end

  def b_bullet_green(title='')
    image_tag('icons/bullet_green.png', :title => title) + " "
  end

  def b_bullet_red(title='')
    image_tag('icons/bullet_red.png', :title => title) + " "
  end

  def b_bullet_yellow(title='')
    image_tag('icons/bullet_yellow.png', :title => title) + " "
  end

  def b_bullet_black(title='')
    image_tag('icons/bullet_black.png', :title => title) + " "
  end

  def b_did
    image_tag('icons/did.png', :title => _('DID')) + " "
  end

  def user_link_nice_device(device)
    link_to nice_device(device), :controller => "devices", :action => "user_device_edit", :id => device.id
  end

  def link_nice_device_user(device)
    if device
      user = device.user

      if device.user_id == session[:user_id] or user.owner_id == session[:user_id]
        return link_nice_user(user)
      else
        owner = user.owner
        return link_user_gray(owner, {:title => _("This_user_belongs_to_Reseller") + ": " +nice_user(owner)}) + nice_user(user)
      end
    end
  end

  def device_code(code)
    name = 'Default_device_codec_' + code.to_s
    Confline.get_value(name, session[:user_id])
  end

  def device_reg_status(device)
    out, icon = ''
    device_reg_status = device.reg_status.to_s

    if device_reg_status.length == 0
      return out
    end

    if device_reg_status[0..1] == "OK"
      icon = 'icons/bullet_green.png'
      title = _('Device_Status_Ok')
    end

    if device_reg_status[0..5] == "LAGGED"
      icon = 'icons/bullet_yellow.png'
      title = _('Device_Status_Lagged')
    end

    case device_reg_status
    when 'Unmonitored'
      icon = 'icons/bullet_white.png'
      title = _('Device_Status_Unmonitored')
    when 'UNKNOWN'
      icon = 'icons/bullet_black.png'
      title = _('Device_Status_Unknown')
    when 'UNREACHABLE'
      icon = 'icons/bullet_red.png'
      title = _('Device_Status_Unreachable')
    end

    return image_tag(icon, :title => title)
  end
end
