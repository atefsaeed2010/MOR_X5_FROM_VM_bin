# -*- encoding : utf-8 -*-
class Campaign < ActiveRecord::Base

  attr_protected

  belongs_to :user
  belongs_to :device
  has_many :adnumbers
  has_many :adactions, -> { order('priority ASC') }, :dependent => :destroy

  before_save :validate_device, :check_time

  def validate_device
    if !['admin', 'accountant'].include?(User.current.usertype)
      if device
        dev_user = device.user
      else
        errors.add(:device, _("Device_not_found"))
        return false
      end
      if User.current.usertype == 'reseller' and device and !Device.joins("LEFT JOIN users ON (devices.user_id = users.id)").where("devices.id = #{device.id} and (users.owner_id = #{User.current.id} or users.id = #{User.current.id})").first
        errors.add(:device, _("Device_not_found"))
        return false
      end

      if User.current.usertype == 'user' and device and dev_user and dev_user.id != User.current.id
        errors.add(:device, _("Device_not_found"))
        return false
      end
    end
  end

  def check_time
    if retry_time.to_i < 60
      errors.add(:retry_time, _("Please_enter_retry_time_higher_or_equal_to_60"))
      return false
    end
    if wait_time.to_i < 10
      errors.add(:wait_time, _("Please_enter_wait_time_higher_or_equal_to_10"))
      return false
    end
  end

  def new_numbers_count
    Adnumber.count_by_sql "SELECT COUNT(adnumbers.id) FROM adnumbers WHERE adnumbers.campaign_id = '#{self.id}' AND status = 'new'"
  end

  def executed_numbers_count
    Adnumber.count_by_sql "SELECT COUNT(adnumbers.id) FROM adnumbers WHERE adnumbers.campaign_id = '#{self.id}' AND status = 'executed'"
  end

  def completed_numbers_count
    Adnumber.count_by_sql "SELECT COUNT(adnumbers.id) FROM adnumbers WHERE adnumbers.campaign_id = '#{self.id}' AND status = 'completed'"
  end

  def completed_numbers_user_billsec
    #sql = "SELECT SUM(calls.user_billsec) FROM adnumbers JOIN calls ON (adnumbers.channel = calls.channel) WHERE adnumbers.campaign_id = '#{self.id}' AND status = 'completed'"
    #res = ActiveRecord::Base.connection.select_value(sql)
    0
  end

  def user_price
    #sql = "SELECT SUM(calls.user_price) FROM adnumbers JOIN calls ON (adnumbers.channel = calls.channel) WHERE adnumbers.campaign_id = '#{self.id}' AND status = 'completed'"
    #res = ActiveRecord::Base.connection.select_value(sql)
    0
  end

  def profit
    #sql = "SELECT SUM(calls.user_price - calls.provider_price) FROM adnumbers JOIN calls ON (adnumbers.channel = calls.channel) WHERE adnumbers.campaign_id = '#{self.id}' AND status = 'completed'"
    #res = ActiveRecord::Base.connection.select_value(sql)
    0
  end

  def count_completed_user_billsec(device, channels, from, till)
    sql =" SELECT SUM(calls.user_billsec) FROM calls WHERE (src_device_id = #{device} AND channel REGEXP '#{channels}' AND disposition = 'ANSWERED' AND calldate BETWEEN '#{from} 00:00:00' AND '#{till} 23:59:59') "
    ActiveRecord::Base.connection.select_value(sql)
  end

  def count_completed_user_billsec_longer_than_ten(device, channels, from, till)
    sql =" SELECT SUM(calls.user_billsec) FROM calls WHERE (src_device_id = #{device} AND channel REGEXP '#{channels}' AND disposition = 'ANSWERED' AND calldate BETWEEN '#{from} 00:00:00' AND '#{till} 23:59:59') AND user_billsec > 10"
    ActiveRecord::Base.connection.select_value(sql)
  end

  def final_path
    path = Confline.get_value("Temp_Dir")
    final_path = Confline.get_value('AD_Sounds_Folder')

    if final_path.to_s == ""
      final_path = "/home/mor/public/ad_sounds"
    end

    MorLog.my_debug "final_path:" + final_path.to_s

    return path, final_path
  end

  #Campaign will not be able to start if user is blocked
  def user_blocked?
    device.user.blocked?
  end

  #Campaign will not be able to start if user is prepaid and does not have balance
  def user_has_no_balance?
    device.user.prepaid? and device.user.balance <= 0
  end

  def self.create_by_user(user, params, time_from, time_till)
    campaign = self.new(params[:campaign])
    campaign.user_id = user.id
    campaign.owner_id = user.owner_id
    campaign.status = "disabled"
    if !!!(params[:campaign][:max_retries].to_s =~ /^[+]?[0-9]+$/)
      campaign.errors.add(:max_retries, _('Max_retries_must_be_integer'))
      errors = 1
    end
    campaign.start_time = time_from.strftime('%H:%M:%S')
    campaign.stop_time = time_till.strftime('%H:%M:%S')
    return campaign
  end

  def update_by(params, time_from, time_till)
    self.update_attributes(params)
    if !!!(params[:max_retries].to_s =~ /^[+]?[0-9]+$/)
      self.errors.add(:max_retries, _('Max_retries_must_be_integer'))
    end
    self.start_time = time_from.strftime('%H:%M:%S')
    self.stop_time = time_till.strftime('%H:%M:%S')

    #    @campaign.retry_time = 60 if params[:campaign][:retry_time].to_i < 60
    #    @campaign.wait_time = 30 if params[:campaign][:wait_time].to_i < 30
  end

  # On success return notice to be flashed
  def change_status
    notice = ''
    status_changed = false
    adactions_size = self.adactions.size

    if self.status == "enabled"
      self.status = "disabled"
      notice = _('Campaign_stopped') + ": " + self.name
      status_changed = true
    else
      notice =  _('No_actions_for_campaign') + ": " + self.name  if adactions_size == 0
      notice =  _('No_free_numbers_for_campaign') + ": " + self.name if self.new_numbers_count == 0
      #note the order in whitch we are checking whether campaing will be able to start
      #dont change it without any reason(ticket #2594)
      notice = _('User_has_no_credit_left') if self.user_has_no_credit?
      notice = _('User_has_empty_balance') if self.user_has_no_balance?
      notice = _('User_is_blocked') if self.user_blocked?

      if adactions_size > 0 and self.new_numbers_count > 0 and !self.user_has_no_credit? and !self.user_has_no_balance? and !self.user_blocked?
        self.status = "enabled"
        notice = _('Campaign_started') + ": " + self.name
        status_changed = true
      end
    end
    return notice, status_changed
  end

