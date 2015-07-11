# -*- encoding : utf-8 -*-
class PbxPool < ActiveRecord::Base

  attr_protected

  has_many :users
  before_destroy :validate_delete

  validates :name, presence: {
                       message: _('Name_cannot_be_blank')
                   },
                   uniqueness: {
                       case_sensitive: false,
                       message: _('Name_must_be_unique')
                   }

  def validate_delete
    pbx_pool_user = User.where(pbx_pool_id: self.id).first
    unless pbx_pool_user.blank?
      errors.add(:pbx_pool_user, _('pbx_pool_is_in_use'))
    end

    return errors.size > 0 ? false : true
  end

  def PbxPool.pbx_pools_order_by(params, options)
    case options[:order_by].to_s.strip
    when "id"
      order_by = " pbx_pools.id "
    when "name"
      order_by = " pbx_pools.name "
    # atkomentuoti, kai bus sukurtas numbers pridėjimas
    #when "numbers"
    #  order_by = " num "
    when "comment"
      order_by = " pbx_pools.comment "
    else
      options[:order_by] ? order_by = "pbx_pools.id" : order_by = "pbx_pools.id"
      options[:order_desc] = 1
    end
    order_by << " ASC" if options[:order_desc].to_i == 0 and order_by != ""
    order_by << " DESC" if options[:order_desc].to_i == 1 and order_by != ""

    return order_by
  end

end
