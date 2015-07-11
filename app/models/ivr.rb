# -*- encoding : utf-8 -*-
class Ivr < ActiveRecord::Base
  attr_protected

  has_many :ivr_extensions
  has_many :ivr_blocks, :dependent => :destroy
  belongs_to :start_block, class_name: 'IvrBlock'
  belongs_to :user

  before_create :ivr_before_create

  def ivr_before_create
    self.user_id = User.current.id
  end

  def self.create_by(block, params)
    ivr = self.new()
    ivr.name = "New_Ivr"
    ivr.start_block_id = block.id
    ivr.name = params[:ivr_name].to_s if params[:ivr_name].to_s != ""
    return ivr
  end

  def start_block
    IvrBlock.includes([:ivr_extensions, :ivr_actions]).where(["ivr_blocks.id = ?", self.start_block_id]).first
  end

  def used_by_queues
    AstQueue.where(:context => self.id).first
  end

  def validate_before_destroy
    notice = ''

    if self.used_by_queues and notice.blank?
      notice = _('IVR_assigned_to_queues')
    end

    is_ivr_in_use_callback = (Confline.get_value('Busy_IVR').to_i == self.id) || (Confline.get_value('Failed_IVR').to_i == self.id)
    self.errors.add(:assigned_to_callback, _('assigned_to_callback')) if is_ivr_in_use_callback

    notice
  end

  def self.extension_block(params)
    critical_update = 0
    data = params[:data].to_i
    if params[:id] != '0' and data != 0 # Hack for IE... it sometimes sends zeros instead ob block numbers.
      ext = IvrExtension.includes(:ivr_block).where(["ivr_block_id = ? AND exten = ?", params[:id], params[:ext]]).first
      if data == -1
        if ext
          ext.destroy
          critical_update = 1
        end
      else
        if ext
          ext.goto_ivr_block_id = data
        else
          ext = IvrExtension.new(:exten => params[:ext], :goto_ivr_block_id => data, :ivr_block_id => params[:id])
        end
        ext.save
        critical_update = 1
      end
    end

    return data, ext, critical_update
  end
end
