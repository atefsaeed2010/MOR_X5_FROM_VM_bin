# -*- encoding : utf-8 -*-
class  TimePeriod < ActiveRecord::Base
  attr_protected
  has_many :aggregates
end