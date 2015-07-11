# -*- encoding : utf-8 -*-
class Providertype < ActiveRecord::Base
  attr_protected
  attr_accessible :id, :name, :ast_name
end
