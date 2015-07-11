# -*- encoding : utf-8 -*-
class Blank < ActiveRecord::Base

  attr_accessible :id, :name, :date, :description, :value1, :value2, :value3, :balance

  validates_presence_of :name, :message => _('Blank_must_have_name')
  validates_numericality_of :value1, :only_integer => true, :allow_nil => true, :greater_than_or_equal_to => 0, :message => _('value1_must_be_integer')
  validates_numericality_of :value2, :allow_nil => true, :message => _('value2_must_be_number')
  validates_numericality_of :balance, :allow_nil => true, :message => _('balance_must_be_number')

  def self.csv_string(csv_string, sep)

    self.all.each do |blank|
      csv_string += "\"#{self.id.to_i}\"#{sep}\"#{self.name.to_s}\"#{sep}\"#{self.date}\"#{sep}\"#{self.description}\"#{sep}\"#{self.value1.to_i}\"#{sep}\"#{nice_number(self.value2.to_d)}\"#{sep}\"#{self.value3.to_s}\"\n"
    end
    return csv_string
  end

  def self.order_by(options, fpage, items_per_page)
    order_by, order_desc = [options[:order_by], options[:order_desc]]
    order_string = ''
    if not order_by.blank? and not order_desc.blank?
      order_string << "#{order_by} #{order_desc.to_i.zero? ? 'ASC' : 'DESC'}" if Blank.accessible_attributes.member?(order_by)
    end
    selection = Blank.order(order_string)
    selection = options[:csv].to_i.zero? ? selection.limit("#{fpage}, #{items_per_page}").all : selection.all
  end

  def self.filter(options, session_from, session_till)
    max_value, min_value, name = options[:s_max_value2], options[:s_min_value2], options[:s_name]

    where = []
    where << "name LIKE '#{name}'" if name.present?
    where << "value2 >= #{min_value}" if min_value.present?
    where << "value2 <= #{max_value}" if max_value.present?
    where << "date >= '#{session_from}'"
    where << "date <= '#{session_till}'"

    if [min_value, max_value].any? {|var| (/^(?!0\d)\d*(\.\d+)?$/ !~ var and var.present?)}
      return Blank.none
    end

    Blank.where(where.join(' AND '))
  end
end

