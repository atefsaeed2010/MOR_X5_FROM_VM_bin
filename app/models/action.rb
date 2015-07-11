# -*- encoding : utf-8 -*-
# Represents logger for system administrator.
class Action < ActiveRecord::Base

  attr_protected

  belongs_to :user

  # Adds action in Action table. Action time is current time. Return false if user was not found.
  # * +user_id+ - id of the user that experienced the problem.
  # * +action+ - action to describe what was happening.
  # * +message+ - problem description.
  def Action.add_action(user_id, action = "", message = "")
    if user_id and User.where(id: user_id).first
      act = Action.new
      act.date = Time.now
      act.user_id = user_id
      act.action = action.to_s
      act.data = message.to_s
      act.save
      return act
    else
      return false
    end
  end

  # Adds action in Action table. Action time is current time. Return false if user was not found.
  #
  # * +user_id+ - id of the user that experienced the problem.
  # * +user_id+ - action to describe what was happening.
  # * +message+ - problem description.

  def Action.add_action_second(user_id, action = "", data = "", data2 = "")
    if user_id and User.where(id: user_id).first
      act = Action.new
      act.date = Time.now
      act.user_id = user_id
      act.action = action.to_s
      act.data = data.to_s
      act.data2 = data2.to_s
      act.save
      return act
    else
      return false
    end
  end

 # Adds action in Action table. Action time is current time. Return false if user was not found.
 # * +user_id+ - id of the user that experienced the problem.
 # * +details+ - Hash of Action params. Any action param can be overloaded.
  def Action.add_action_hash(user, details={})
    if user.class == User
      uid = user.id
    else
      uid = user
    end

    date = details[:date]
    detai = {
        :date => date.blank? ? Time.now : date,
        :data => "",
        :data2 => "",
        :user_id => uid,
        :target_id => nil,
        :target_type => "",
        :action => ""
    }.merge(details)
    if user and !uid.blank?
      act = Action.new
      act.update_attributes(detai)
      return act
    else
      return false
    end
  end

  # Adds error message to actions table. Action time is current time. Return false if user was not found.
  #
  # * +user_id+ - id of the user that experienced the problem.
  # * +message+ - problem description.

  def Action.add_error (user_id, message = "", opts = {})
    if user_id and User.where(id: user_id).first
      act = Action.new
      act.date = Time.now
      act.user_id = user_id
      act.action = "error"
      act.data = message.to_s
      act.processed = 0
      [:data2, :data3, :data4].each do |key|
        option = opts[key]
        act[key] = option if option
      end
      act.save
      return act
    else
      return false
    end
  end

  def Action.create_email_sending_action(obj, action, email, options = {})
    act = Action.new
    act.date = Time.now
    act.processed = 0
    if action == 'sms_email_sent'
      if options
        act.user_id= options[:email_from_user].id
        act.target_id=options[:sms_id]
        act.data=options[:email_to_address]
      end
      act.action=action
      act.target_type="Sms"
    else
      obj_is_user = obj.class.to_s == 'User'
      owner = obj_is_user ? obj.owner_id : 0
      act.user_id = owner

      if options and options[:er_type].to_i == 0
        act.data = obj.id
        act.data2 = email.id
        if options[:status]
          act.action = obj_is_user ? 'email_sent' : 'paypal_email_sent'
        else
          act.action = 'email_not_sent'
        end
        status = act.action
      else
        act.action = 'error'
        act.data = 'Cant_send_email'
        message = _('Emeil_is_empty')
        message += " " + obj.first_name + " " + obj.last_name if obj_is_user
        act.data2 = message
        act.data3 = email.id
        act.data4 = options[:err_message] if options[:err_message]
        status = message
      end
      act.target_id = obj.id
      act.target_type = obj.class.to_s.downcase
    end
    act.save
    return status
  end

  def Action.create_cards_action(order, message = "card_sold")
    cards = order.cards
    for card in cards
      act = Action.new
      act.date = Time.now
      act.action = message
      act.data = card.id
      act.data2 = order.payer_email
      act.save
    end
  end

  def Action.dont_be_so_smart(user_id, request, params)
    user_id ||= '-1'
    Action.new(:user_id => user_id, :date => Time.now.to_s(:db), :action => "hacking_attempt", :data => request["REQUEST_URI"].to_s[0..255], :data2 => request["REMOTE_ADDR"].to_s, :data3 => params.inspect.to_s[0...255]).save
  end

  def Action.set_first_call_for_user(from, till)
    calls = Call.count(:all, :select => "distinct(user_id)", :conditions => ["calls.calldate <= '#{till}' AND user_id >= 0"])

    actions = Action.count(:all, :select => "distinct(user_id)", :conditions => ["action='first_call' AND date <= '#{till}'"])
    if calls.to_i > actions.to_i
      sql = "select calls.id, calldate, card_id, user_id from calls
                  JOIN (SELECT users.id FROM users
                        LEFT OUTER JOIN actions ON(users.id = actions.user_id AND actions.action = 'first_call')
                        WHERE actions.id IS NULL) as users ON (users.id = calls.user_id)
                  WHERE user_id != -1 AND calldate != '0000-00-00 00:00:00'
                  GROUP BY calls.user_id
                  ORDER BY calls.id ASC"
      res3 = ActiveRecord::Base.connection.select_all(sql)
      res3.each do |res|
        Action.add_action_hash(res['user_id'], {:action => "first_call", :date => res['calldate'], :data => res['id'], :data2 => res['card_id']})
      end
    end
    calls_size = Action.count(:all, :select => "distinct(user_id)", :conditions => ["action='first_call' AND date BETWEEN '#{from}' AND '#{till}'"])
    return calls_size
  end

  def Action.actions_order_by(options)
    order_by_options = options[:order_by].to_s.strip
    order_desc = options[:order_desc] || 0
    order_by = order_by_finder(order_by_options)

    if order_by.present?
      if order_desc.to_i.zero?
        order_by += " ASC"
      else
        order_by += " DESC"
      end
    end

    return order_by
  end

  def Action.condition_for_action_log_list(current_user, a1, a2, s_int_ch, options)
    #conditions
    cond_arr = []
    join = ""
    current_user.usertype == 'admin' ? cond = [] : cond = ["actions.action NOT in ('bad_login')"]

    if current_user.usertype == 'reseller'
      cond << "users.owner_id = ?"
      cond_arr << current_user.id
    end

    if !s_int_ch or s_int_ch.to_i != 1
      cond << "actions.date BETWEEN ? AND ?"
      cond_arr << a1.to_s
      cond_arr << a2.to_s
      if options[:s_type].to_s != "all"
        cond << "actions.action = ? "
        cond_arr << options[:s_type].to_s
      end
      if options[:s_user].to_i != -1
        cond << "actions.user_id = ? "
        cond_arr << options[:s_user].to_i
      end
      unless options[:s_did].blank?
        join << " JOIN dids ON (actions.data = dids.id)"
        cond << "dids.id = ?"
        cond_arr << options[:s_did]
        if options[:s_type].to_s == "all"
          cond << "actions.action LIKE 'did%'"
        end
      end
      if options[:s_processed].to_i != -1
        cond << "actions.processed = ? "
        cond_arr << options[:s_processed].to_s
      end
    else
      options[:s_type] = 'error'
      cond << "actions.action = ? "
      cond_arr << 'error'
      cond << "actions.processed = ? "
      cond_arr << 0
    end

    [:s_target_type, :s_target_id].each do |condition|
      unless options[condition].blank?
        cond << "#{condition.to_s.match(/\As_(.*)\Z/)[1]} = ?"
        cond_arr << options[condition]
      end
    end

    #ticket #5173 - hide hourly actions
    #Note that NULL != 'hourly..' will return FALSE, thats why additional OR is needed
    cond << "(actions.data4 != 'hourly_actions_cooldown_time' OR actions.data4 IS NULL)"

    join << " JOIN users on (actions.user_id = users.id)"

    return cond, cond_arr, join
  end

  def Action.disable_login_check(ip)
    found = 0

    actions = Action.where(["action in ('login', 'bad_login') and (data = ? or data2 = ?)", ip, ip]).order('date DESC').limit(3).all
    actions_size = actions.size.to_i
    found = 1 if  !actions or actions_size < 3
    if actions and actions_size > 0
      actions.each do |action|
        found = 1 if action.action.to_s == 'login'
      end
    end
    return found.to_i
  end

  def toggle_processed
    self.processed = processed.to_i == 1 ? 0 : 1
    save
  end

  def self.order_by_finder(order_by_options)
    case order_by_options
      when "user" then
        order_by = "users.first_name"
      when "type" then
        order_by = "actions.action"
      when "date" then
        order_by = "actions.date"
      when "data" then
        order_by = "actions.data"
      when "data2" then
        order_by = "actions.data2"
      when "data3" then
        order_by = "actions.data3"
      when "data4" then
        order_by = "actions.data4"
      when "processed" then
        order_by = "actions.processed"
      when "target" then
        order_by = "actions.target_type, actions.target_id "
      else
        order_by = order_by_options || "actions.action"
    end
  end
end
