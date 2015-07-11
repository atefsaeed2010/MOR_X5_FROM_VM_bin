# -*- encoding : utf-8 -*-
class Backup < ActiveRecord::Base
  extend UniversalHelpers

  attr_accessible :id, :backuptime, :comment, :backuptype

  attr_protected

  def destroy_all
    backup_folder = Confline.get_value('Backup_Folder')
    `rm -rf #{backup_folder.to_s + "/db_dump_" + self.backuptime.to_s + ".sql.tar.gz"}`
    self.destroy
  end

  def Backup.backups_hourly_cronjob(user_id)
    MorLog.my_debug "Checking hourly backups"
    backup_shedule = Confline.get_value("Backup_shedule")
    backup_month = Confline.get_value("Backup_month")
    backup_month_day = Confline.get_value("Backup_month_day")
    backup_week_day = Confline.get_value("Backup_week_day")
    backup_hour = Confline.get_value("Backup_hour")
    backup_number = Confline.get_value('Backup_number')

    MorLog.my_debug("Make backups at: #{backup_hour} h", true, "%Y-%m-%d %H:%M:%S")
    backup_hour = backup_hour.to_i == 24 ? 0 : backup_hour.to_i

    @time = Time.now()
    if backup_shedule.to_i == 1
      if (backup_month.to_i == @time.month.to_i) or (backup_month.to_s == "Every_month")
        if (backup_month_day.to_i == @time.day.to_i) or (backup_month_day.to_s == "Every_day")
          if (backup_week_day.to_i == @time.wday.to_i) or (backup_week_day.to_s == "Every_day")
            if (backup_hour.to_i == @time.hour.to_i) or (backup_hour.to_s == "Every_hour")
              res = 0
              MorLog.my_debug "Making auto backup"

              if space_available?
                # check if we have correct number of auto backups
                MorLog.my_debug "Checking for old backups"
                backups = Backup.where(backuptype: 'auto')
                while backups.size.to_i >= backup_number.to_i do
                  backup = Backup.where(backuptype: 'auto').order("backuptime ASC").first
                  backup.destroy_all
                  MorLog.my_debug "Old auto backup deleted"
                end
                #make backup
                res = Backup.private_backup_create(user_id, "auto", "")
              else
                res = 2
              end

              if res > 0
                MorLog.my_debug("Auto backup failed")
                Action.add_error(user_id, 'Auto Backup', {data2: 'There is not enough space on HDD'})
              else
                MorLog.my_debug("Auto backup created")
              end
            end
          end
        end
      end
    end
  end

  def Backup.private_backup_create(user_id, backuptype = "manual", comment = "")
    time = Time.now().to_s(:db)
    backuptime = time.gsub(/[- :]/, '').to_s
    backup_folder = Confline.get_value("Backup_Folder")

    backup_folder = "/usr/local/mor/backups" if backup_folder.to_s == ''
    space_available = backuptype == 'auto' ? true : space_available?

    if space_available
      MorLog.my_debug("/usr/local/mor/make_backup.sh #{backuptime} #{backup_folder} -c")
      script = `/usr/local/mor/make_backup.sh #{backuptime} #{backup_folder} -c`

      return_code = script.to_s.scan(/\d+/).first.to_i
      MorLog.my_debug(return_code)

      if return_code.zero?
        backup = Backup.new
        backup.comment = comment
        backup.backuptype = backuptype
      	backup.backuptime = backuptime
       	backup.save
       	MorLog.my_debug("Auto backup made", true, "%Y-%m-%d %H:%M:%S")
        Action.add_action_second(user_id.to_i, 'backup_created', backup.id, return_code)
      else
        return_code = 1  # backup script error
      end
  	else
      return_code = 2  # not enought space
    end

    return_code
  end

  private

  def self.space_available?
    available = true

    MorLog.my_debug('Checking free HDD space')

    backup_folder = Confline.get_value('Backup_Folder').to_s
    backup_disk_space_percent = Confline.get_value('Backup_disk_space')

    db_config = Rails.configuration.database_configuration[Rails.env]
    #Retrieves the space required to make a backup for the Database, in KB
    required_disk_space_from_script = `/usr/bin/mysql -h "#{db_config['host']}" -u #{db_config['username']} --password=#{db_config['password']} "#{db_config['database']}" -e "SELECT ROUND(SUM(Data_length)/1024) AS SIZE FROM  INFORMATION_SCHEMA.PARTITIONS WHERE TABLE_SCHEMA = '#{db_config['database']}' AND   TABLE_NAME  != 'call_logs' AND   TABLE_NAME  != 'sessions'" | tail -n 1`
    required_disk_space = required_disk_space_from_script.to_i * 2

    space = disk_space_usage(backup_folder).to_i
    space_percent = (100 - disk_space_usage_percent(backup_folder).to_i)

    MorLog.my_debug "Free space on HDD for backups: #{space} KB #{space_percent} %"
    MorLog.my_debug "Required space on HDD for backups: #{required_disk_space} KB #{backup_disk_space_percent} %"

    if (space < required_disk_space) or (space_percent < backup_disk_space_percent.to_i)
      MorLog.my_debug "Not enough space on HDD to make new backup"
      available = false
    end

    available
  end
end
