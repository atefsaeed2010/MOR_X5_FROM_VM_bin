# -*- encoding : utf-8 -*-
class QueuePeriodicAnnouncement < ActiveRecord::Base

  belongs_to :queue

  def self.table_name()
    "queue_periodic_announcements"
  end

  attr_accessible :id, :queue_id, :ivr_sound_files_id, :priority

  attr_protected

  def move_announcement(direction)
    if direction == "down"
      following_queue_announcement = QueuePeriodicAnnouncement.where("queue_id = #{self.queue_id} AND priority > #{self.priority}").order("priority").first
      old_priority = self.priority
      self.update_attribute(:priority, following_queue_announcement.priority)
      following_queue_announcement.update_attribute(:priority, old_priority)
    else
      previous_queue_announcement = QueuePeriodicAnnouncement.where("queue_id = #{self.queue_id} AND priority < #{self.priority}").order("priority DESC").first
      old_priority = self.priority
      self.update_attribute(:priority, previous_queue_announcement.priority)
      previous_queue_announcement.update_attribute(:priority, old_priority) if previous_queue_announcement
    end
  end

end

