# -*- encoding : utf-8 -*-
class VoicemailBox < ActiveRecord::Base

  attr_protected

  #cant find why or how this relationship would be posible
  #has_one :user

  primary_key = "uniqueid"
  belongs_to :device

  validates_uniqueness_of :device_id

  class << self # Class methods
    alias :all_columns :columns

    def columns
      all_columns.reject { |c| c.name == 'delete' }
    end
  end

  def self.delete
    self[:delete]
  end

  def self.delete=(s)
    self[:delete] = s
  end
end
