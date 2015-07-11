# -*- encoding : utf-8 -*-
class AlertContactGroup < ActiveRecord::Base
  attr_accessible :id, :alert_contact_id, :alert_group_id


  belongs_to :alert_group
  belongs_to :alert_contact

  validates :alert_group, presence: {message: _('alert_group_must_be_selected') }
  validates :alert_contact, presence: {message: _('alert_contact_must_be_selected') }
end
