# -*- encoding : utf-8 -*-
class AstQueue < ActiveRecord::Base
  has_many :dids

  validates_presence_of :extension, :message => _('Please_enter_extension')
  validates_presence_of :name, :message => _('Name_cannot_be_blank')

  after_create :after_create_queue

  def self.table_name()
    "queues"
  end

  def after_create_queue
    extension, ast_queue_id = [self.extension, self.id]
    dialplan = Dialplan.new({:name => self.name, :dptype => 'queue', :data1 => ast_queue_id, :data2 => extension})

    if dialplan.save
      context = "mor_local"
      exten = extension
      app = "Set"
      appdata = "MOR_DP_ID=#{dialplan.id}"
      Extline.mcreate(context, "1", app, appdata, exten, "0")

      app = "Goto"
      appdata = "mor_queues,queue#{ast_queue_id}, 1"
      Extline.mcreate(context, "2", app, appdata, exten, "0")
    end
  end

  def destroy_all
    ast_queue_id = self.id
    dialplan = Dialplan.where(:name => self.name, :dptype => 'queue', :data1 => ast_queue_id, :data2 => extension).first

    Extline.delete_all(:exten => extension, :appdata => "MOR_DP_ID=#{dialplan.id}")
    Extline.delete_all(:exten => extension, :appdata => "mor_queues,queue#{ast_queue_id}, 1")

    dialplan.destroy
    self.destroy
  end
end
