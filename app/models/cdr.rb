# -*- encoding : utf-8 -*-
class Cdr < ActiveRecord::Base

  def self.table_name()
    "cdr"
  end

  attr_protected
end
