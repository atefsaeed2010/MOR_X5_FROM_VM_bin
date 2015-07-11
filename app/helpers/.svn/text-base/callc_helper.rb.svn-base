# -*- encoding : utf-8 -*-
module CallcHelper
  def find_user(value)
    user = User.find(value)
  end

  def find_engine_gateway
  	engine = GatewayEngine.find(:enabled, {:for_user => current_user.id}).enabled_by(current_user.owner_id)
  end

  def request_maches
  	request.env["HTTP_USER_AGENT"] and (request.env["HTTP_USER_AGENT"].match("iPhone") or request.env["HTTP_USER_AGENT"].match("iPod"))
  end

  def b_cog
    image_tag('icons/cog.png') + " "
  end

  def nice_web(string)
    if string.include?("http//") || string.include?("http://") || string.include?("https//") || string.include?("https://")
      web = string
    else
      web = 'http://' + string.to_s
    end

    return web.to_s
  end

  def gateway_link(name, engine, gateway)
    external = gateway.settings['external'].to_s

    if external == "true" # external payments have no menu, so show only logo IMG
      return gateway_logo(gateway, {:style => 'border-style:none', :title => name.to_s.gsub("_", " ").capitalize})
    else
      return link_to(gateway_logo(gateway, {:style => 'border-style:none', :title => name.to_s.gsub("_", " ").capitalize}), {:controller => "payment_gateways/#{engine}/#{name}"}, {:id => "#{engine}_#{name}"})
    end
  end

  def can_view_forgot_password?
    return (
      (Confline.get_value("Email_Sending_Enabled", 0).to_i == 1) &&
      (!Confline.get_value("Email_Smtp_Server", 0).to_s.blank?) &&
      (Confline.get_value("Show_forgot_password", session[:owner_id].to_i).to_i == 1)
      )
  end
end
