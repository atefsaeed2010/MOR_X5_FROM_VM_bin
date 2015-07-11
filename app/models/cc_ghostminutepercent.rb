# -*- encoding : utf-8 -*-
class CcGhostminutepercent < ActiveRecord::Base
  attr_protected

  self.table_name = 'cc_gmps'

  belongs_to :cardgroup
end
