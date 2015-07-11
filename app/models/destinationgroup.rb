# -*- encoding : utf-8 -*-
class Destinationgroup < ActiveRecord::Base

  attr_protected

  has_many :destinations, -> { order(:prefix) } #, :foreign_key => "prefix", :order => "prefix ASC"
  has_many :rates
  has_many :customrates

  validates_presence_of :name

  before_destroy :check_for_rates, :check_for_alerts
  after_destroy :fix_destinations

  # destinations which haven't assigned to destination group by first letter
  def free_destinations_by_st(st)
    adests = Destination.find_by_sql ["SELECT destinations.* FROM destinations, directions WHERE destinations.destinationgroup_id = 0 AND directions.code = destinations.direction_code AND directions.name like ? ORDER BY directions.name ASC, destinations.prefix ASC", st.to_s+'%']
    dests = self.destinations
    fdests = []
    fdests = adests - dests
  end

  def rate(tariff_id)
    Rate.where("tariff_id = #{tariff_id} AND destinationgroup_id = #{self.id}").first
  end

  def custom_rate(user_id)
    Customrate.where("user_id = #{user_id} AND destinationgroup_id = #{self.id}").first
  end

  def Destinationgroup.destinationgroups_order_by(params, options)
    case options[:order_by].to_s.strip
      when "country"
        order_by = "dgn"
      when "prefix"
        order_by = "prefix"
      when "destination"
        order_by = "name"
      else
        order_by = options[:order_by]
    end
    if order_by != ""
      order_by += (options[:order_desc].to_i == 0 ? " ASC" : " DESC")
    end
    return order_by
  end

  def rates_size(user_id, tariff_id)
    rates_size = Aratedetail.count(:joins => "LEFT JOIN (rates) ON rates.id = aratedetails.rate_id", :conditions => ["rates.tariff_id = ? AND rates.destinationgroup_id = ?", tariff_id, self.id])
    if rates_size == 0
      rates_size = Acustratedetail.count(:joins => "LEFT JOIN customrates ON (customrates.id = acustratedetails.customrate_id) ", :conditions => ["customrates.user_id = ? AND customrates.destinationgroup_id = ?", user_id, self.id])
    end

    rates_size
  end

  def rates_price(user_id, tariff_id)
    rates = Aratedetail.where("rates.tariff_id = ? AND rates.destinationgroup_id = ?", tariff_id, self.id).
                              joins("LEFT JOIN (rates) ON rates.id = aratedetails.rate_id")
    if rates.blank?
      rates = Acustratedetail.where("customrates.user_id = ? AND rates.destinationgroup_id = ?", user_id, self.id).
                              joins("LEFT JOIN (customrates) ON customrates.id = acustratedetails.customrate_id")
    end

    rates.sum(:price)
  end

  def message
    ": #{name} #{desttype}"
  end

  private

  def check_for_rates
    if rates.size > 0 || customrates.size > 0
      errors.add(:base, _('Cant_delete_destination_group_rates_exist') + message)
      false
    end
  end

  def check_for_alerts
    if Alert.where(check_type: 'destination_group', check_data: id).first
      errors.add(:base, _('Cant_delete_destination_group_alerts_exist'))
      false
    end
  end

  def fix_destinations
    sql = "UPDATE destinations SET destinationgroup_id = 0 WHERE destinationgroup_id = '#{id}'"
    res = ActiveRecord::Base.connection.update(sql)
  end
end

