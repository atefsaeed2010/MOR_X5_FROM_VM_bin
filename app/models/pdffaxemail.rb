# -*- encoding : utf-8 -*-
class Pdffaxemail < ActiveRecord::Base
  attr_protected

  belongs_to :device

end
