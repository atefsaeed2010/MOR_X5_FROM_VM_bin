# -*- encoding : utf-8 -*-
class Usergroup < ActiveRecord::Base
  attr_protected

  attr_accessible :id, :user_id, :group_id, :gusertype, :position

  belongs_to :group
  belongs_to :user

  before_create :check_menager_size_in_group

  def check_menager_size_in_group
    if Usergroup.where(['group_id=? AND gusertype = "manager"', self.group_id]).count.to_i > 0 and self.gusertype == 'manager'
      errors.add(:gusertype, _("Call_Shop_can_have_only_one_manager"))
      return false
    end
  end

end
