# -*- encoding : utf-8 -*-
class FlatrateDestination < ActiveRecord::Base
  attr_protected

  belongs_to :service
  belongs_to :destination

  def self.get_by_service_id(service_id)
  	flatrate_destinations = FlatrateDestination.includes(:service, :destination).where(["flatrate_destinations.service_id = ?", service_id]).all
    flatrate_destinations.each_with_index { |fd, i| fd.destroy and flatrate_destinations[i] = nil if fd.destination == nil }
    flatrate_destinations = flatrate_destinations.compact
  end
end

