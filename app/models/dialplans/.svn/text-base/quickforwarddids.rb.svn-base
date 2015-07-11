class Dialplans::Quickforwarddids < Dialplans::Fabricator
  def fabricate(params)
    dp_params = params[:dialplan]

    @dialplan.data10 = (dp_params[:data10].to_i == 1 ? 1 : 0)
    if params[:users_device].to_i != 0 and not User.joins("JOIN devices ON devices.user_id = users.id").where(["devices.id = ? AND users.owner_id = ?", params[:users_device].to_i, User.current.get_corrected_owner_id]).first
      @dialplan.errors.add(:update, _('Device_was_not_found'))
    else
      @dialplan.data3 = params[:users_device].to_i
    end
  end
end
