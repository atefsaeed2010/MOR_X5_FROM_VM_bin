class Ip_new_score < ActiveRecord::Base

  validates_numericality_of :score, :only_integer => true

  def self.table_name()
    "bl_ip_new_score"
  end

  attr_protected
end
