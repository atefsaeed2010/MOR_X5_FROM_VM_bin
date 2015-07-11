# -*- encoding : utf-8 -*-
class QueueAgent < ActiveRecord::Base

  attr_protected


  def move_queue_agent(direction)
    if direction == "down"
      following_queue_agent = QueueAgent.where("queue_id = #{self.queue_id} AND priority > #{self.priority}").order("priority").first
      old_priority = self.priority
      self.update_attribute(:priority, following_queue_agent.priority) if following_queue_agent
      following_queue_agent.update_attribute(:priority, old_priority) if following_queue_agent
    else
      previous_queue_agent = QueueAgent.where("queue_id = #{self.queue_id} AND priority < #{self.priority}").order("priority DESC").first
      old_priority = self.priority
      self.update_attribute(:priority, previous_queue_agent.priority) if previous_queue_agent
      previous_queue_agent.update_attribute(:priority, old_priority) if previous_queue_agent
    end
  end

end
