# -*- encoding : utf-8 -*-
class Location < ActiveRecord::Base
  attr_accessible :id, :name, :user_id

  has_many :locationrules, -> { order("name ASC") }
  has_many :devices

  validates_presence_of :name, :message => _('Name_cannot_be_blank')

  before_create :loc_before_create

  def loc_before_create
    current = User.current
    if current
      if current.usertype.to_s == 'admin'
        self.user_id ||= current.id
      else
        self.user_id = current.id
      end
    end
  end

  def destroy_all
    for rule in locationrules
      rule.destroy
    end
    self.destroy
  end

  def Location.nice_locilization(cut, add, dst)
    start = 0
    start = cut.length.to_i if cut
    add.to_s + dst[start, dst.length.to_i].to_s
  end

  def self.locations_for_device_update(reseller, correct_owner_id)
    collect_locations = reseller ? 'user_id = ? AND id != 1' : 'user_id = ? OR id = 1'

    locations = Location.where([collect_locations, correct_owner_id]).order(:name)
  end
end
