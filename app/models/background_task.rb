# -*- encoding : utf-8 -*-
class BackgroundTask < ActiveRecord::Base
  attr_accessible :id, :owner_id, :user_id, :task_id, :status, :percent_completed, :created_at
  attr_accessible :started_at, :updated_at, :expected_to_finish_at, :finished_at, :failed_at
  attr_accessible :last_error, :to_do_times, :attempts, :data1, :data2, :data3, :data4, :data5, :data6

  belongs_to	:user
  belongs_to	:owner, class_name: 'User', foreign_key: 'owner_id'
end
