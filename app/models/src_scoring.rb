class Src_scoring < ActiveRecord::Base

  validates_numericality_of :score, :only_integer => true

  def self.table_name()
    "bl_src_scoring"
  end

  attr_protected
end
