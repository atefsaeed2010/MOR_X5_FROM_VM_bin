# -*- encoding : utf-8 -*-
class Server < ActiveRecord::Base
  attr_accessible :id, :server_ip, :stats_url, :server_type, :active, :comment, :hostname
  attr_accessible :maxcalllimit, :ami_port, :ami_secret, :ami_username, :port
  attr_accessible :ssh_username, :ssh_secret, :ssh_port, :gateway_active, :version, :uptime
  attr_accessible :gui, :db, :core, :load_ok


  has_many :serverproviders
  has_many :providers
  has_one :gateway
  has_many :activecalls
  has_many :server_devices
  has_many :devices, :through => :server_devices
  has_many :server_loadstats

  require 'rami'

  before_destroy :check_if_no_providers_own_server, :check_if_no_devices_own_server, :gui_db_core?
  before_destroy :check_if_server_is_resellers_server
  before_destroy :check_if_no_queue_own_server
  after_save :check_server_device
  before_update :check_role

  validates_presence_of :server_ip, :message => _('Server_IP_cannot_be_empty')
  validates_presence_of :hostname, :message => _('Hostname_cannot_be_empty')
  validates_format_of :server_ip, :with => /(\A(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}\z)|(\A(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])\z)|^dynamic\z|^\z/, :message => _("Server_IP_is_not_valid")
  validates_uniqueness_of :server_ip, :message => _("Server_IP_is_not_valid")
  validates_uniqueness_of :hostname, :message => _("Hostname_is_not_valid")
  validates_format_of :hostname, :with => /(\A(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}\z)|(\A(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])\z)|^dynamic\z|^\z/, :message => _("Hostname_is_not_valid")

  def check_if_no_devices_own_server
    if ServerDevice.where(["server_id = ?", self.id]).count.to_i > 0
      errors.add(:id, _('Server_Has_Devices'))
      return false
    end
  end

  def check_if_no_queue_own_server
    if AstQueue.where("server_id = #{self.id}").count.to_i > 0
      errors.add(:id, _('Server_Has_queues'))
      return false
    end
  end

  def check_if_no_providers_own_server
    if Serverprovider.where(["server_id = ?", self.id]).count.to_i > 0
      errors.add(:id, _('Server_Has_Providers'))
      return false
    end
  end


  def check_if_server_is_resellers_server
    if Confline.get_value('Resellers_server_id') == self.id
      errors.add(:id, _('Server_is_default_resellers_server'))
      return false
    end
  end

  def check_server_device
    unless self.server_device
      self.create_server_device if self.id.to_i > 0
    end
  end

  def serverprovider
    Serverprovider.where(["provider_id=?", self.id]).all
  end

  def providers
    Provider.find_by_sql("SELECT providers.* FROM providers, serverproviders WHERE serverproviders.server_id = '#{self.id.to_s}' AND serverproviders.provider_id = providers.id  AND providers.hidden = 0 ORDER BY providers.id;")
  end

  #deletes realtime device from cache
  # device_id -1 means that it should work on all servers, always load - for backwards compatibility
  def prune_peer(device_name, reload = 1, sip = 1, iax2 = 1, device_id = -1)
    if self.active == 1
      server = Rami::Server.new({'host' => self.server_ip, 'username' => self.ami_username, 'secret' => self.ami_secret})
      server.console = 1
      server.event_cache = 100
      server.run

      client = Rami::Client.new(server)
      client.timeout = 3

      device_username = device_name

      # clean in all servers
      t = client.command("sip prune realtime peer " + device_username) if sip == 1
      t = client.command("iax2 prune realtime " + device_username) if iax2 == 1

      # should we load by device server and CCL status? #6795
      # https://docs.google.com/spreadsheets/d/1W43xiN66Wd4euhlB04yuV9tbStDUwpsAwNUMmO171nc/edit#gid=0

      load = 0
      if device_id.to_i == -1
        load = 1
      else
        device = Device.find(device_id.to_i)
        if device
          ccl_active = Confline.get_value('CCL_Active').to_i
          load = 1 if device.device_type.to_s == 'IAX2' && self.id.to_i == device.server_id.to_i
          load = 1 if device.device_type.to_s == 'SIP' && ccl_active.to_i != 1 && self.id.to_i == device.server_id.to_i
          load = 1 if device.device_type.to_s == 'SIP' && device.host.to_s != 'dynamic' && ccl_active.to_i == 1
        else
          load = 1
        end
      end

      if reload == 1 && load == 1
        t = client.command("sip show peer " + device_username + " load") if sip == 1
        t = client.command("sip show user " + device_username + " load") if sip == 1
        t = client.command("iax2 show peer " + device_username + " load") if iax2 == 1
      end

      client.respond_to?(:stop) ? client.stop : false
    end
  end

  def reload(check_active = 1)
    if (self.active == 1 and check_active == 1) or (check_active == 0)
      server = Rami::Server.new({'host' => self.server_ip, 'username' => self.ami_username, 'secret' => self.ami_secret})
      server.console =1
      server.event_cache = 100
      server.run

      client = Rami::Client.new(server)
      client.timeout = 3

      client.command("sip reload")
      client.command("iax2 reload")

      client.stop
    end
  end

  def ami_cmd(cmd)
    if self.active == 1
      server = Rami::Server.new({'host' => self.server_ip, 'username' => self.ami_username, 'secret' => self.ami_secret})
      server.console = 1
      server.event_cache = 100
      server.run
      client = Rami::Client.new(server)
      client.timeout = 3
      client.command(cmd)
      client.stop
    end
  end

  def create_server_device
    dev = Device.new
    dev.name = 'mor_server_' + self.id.to_s
    dev.fromuser = dev.name
    dev.host = hostname
    dev.secret = '' #random_password(10)
    dev.context = 'mor_direct'
    dev.ipaddr = server_ip
    dev.device_type = 'SIP' #IAX2 sux
    dev.port = 5060 #make dynamic later
    dev.proxy_port = 5060 #proxy_port == port (if not changed manually)
    dev.extension = dev.name
    dev.username = dev.name
    dev.user_id = 0
    dev.allow = 'all'
    dev.nat = 'no'
    dev.canreinvite = 'no'
    dev.server_id = self.id
    dev.description = 'DO NOT EDIT'
    if dev.save
    else
      if _(dev.errors.values.first.try(:first).to_s) == _('Device_extension_must_be_unique')
        errors.add(:device, _('Server_device_extension_not_unique', "mor_server_#{self.id.to_s}")) and return false
      end
    end
  end

  def server_device
    Device.where("name = 'mor_server_#{self.id.to_s}'").first
  end

  def check_role
    if self.db.to_i == 1
      ActiveRecord::Base.connection.execute("UPDATE `servers` SET `db` = 0 WHERE `db` = 1 AND `id` != #{id}")
      ActiveRecord::Base.connection.execute("UPDATE `servers` SET `db` = 1 WHERE `db` = 0 AND `id`  = #{id}")
    end
    if self.gui.to_i == 1
      ActiveRecord::Base.connection.execute("UPDATE `servers` SET `gui` = 0 WHERE `gui` = 1 AND `id` != #{id}")
      ActiveRecord::Base.connection.execute("UPDATE `servers` SET `gui` = 1 WHERE `gui` = 0 AND `id`  = #{id}")
    end
    if self.gui.to_i == 0 and Server.where(['`gui` = 1 AND `id` != ?', self.id]).count.zero?
      errors.add(:gui, _('Must_have_minimum_one_gui')) and return false
    end
    if self.db.to_i == 0 and Server.where(['`db` = 1 AND `id` != ?', self.id]).count.zero?
      errors.add(:db, _('Must_have_minimum_one_db')) and return false
    end
    if self.core.to_i == 0 and Server.where(['`core` = 1 AND `id` != ?', self.id]).count.zero?
      errors.add(:core, _('Must_have_minimum_one_core')) and return false
    end
  end

  def gui_db_core?
    if [self.gui, self.db, self.core].include? 1
      errors.add(:server, _('Server_is_used_as_GUI_DB_or_core')) and return false
    end
  end

  def which_loadstats?
    varied_labels = [
      ('cpu_mysql_load'    if db   == 1),
      ('cpu_ruby_load'     if gui  == 1),
      ('cpu_asterisk_load' if core == 1)
    ]
    return varied_labels.compact
  end

  def self.add_provider_to_server_if_not_serv_prov(server, provider, provider_id)
    server_id = server.id

    serverprovider = Serverprovider.new
    serverprovider.server_id = server.id
    serverprovider.provider_id = provider_id
    serverprovider.save

    dev = provider.device
    if dev and dev.user_id != -1
      server_device = ServerDevice.new_relation(server_id, dev.id)
      server_device.save if ServerDevice.where(server_id: server_id, device_id: dev.id).first.blank?
    end
  end

  def self.server_add(params)
    servers = Server.all
    server = Server.new({
                            hostname: params[:server_hostname].to_s.strip,
                            server_ip: params[:server_ip].to_s.strip,
                            server_type: 'asterisk', # server_type can be sip_proxy(single only when ccl_active = 1) or
                                                     # asterisk
                            version: params[:version].to_s.strip,
                            uptime: params[:uptime].to_s.strip,
                            comment: params[:server_comment].to_s.strip,
                            active: 1
                        })

    maxcalls = 1000
    maxcalls = params[:server_maxcalllimit].to_i if (params[:server_maxcalllimit]) &&
        (params[:server_maxcalllimit].length > 0)

    if maxcalls <= 2
      server.maxcalllimit = 2
    else
      server.maxcalllimit = maxcalls
    end

    serv = Rami::Server.new({'host' => server.server_ip,
                             'username' => server.ami_username,
                             'secret' => server.ami_secret})
    serv.console = 1
    serv.event_cache = 100

    return server, serv
  end

  def self.server_update(params, server)
    servers = Server.all
    errors = 0

    server_providers = Serverprovider.where(["server_id = ?", server.id])

    server.assign_attributes({
                                  hostname: params[:server_hostname].to_s.strip,
                                  server_ip: params[:server_ip].to_s.strip,
                                  stats_url: params[:server_url].to_s.strip,
                                  comment: params[:server_comment].to_s.strip,
                                  ami_username: params[:server_ami_username].to_s.strip,
                                  ami_secret: params[:server_ami_secret].to_s.strip,
                                  port: params[:server_port].to_s.strip,
                                  ssh_username: params[:server_ssh_username].to_s.strip,
                                  ssh_secret: params[:server_ssh_secret].to_s.strip,
                                  ssh_port: params[:server_ssh_port].to_s.strip
                              })

    dev = server.server_device

    server_maxcalllimit = params[:server_maxcalllimit].to_i
    server.maxcalllimit = (server_maxcalllimit <= 2 ? 2 : server_maxcalllimit)

    if dev and server.valid?
      name = 'mor_server_' + server.id.to_s
      dev.assign_attributes({
                                name: name,
                                fromuser: name,
                                extension: name,
                                username: name,
                            })
      unless dev.save
        errors += 1
        if dev.errors.values.first.try(:first).to_s ==  _('Device_extension_must_be_unique')
          server.errors.add(:device, _('Server_device_extension_not_unique', "mor_server_#{server.id.to_s}"))
        end
      end
    end

    return dev, server, errors
  end
end
