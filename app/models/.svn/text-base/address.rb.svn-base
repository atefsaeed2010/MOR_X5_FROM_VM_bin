# -*- encoding : utf-8 -*-
class Address < ActiveRecord::Base
  belongs_to :direction
  has_one :user
  has_one :cc_client

  attr_protected

  validates :email, :uniqueness => {message: _('Email_Must_Be_Unique'), case_sensitive: false}, :allow_nil => true

  before_save :address_before_save

  def address_before_save
    email = self.email.to_s

    if email.length > 0 and !Email.address_validation(email)
      errors.add(:email, _("Please_enter_correct_email"))
      return false
    end
  end
end
