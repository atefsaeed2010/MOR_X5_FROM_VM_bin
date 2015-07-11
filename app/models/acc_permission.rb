# -*- encoding : utf-8 -*-
class AccPermission < ActiveRecord::Base

  attr_protected

  has_many :users
  belongs_to :acc_group
end
