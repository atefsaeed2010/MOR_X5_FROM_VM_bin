# -*- encoding : utf-8 -*-
class UserTranslation < ActiveRecord::Base
  belongs_to :user
  belongs_to :translation

  attr_protected

  def UserTranslation.get_active
    UserTranslation.where("active=1 and user_id = #{User.current.id}").all
  end

  def self.translations_change_status(id)
    tr = UserTranslation.find(id)
    active = UserTranslation.get_active.size
    tr.active = (tr.active == 1 ? 0 : 1)
    if (tr.active == 0 and active != 1) or tr.active == 1
      tr.save
    end
  end
end
