# -*- encoding : utf-8 -*-
class Locationrule < ActiveRecord::Base

  attr_accessible :id, :location_id, :name, :enabled, :cut, :add, :minlen, :maxlen
  attr_accessible :lr_type, :lcr_id, :tariff_id, :did_id, :device_id

  attr_protected

  belongs_to :location
  belongs_to :tariff
  belongs_to :lcr
  belongs_to :did
  belongs_to :device

  before_save :loca_before_save
  before_save :trim_attributes

  def loca_before_save
    current = User.current
    if current
      usertype = current.usertype
      if ['admin', 'accountant'].include?(usertype)
        uid = 0
      else
        uid = User.current.id
      end
      if !['admin', 'accountant'].include?(usertype)
        unless location.user_id == uid
          errors.add(:location, _("Location_error"))
          return false
        end
      end
    end
    if cut.blank? and add.blank?
      errors.add(:cut_add, _("Cut_and_Add_cannot_be_empty"))
      return false
    end
    if device and device.belongs_to_provider?
      errors.add(:device, _("Cannot_assign_device"))
      return false
    end
  end

  def self.create_by(params, did)
    rule = self.new()
    rule.name = params[:name]
    rule.enabled = 1
    rule.lr_type = params[:lr_type]
    rule.location_id = params[:location_id]
    rule.cut = params[:cut] if params[:cut]
    rule.add = params[:add] if params[:add]
    rule.minlen = params[:minlen] if !params[:minlen].blank?
    rule.maxlen = params[:maxlen] if !params[:maxlen].blank?
    rule.tariff_id = params[:tariff] if params[:tariff]
    rule.lcr_id = params[:lcr] if params[:lcr]

    rule.did_id = did.id if did
    rule.device_id = params[:device_id_from_js] if params[:device_id_from_js] and params[:device_id_from_js].to_i > 0
    return rule
  end

  def self.create_by_rule(rules, loc)
    rule = self.new({:name => rules.name, :enabled => 1, :lr_type => rules.lr_type})
    rule.location_id = loc.id
    rule.cut = rules.cut if rules.cut
    rule.add = rules.add if rules.add
    rule.minlen = rules.minlen if !rules.minlen.blank?
    rule.maxlen = rules.maxlen if !rules.maxlen.blank?
    return rule
  end

  def update_by(params, did)
    self.name = params[:name]
    self.cut = params[:cut] if params[:cut]
    self.add = params[:add] if params[:add]
    self.minlen = params[:minlen] if !params[:minlen].blank?
    self.maxlen = params[:maxlen] if !params[:maxlen].blank?
    self.tariff_id = params[:tariff] if params[:tariff]
    self.lcr_id = params[:lcr] if params[:lcr]

    self.did_id = did ? did.id : ""
    if params[:user].to_i == -1
      self.device_id = ""
    else
      self.device_id = params[:s_device] ? params[:s_device] : (params[:device_id_from_js] if params[:device_id_from_js])
    end
  end

  def change_status
    st = ' '
    if self.enabled == 0
      self.enabled = 1; st =_('Rule_enabled')
    else
      self.enabled = 0; st = _('Rule_disabled')
    end
    return st
  end

  def trim_attributes
    attrs = [self.cut, self.add]
    attrs.each {|attribute| attribute.try(:gsub!, /\s/, '')}
  end

  validates_uniqueness_of :cut, :scope => [:add, :location_id], :message => _('Rule_Must_Be_Unique'), :if => :check_min_and_max
  validates_presence_of :name, :message => _('Rule_must_have_name')

  def check_min_and_max
    Locationrule.count(:all, :conditions => ["NOT ((? < minlen AND ? < minlen) OR (? > maxlen and ? > maxlen ) ) AND location_id = ? AND locationrules.add = ? and cut = ? AND id != ? AND lr_type = ?", minlen, maxlen, minlen, maxlen, location_id, add, cut, id.to_i, lr_type]).to_i > 0
  end
end
