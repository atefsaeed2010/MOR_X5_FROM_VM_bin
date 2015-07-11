class Dialplans::Authbypin < Dialplans::Fabricator
  def fabricate(params)
    dp_params = params[:dialplan]

    if dp_params[:data1].to_i > 0 or (dp_params[:data3].to_i == 1 and dp_params[:data1].to_i >= 0)
      @dialplan.data1 = dp_params[:data1].to_s.strip
    elsif dp_params[:data3].to_i == 0 and dp_params[:data1].to_i == 0
      @dialplan.data1 = 1
    end
    @dialplan.data2 = dp_params[:data2].to_s.strip if !dp_params[:data2].blank?

    @dialplan.data3 = dp_params[:data3] ? 1 : 0
    @dialplan.data4 = dp_params[:data4] ? 1 : 0
    @dialplan.data6 = dp_params[:data6].to_i == 1 ? "1" : "0"
    @dialplan.data5 = params[:users_device]
    if Dialplan.where(:id => dp_params[:data7].to_i, :user_id => User.current.get_corrected_owner_id).first
      @dialplan.data7 = dp_params[:data7].to_i
    else
      @dialplan.data7 = 0
    end
    @dialplan.data8 = dp_params[:data8].to_i + 1
  end
end