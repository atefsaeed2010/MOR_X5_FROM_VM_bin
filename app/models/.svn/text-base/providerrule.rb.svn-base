# -*- encoding : utf-8 -*-
class Providerrule < ActiveRecord::Base
  attr_accessible :id, :name, :user_id, :rule_regexp, :created_at, :updated_at, :provider_id,
    :enabled, :pr_type

  belongs_to :provider

  def before_transformation
    bt = "_" + self.start.to_s
    if self.length == 0
      bt += "X."
    else
      (self.length - self.start.to_s.length).times do
        bt += "X"
      end
    end
    bt
  end

  def update_by(params)
    self.name = params[:name].to_s.strip
    self.cut = params[:cut].to_s.strip if params[:cut]
    self.add = params[:add].to_s.strip if params[:add]
    self.minlen = params[:minlen].to_s.strip if params[:minlen].to_s.length > 0
    self.maxlen = params[:maxlen].to_s.strip if params[:maxlen].to_s.length > 0
  end

  def self.create_by(params, provider)
    rule = self.new({
                                :provider_id => provider.id,
                                :name => params[:name].to_s.strip,
                                :enabled => 1,
                                :pr_type => params[:pr_type].to_s.strip
                            })
    rule.cut = params[:cut].to_s.strip if params[:cut]
    rule.add = params[:add].to_s.strip if params[:add]
    rule.minlen = params[:minlen].to_s.strip if params[:minlen].to_s.length > 0
    rule.maxlen = params[:maxlen].to_s.strip if params[:maxlen].to_s.length > 0
    return rule
  end
end
