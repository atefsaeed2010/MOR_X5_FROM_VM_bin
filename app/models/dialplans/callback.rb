class Dialplans::Callback < Dialplans::Fabricator
  def fabricate(params)
    dp_params = params[:dialplan]
    @dialplan.data1 = (Did.where(:did => dp_params[:data1].split("-")[0].to_s.strip).first.id.to_s if dp_params[:data1]) rescue nil

    if @dialplan.data1.blank?
      @dialplan.errors.add(:update, _('Could_not_assign_did'))
    else
      @dialplan.data2 = dp_params[:data2].to_s.strip
      @dialplan.data3 = dp_params[:data3].to_s.strip
      @dialplan.data4 = dp_params[:data4] ? dp_params[:data4].to_i : 0
      @dialplan.data5 = dp_params[:data5].to_s.strip
      @dialplan.data6 = dp_params[:data6].to_s.strip
    end
  end
end
