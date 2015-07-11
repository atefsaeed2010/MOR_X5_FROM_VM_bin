# -*- encoding : utf-8 -*-
class AccGroupRight < ActiveRecord::Base
#  set_table_name "acc_group_rights"
  attr_protected

  belongs_to :acc_group
  belongs_to :acc_right
end
