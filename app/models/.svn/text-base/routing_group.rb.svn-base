# -*- encoding : utf-8 -*-
class RoutingGroup < ActiveRecord::Base
  has_many :rgroup_dpeers, :dependent => :destroy
  validates_presence_of :name, :message => _("routing_group_must_have_name")


  attr_protected

  before_destroy :validate_delete

  def validate_delete
    op = Device.where(:op_routing_group_id => self.id).first
    errors.add(:device, _('routing_group_is_used_in_device')) if op
    return errors.size > 0 ? false : true
  end
end
