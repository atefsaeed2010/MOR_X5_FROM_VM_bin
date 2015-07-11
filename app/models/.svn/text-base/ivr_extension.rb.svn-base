# -*- encoding : utf-8 -*-
class IvrExtension < ActiveRecord::Base
  attr_accessible :id, :exten, :goto_ivr_block_id, :ivr_block_id

  belongs_to :ivr
  belongs_to :ivr_block

  def goto_ivr_block
    IvrBlock.where("id = #{self.goto_ivr_block_id}").first
  end

end
