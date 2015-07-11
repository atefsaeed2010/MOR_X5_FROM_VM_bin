# -*- encoding : utf-8 -*-
class Devicetype < ActiveRecord::Base
  attr_accessible :id, :name, :ast_name

  def self.load_types(options = {})
    Devicetype.all.map { |type|
      (options.has_key?(type.name) and options[type.name] == false) ? nil : type
    }.compact
  end
end
