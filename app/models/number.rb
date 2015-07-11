# -*- encoding : utf-8 -*-
class Number < ActiveRecord::Base
  belongs_to :number_pool
  validates_numericality_of :number, :message => _("number_must_be_number")


  def Number.numbers_order_by(options)
    case options[:order_by].to_s.strip
      when "id"
        order_by = "id"
      when "number"
        order_by = "number"
      else
        order_by = options[:order_by]
    end

    if order_by != ""
      order_by << (options[:order_desc].to_i == 0 ? " ASC" : " DESC")
    end
    return order_by
  end
end
