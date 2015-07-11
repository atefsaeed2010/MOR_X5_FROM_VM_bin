# -*- encoding : utf-8 -*-
class Devicecodec < ActiveRecord::Base
  attr_protected
  attr_accessible :id, :device_id, :codec_id, :priority
end