=begin
  Campaign will not be able to start if user is postpaid and does not have balance
  and/or credit left
  credit -1 means user has unlimited credit
=end
  def user_has_no_credit?
    device.user.postpaid? and device.user.balance + device.user.credit <= 0 and device.user.credit != -1
  end

=begin
    analyzes csv file and import numbers
    requires temporary table name
    returns number of file lines as numbers and imported lines size
=end
  def insert_numbers_from_csv_file(name, trial = {})
    CsvImportDb.log_swap('analize')
    MorLog.my_debug("CSV analize_file #{name}", 1)
    numbers_in_csv_file = (ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name}").to_i).to_s

    #------------ Analyze ------------------------------------
    # set error flag on duplicates | code : 1
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 1 WHERE f_number IN (SELECT number FROM (select f_number as number, count(*) as u from #{name} group by f_number  having u > 1) as imf )")

    # unset error for first number of duplicates
    ActiveRecord::Base.connection.execute("UPDATE #{name}, (SELECT id FROM #{name} WHERE f_error = 1 AND nice_error = 1 GROUP BY f_number) AS A SET f_error = 0, nice_error = 0 WHERE f_error = 1 AND nice_error = 1 AND #{name}.id = A.id")

    # set error flag where number is found in DB | code : 2
    ActiveRecord::Base.connection.execute("UPDATE #{name} LEFT JOIN adnumbers ON (replace(f_number, '\\r', '') = adnumbers.number AND adnumbers.campaign_id = #{self.id}) SET f_error = 1, nice_error = 2 WHERE adnumbers.id IS NOT NULL AND f_error = 0")

    # set error flag on not int numbers | code : 3
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 3 WHERE replace(f_number, '\\r', '') REGEXP '^[0-9]+$' = 0")

    #------------ Import -------------------------------------
    CsvImportDb.log_swap('create_adnumbers_start')
    MorLog.my_debug("CSV create_adnumbers #{name}", 1)
    count = 0
    s = [] ; ss=[]
    ["status", "number", "campaign_id"].each{ |col|

      case col
        when "status"
          s << "'new'"
        when "campaign_id"
          s << self.id.to_s
        when "number"
          s <<  "replace(f_number, '\\r', '')"
      end
      ss << col
    }

    #if autodialer addon isn't active than set numbers limit to 10
    if trial[:status] == 'autodialer'
      limit = trial[:limit]
    else
      limit = 1000
    end

    s1 = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_error = 0").to_i
    n = s1/1000 + 1

    n.times{| i|
      nr_sql = "INSERT INTO adnumbers (#{ss.join(',')})
                    SELECT #{s.join(',')} FROM #{name}
                    WHERE f_error = 0 LIMIT #{i * 1000}, #{limit}"
      begin
        ActiveRecord::Base.connection.execute(nr_sql)
        count += ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_error = 0 LIMIT #{i * 1000}, #{limit}").to_i
      end
    }

    #when autodialer addon isn't active then imported numbers should not be above limit
    if trial[:status] == 'autodialer'
      count = limit if (limit < count)
    end
    bad_numbers_count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_error = 1").to_i

    CsvImportDb.log_swap('create_adnumbers_end')
    return numbers_in_csv_file, count, bad_numbers_count
  end
end
