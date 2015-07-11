# -*- encoding : utf-8 -*-
class AccGroup < ActiveRecord::Base
  attr_protected :group_type
  has_many :users
  has_many :acc_group_rights, :dependent => :destroy
  has_many :acc_permissions, :dependent => :destroy
  validates_presence_of :name, :message => _("Group_Name_Must_Be_Set")
  validates_uniqueness_of :name, :case_sensitive => false, :message => _("Group_Name_Must_Be_Unique")

  before_destroy :acc_group_before_destroy
=begin rdoc
 Performs validation before destroy
=end

  def acc_group_before_destroy
    if User.where(acc_group_id: self.id).first
      errors.add(:users, _("Group_has_assigned_users"))
      return false
    end
    return true
  end

  def self.create_by(params)
    group = AccGroup.new(:name => params[:name].to_s)
    group.group_type = params[:group_type]
    group.description = params[:description].to_s
    return group
  end

  def self.accountants
    self.where(group_type: :accountant).all
  end

  def self.resellers
    self.where(group_type: :reseller).all
  end

  def create_empty_permissions
    AccRight.where(right_type: self.group_type).all.each do |acc_right|
    AccGroupRight.create(:acc_group_id => self.id, :acc_right_id => acc_right.id, :value => 0)
    end
  end

  def rights_by_condition(payment_gateway_active = false, sms_active = false, pbx_active = false, calling_cards_active  = false )
    cond = ["right_type = ?"]
    var = [group_type]
    permis = []
    if group_type == 'reseller'
      permis << "'Call_Shop'"
      permis << "'Payment_Gateways'" if payment_gateway_active
      permis << "'Calling_Cards'"
      permis << "'SMS'" if sms_active
      permis << "'Autodialer'"
      permis << "'Pbx_functions'" if pbx_active

      cond << " nice_name IN (#{permis.join(' , ')})" if permis.size.to_i > 0
    elsif group_type != 'reseller'
      permis << "'Callingcard'" unless calling_cards_active

      cond << "permission_group NOT IN (#{permis.join(' , ')})" if permis.size.to_i > 0
    end

    if (permis.try(:size).to_i > 0) || group_type != 'reseller'
      rights = AccRight.where([cond.join(' AND ')].concat(var)).order('permission_group, id DESC')
    else
      rights = []
    end
  end

  def update_rights(params)
    rights = AccRight.where(['right_type = ?', group_type])
    rights.each do |right|
      right_id = right.id
      gr = self.acc_group_rights.select { |r| r.acc_right_id == right_id }[0]
      gr = AccGroupRight.new(:acc_group => self, :acc_right => right) if gr.nil?

      if (params["right_#{right_id}".to_sym] && params["right_#{right_id}".to_sym].to_i != gr.value) || gr.new_record? || only_view == true
        gr.value = (params["right_#{right_id}".to_sym]) ? params["right_#{right_id}".to_sym].to_i : 0
        gr.value = 1 if gr.value > 1 && only_view
        gr.save
      end
    end
  end

end
