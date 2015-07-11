# -*- encoding : utf-8 -*-
class Customrate < ActiveRecord::Base
  attr_accessible :id, :user_id, :destinationgroup_id

  belongs_to :user
  has_many :acustratedetails
  belongs_to :destinationgroup

  def manage_details(rate_details_action)
    status = []
    rdetails = acustratedetails

    if rate_details_action.to_s == 'COMB_WD'
      rdetails.each do |ratedetail|
        if ratedetail.daytype == 'WD'
          ratedetail.daytype = ''
          ratedetail.save
        else
          ratedetail.destroy
        end
      end
      status << _('Rate_details_combined')
    end

    if rate_details_action.to_s == 'COMB_FD'
      rdetails.each do |rd|
        if rd.daytype == 'FD'
          rd.daytype = ''
          rd.save
        else
          rd.destroy
        end
      end
      status << _('Rate_details_combined')
    end

    if rate_details_action == 'SPLIT'
      rdetails.each do |rd|
        nrd = Acustratedetail.new(start_time: rd.start_time,
                                 end_time: rd.end_time,
                                 from: rd.from,
                                 duration: rd.duration,
                                 customrate: rd.customrate,
                                 artype: rd.artype,
                                 round: rd.round,
                                 price: rd.price,
                                 daytype: 'FD')
        nrd.save

        rd.daytype = 'WD'
        rd.save
      end
      status << _('Rate_details_split')
    end
    status
  end

  def acustratedetails_by_daytype(daytype)
    Acustratedetail.where("customrate_id = #{self.id} AND daytype = '#{daytype}'").order("daytype DESC, start_time ASC").all
  end

  def destroy_all
    for acr in self.acustratedetails
      acr.destroy
    end
    self.destroy
  end

  def manage_details_times
    if acustratedetails.first.daytype == ''
      wdfd = true
      start_time_array, end_time_array = details_times
    else
      wdfd = false
      wstart_time_array, wend_time_array = details_times('WD')
      fstart_time_array, fend_time_array = details_times('FD')
    end
    [wdfd, start_time_array, end_time_array, wstart_time_array, wend_time_array, fstart_time_array, fend_time_array]
  end

  private

  def details_times(day_type = '')
    results = Acustratedetail.select('start_time, end_time').where(daytype: day_type, customrate_id: id).group(:start_time).order(:start_time)

    start_time_array = []
    end_time_array = []

    results.each do |result|
      start_time_array << (result['start_time'] ? result['start_time'].strftime('%H:%M:%S') : Time.parse('00:00:00').strftime('%H:%M:%S'))
      end_time_array << (result['end_time'] ? result['end_time'].strftime('%H:%M:%S') : Time.parse('23:59:59').strftime('%H:%M:%S'))
    end
    [start_time_array, end_time_array]
  end
end
