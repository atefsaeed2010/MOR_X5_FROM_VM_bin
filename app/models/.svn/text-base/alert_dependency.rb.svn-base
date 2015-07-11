# -*- encoding : utf-8 -*-
class AlertDependency < ActiveRecord::Base
  attr_protected

  belongs_to :alert, foreign_key: :owner_alert_id, primary_key: :owner_alert_id

  def self.cycle_exists?(depencency, depencency_owner = nil)
    if  (depencency.alert_id == depencency.owner_alert_id) ||
        (depencency_owner.present? && depencency.alert_id == depencency_owner.owner_alert_id)
      return true
    else
      owner_id = depencency_owner.nil? ? depencency.owner_alert_id : depencency_owner.owner_alert_id
      owners = AlertDependency.where(alert_id: owner_id)
      owners.each do |owner|
        return cycle_exists?(depencency, owner) if owner
      end
    end
    return false
  end
end
