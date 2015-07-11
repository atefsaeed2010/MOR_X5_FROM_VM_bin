# -*- encoding : utf-8 -*-
class Quickforwarddid < ActiveRecord::Base
  attr_accessible :id, :did_id, :user_id, :number, :description

  belongs_to :did
  belongs_to :user
  validates :number, numericality: {message: _('quickforward_number_must_be_numerical')}

  def self.quickforwarddid_update(qfdid, params, current_user)
    qfdid.did_id = params[:did_id]
    qfdid.user = current_user
    qfdid.number = params[:number]
    qfdid.description = params[:description]
    qfdid.save
  end
end
