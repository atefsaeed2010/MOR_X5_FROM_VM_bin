# -*- encoding : utf-8 -*-
class FlatrateData < ActiveRecord::Base
  belongs_to :subscription

  def self.table_name()
    "flatrate_data"
  end

  attr_protected
end
