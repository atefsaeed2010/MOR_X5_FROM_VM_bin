# -*- encoding : utf-8 -*-
class DpeerTpoint < ActiveRecord::Base
  attr_accessible :id, :dial_peer_id, :device_id, :tp_percent, :tp_weight

  belongs_to :dial_peer
  belongs_to :device
  before_validation :set_defaults

  validates_numericality_of :tp_percent,  :greater_than_or_equal_to => 0, :less_than_or_equal_to => 100, :message => _('weight_must_be_number_between_0_100'), :allow_nil => true
  validates_numericality_of :tp_weight,  :greater_than_or_equal_to => 0, :less_than_or_equal_to => 100, :message => _('percent_must_be_number_between_0_100'), :allow_nil => true

  def set_defaults
  	self.tp_percent = 100 unless self.tp_percent
    self.tp_weight = 1 unless self.tp_weight
  end
end
