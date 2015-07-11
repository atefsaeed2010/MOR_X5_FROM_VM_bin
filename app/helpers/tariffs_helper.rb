# -*- encoding : utf-8 -*-
module TariffsHelper
  def destination_rate_details(rate, tariff)
    details_count = rate.ratedetails.size
    if (details_count == 1)
      link_text = nice_number(rate.ratedetails.first.try(:rate))
    else
      link_text = _('Details')
    end
    style = check_rate_active(rate)
    link_to b_details + link_text, {:action => 'rate_details', :id => rate.id}, :id => "details_img_"+rate.id.to_s, :style => style
  end

  def check_rate_active(rate)
    (@effective_from_active and rate.active == 0) ? "color: #BFBFBF;" : ""
  end

  def find_rates(tariff_id)
    Rate.where(tariff_id: tariff_id, destination_id: !0)
  end

  def finf_custom_rates(dg_id)
    Customrate.where(user_id: session[:user_id], destinationgroup_id: dg_id).first
  end

  def b_make_tariff
    image_tag('icons/application_add.png', :title => _('Make_tariff')) + " "
  end

  def link_nice_tariff_simple(tariff)
    if tariff.purpose == 'user'
      link_to tariff.name, :controller => "tariffs", :action => "user_rates_list", :id => tariff.id, :st => "A"
    elsif tariff.purpose == 'user_wholesale'
      link_to tariff.name, :controller => "tariffs", :action => "rates_list", :id => tariff.id, :st => "A"
    end
  end

  def link_nice_tariff_retail(tariff)
    out = "<b>#{_('Tariff')}: </b>"
    out += link_to tariff.name, :controller => "tariffs", :action => "user_rates_list", :id => tariff.id, :st => "A"
    out += "<br><br>"
  end

  def effective_from_date_formats
    formats = ['%Y-%m-%d', '%Y/%m/%d', '%Y,%m,%d', '%Y.%m.%d', '%d-%m-%Y', '%d/%m/%Y',
               '%d,%m,%Y', '%d.%m.%Y', '%m-%d-%Y', '%m/%d/%Y', '%m,%d,%Y', '%m.%d.%Y']
    formats.map{|format| [format.gsub('%', ''), format]}
  end
end
