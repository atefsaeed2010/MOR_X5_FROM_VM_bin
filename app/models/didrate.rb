# -*- encoding : utf-8 -*-
class Didrate < ActiveRecord::Base

  attr_protected

  belongs_to :did


  def did_rate_details
    Didrate.where(['did_id=? and rate_type=? and daytype = ?', did_id, rate_type, daytype]).order('start_time ASC').all
  end

  def did_rate_details_all
    Didrate.where(['did_id=? and rate_type=?', did_id, rate_type]).order('start_time ASC').all
  end

  def Didrate.find_hours_for_select(options = {})
    cond = []; var = []
    if options[:d_search].to_s == 'true'
      unless options[:did].blank?
        cond  << 'dids.did LIKE ?'
        var  << options[:did]
      end
    else
      cond = ['dids.did Between ? AND ?']
      var = [options[:did_from], options[:did_till]]
    end
    cond << 'daytype = ?'; var << [options[:day]]
    Didrate.includes(:did).where([cond.join(' AND ')] + var).references(:did).group('didrates.start_time, didrates.end_time').order('didrates.start_time').all
  end

  def self.create_by(did_rate, options = {})
    nrd = Didrate.new
    # if options[:key] specified nrd.key = options[:key] else nrd.key = did_rate.key
    nrd.start_time =  options[:start_time] || did_rate.start_time
    nrd.end_time = options[:end_time] || did_rate.end_time
    nrd.rate = options[:rate] || did_rate.rate
    nrd.connection_fee = options[:connection_fee] || did_rate.connection_fee
    nrd.did_id = options[:did_id] || did_rate.did_id
    nrd.increment_s = options[:increment_s] || did_rate.increment_s
    nrd.min_time = options[:main_time] || did_rate.min_time
    nrd.daytype = options[:daytype] || did_rate.daytype
    nrd.rate_type = options[:rate_type] || did_rate.rate_type
    nrd
  end

  def update_daytype(string)
    if self.daytype == string
      self.daytype = ''
      self.save
    else
      self.destroy
    end
  end

  def self.owner_rate_save(dids, params_did)
    dids.owner_tariff_id = params_did[:tariff_id].to_i
    dids.save
  end
end
