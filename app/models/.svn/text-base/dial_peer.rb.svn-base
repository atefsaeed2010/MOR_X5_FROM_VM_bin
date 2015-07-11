# -*- encoding : utf-8 -*-
class DialPeer < ActiveRecord::Base
  attr_accessible :id, :active, :name, :comment, :dst_regexp, :dst_deny_regexp, :src_regexp
  attr_accessible :src_deny_regexp, :weight, :stop_hunting, :delta_price, :tp_priority

  belongs_to :rgroup_dpeers
  has_many :dpeer_tpoints, :dependent => :destroy

  before_validation :set_defaults
  before_destroy :validate_delete

  validates_presence_of :name, :message => _('dial_peer_must_have_name')
  validates_length_of :name, :maximum => 100, :message => _('dial_peer_name_is_to_long')
  validates_numericality_of :weight,  :greater_than_or_equal_to => 0,
                            :message => _('weight_must_be_positive_number'), :allow_nil => true
  validates_numericality_of :delta_price, :message => _('delta_price_must_be_decimal_number'), :allow_nil => true

  def set_defaults
    self.weight = 0 unless self.weight
    self.delta_price = 0 unless self.delta_price
  end

  def validate_delete
    if RgroupDpeer.exists?(dial_peer_id: self.id)
      errors.add(:rgroup, _('dial_peer_is_used_in_routong_group'))
      return false
    end
  end
end
