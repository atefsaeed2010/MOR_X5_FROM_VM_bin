# -*- encoding : utf-8 -*-
class NumberPool < ActiveRecord::Base

  attr_protected

  has_many :numbers, :dependent => :destroy

  before_destroy :validate_delete

  def validate_delete
    device = Device.where(callerid_number_pool_id: self.id).first
    unless device.blank?
      errors.add(:device, _('number_pool_used_in_device'))
    end

    return errors.size > 0 ? false : true
  end

  def NumberPool.number_pools_order_by(options)

      case options[:order_by].to_s.strip
        when "id"
          order_by = "id"
        when "name"
          order_by = "name"
        when "numbers"
          order_by = "num"
        else
          order_by = options[:order_by]
      end

      if order_by != ""
        order_by << (options[:order_desc].to_i == 0 ? " ASC" : " DESC")
      end
      return order_by
  end
end
