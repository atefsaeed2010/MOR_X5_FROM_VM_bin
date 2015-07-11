# -*- encoding : utf-8 -*-
class Translation < ActiveRecord::Base
  has_many :user_translations, :dependent => :destroy

  attr_protected

  def self.default
    t = order("position ASC").first
    return t ? t.name : "English"
  end
end
