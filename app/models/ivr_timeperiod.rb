# -*- encoding : utf-8 -*-
class IvrTimeperiod < ActiveRecord::Base
  attr_accessible :id, :name, :start_hour, :end_hour, :start_minute, :end_minute, :start_weekday,
    :end_weekday, :start_day, :end_day, :start_month, :end_month, :main_lcr_id, :lcr_id, :active


  belongs_to :user

  @@weekdays = {}
  @@weekdays["mon"] = _("Monday")
  @@weekdays["tue"] = _("Tuesday")
  @@weekdays["wed"] = _("Wednesday")
  @@weekdays["thu"] = _("Thursday")
  @@weekdays["fri"] = _("Friday")
  @@weekdays["sat"] = _("Saturday")
  @@weekdays["sun"] = _("Sunday")

  @@months = %w( January February March April May June July August September October November December)


  before_create :ivr_t_before_create

  def ivr_t_before_create
    self.user_id = User.current.id
  end

  def start_weekday_name
    if self.start_weekday == "0"
      return ""
    else
      return @@weekdays[self.start_weekday]
    end
  end

  def end_weekday_name
    if self.end_weekday == "0"
      return ""
    else
      @@weekdays[self.end_weekday]
    end
  end

  def start_month_name
    @@months[self.start_month.to_i-1]
  end

  def end_month_name
    @@months[self.end_month.to_i-1]
  end

  def start_time
    tmpH = "0"+self.start_hour.to_s
    tmpH = tmpH[tmpH.size-2, tmpH.size]
    tmpM = "0"+self.start_minute.to_s
    tmpM = tmpM[tmpM.size-2, tmpM.size]
    tmpH+":"+tmpM
  end

  def end_time
    tmpH = "0"+self.end_hour.to_s
    tmpH = tmpH[tmpH.size-2, tmpH.size]
    tmpM = "0"+self.end_minute.to_s
    tmpM = tmpM[tmpM.size-2, tmpM.size]
    tmpH+":"+tmpM
  end

  def IvrTimeperiod.ivr_timeperiods_order_by(params, options)
    case options[:order_by].to_s.strip
    when "name"
      order_by = " ivr_timeperiods.name "
      order_by << " ASC" if options[:order_desc].to_i == 0 and order_by != ""
      order_by << " DESC" if options[:order_desc].to_i == 1 and order_by != ""
    when "start"
      order_by = []
                    ["start_month", "start_day", "start_hour", "start_minute"].each { |t|
                      order = t
                      order << " ASC" if options[:order_desc].to_i == 0 and order_by != ""
                      order << " DESC" if options[:order_desc].to_i == 1 and order_by != ""
                      order_by << order
                      }
      order_by = order_by.join(",")
    when "end"
      order_by = []
                    ["end_month", "end_day", "end_hour", "end_minute"].each { |t|
                      order = t
                      order << " ASC" if options[:order_desc].to_i == 0 and order_by != ""
                      order << " DESC" if options[:order_desc].to_i == 1 and order_by != ""
                      order_by << order
                      }
      order_by = order_by.join(",")
    else
      options[:order_by] ? order_by = "ivr_timeperiods.name" : order_by = "ivr_timeperiods.name"
      options[:order_desc] = 1
    end

    return order_by
  end

  def update_by(params)
    self.name = params[:period][:name] if params[:period] and params[:period][:name]
    self.start_month = params[:period][:start_month] if params[:period] and params[:period][:start_month]
    self.start_day = params[:period][:start_day] if params[:period] and params[:period][:start_day]
    self.start_weekday = params[:period][:start_weekday] if params[:period][:start_weekday]
    self.start_hour = params[:period][:start_hour]
    self.start_minute = params[:period][:start_minute]
    self.end_month = params[:period][:end_month] if params[:period] and params[:period][:end_month]
    self.end_day = params[:period][:end_day] if params[:period] and params[:period][:end_day]
    self.end_weekday = params[:period][:end_weekday] if params[:period][:end_weekday]
    self.end_hour = params[:period][:end_hour]
    self.end_minute = params[:period][:end_minute]
  end


end
