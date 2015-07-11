class Ip_scoring < ActiveRecord::Base

  validates_numericality_of :score, :only_integer => true

  def self.table_name()
    "bl_ip_scoring"
  end

  attr_protected
end
