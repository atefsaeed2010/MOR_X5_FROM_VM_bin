class Devicerule < ActiveRecord::Base
  belongs_to :device

  def change_status
    if  self.enabled == 0
      self.enabled = 1
    else
      self.enabled = 0
    end
  end

  def update_by(params)
    self.name = params[:name].to_s.strip
    self.cut = params[:cut].to_s.strip if params[:cut]
    self.add = params[:add].to_s.strip if params[:add]
    self.minlen = params[:minlen].to_s.strip if params[:minlen].length > 0
    self.maxlen = params[:maxlen].to_s.strip if params[:maxlen].length > 0
  end
end
