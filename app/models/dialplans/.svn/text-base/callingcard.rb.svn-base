class Dialplans::Callingcard < Dialplans::Fabricator
  def fabricate(params)
    dp_params = params[:dialplan]

    cardgroup = Cardgroup.where(:id => params[:dialplan_number_pin_length]).first

    if !cardgroup
      @dialplan.errors.add(:update, _('Cardgroup_was_not_found'))
    else
      @dialplan.data1 = cardgroup.number_length
      @dialplan.data2 = cardgroup.pin_length

      # tell time - data3
      @dialplan.data3 = @dialplan.tell_time_status(dp_params[:data3], params[:tell_hours], params[:tell_seconds])

      @dialplan.data4 = dp_params[:data4] ? 1 : 0
      @dialplan.data7 = dp_params[:data7] ? 1 : 0
      @dialplan.data8 = dp_params[:data8] ? 1 : 0

      @dialplan.data5 = dp_params[:data5].to_s.strip if dp_params[:data5].to_i > 0
      @dialplan.data6 = dp_params[:data6].to_s.strip if dp_params[:data6].to_i > 0
      @dialplan.data9 = params[:end_ivr].to_i + 1
      @dialplan.data10 = dp_params[:data10].to_i
      @dialplan.data11 = dp_params[:data11].to_d
      @dialplan.data13 = dp_params[:data13] ? 1 : 0
      if @dialplan.data11.to_i == 0
        @dialplan.data12 = ''
      else
        @dialplan.data12 = dp_params[:data12].to_i
      end
    end
  end
end
