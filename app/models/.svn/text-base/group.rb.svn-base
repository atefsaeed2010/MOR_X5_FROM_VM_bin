# -*- encoding : utf-8 -*-
class Group < ActiveRecord::Base
  attr_accessible :id, :user, :name, :grouptype, :owner_id, :description, :translation_id, :simple_session, :postpaid, :balance

  has_many :usergroups, :dependent => :destroy
  belongs_to :user, :foreign_key => 'owner_id'
  belongs_to :translation

  def users
    User.from("users, usergroups").where("users.id = usergroups.user_id AND usergroups.group_id = #{id}").order("gusertype ASC, position ASC")
  end

  def simple_users
    User.from("users, usergroups").where("users.id = usergroups.user_id AND usergroups.group_id = #{id} AND usergroups.gusertype = 'user'").order("gusertype ASC, position ASC")
  end

  def manager_users
    User.from("users, usergroups").where("users.id = usergroups.user_id AND usergroups.group_id = #{id} AND usergroups.gusertype = 'manager'").order("gusertype ASC, position ASC")
  end

  def move_member(member, direction)
    unless (users.last == member and direction == "down") || (users.first == member and direction == "up")
      current_member = Usergroup.where({:group_id => self.id, :user_id => member.id}).first
      if current_member.gusertype == "user"
        if direction == "down"
          following_member = Usergroup.where({:group_id => self.id, :position => current_member.position + 1}).first
          current_member.update_attribute(:position, current_member.position + 1)
          following_member.update_attribute(:position, following_member.position - 1)
        else
          previous_member = Usergroup.where({:group_id => self.id, :position => current_member.position - 1}).first
          current_member.update_attribute(:position, current_member.position - 1)
          previous_member.update_attribute(:position, previous_member.position + 1) if previous_member
        end
        true
      else
        false
      end
    else
      false
    end
  end

  def logged_users
    lu=[]
    for user in self.users
      lu << user if user.logged == 1
    end
    lu
  end

  def gusertype(user)
    ut = ""
    if self.users.include?(user)
      #my_debug "self.users.include?(user): true"
      ut = ActiveRecord::Base.connection.select_value("SELECT gusertype FROM usergroups WHERE group_id='" + self.id.to_s + "' AND user_id='" + user.id.to_s + "'").to_s
    end
    ut
  end

  ##==============================================================

  #put value into file for debugging
  def my_debug(msg)
    File.open(Debug_File, "a") { |f|
      f << msg.to_s
      f << "\n"
    }
  end

  def update_members(params)
    for user in self.users
      user.sales_this_month = params["sales_this_month_#{user.id}".intern].to_i
      user.sales_this_month_planned = params["sales_this_month_planned_#{user.id}".intern].to_i

      user.calltime_normative = params["calltime_normative_#{user.id}".intern].to_d
      user.show_in_realtime_stats = params["show_in_realtime_stats_#{user.id}".intern].to_i

      #my_debug params["show_in_realtime_stats_#{user.id}".intern].to_i
      #      my_debug params["sales_this_month_#{user.id}".intern]
      #     my_debug params["sales_this_month_planned_#{user.id}".intern]

      user.save
    end
  end

  def get_members(call_shop_active)
    #User can't see more than 2 call booths in free mode
    manager_users = self.manager_users
    if call_shop_active
      simple_users = self.simple_users
    else
      simple_users = manager_users.blank? ? self.simple_users[0..1] : self.simple_users.limit(1)
    end
    return manager_users, simple_users
  end

  def add_group(user,params)
    success = true
    usergroup = Usergroup.new({:user_id => user.id, :group_id => self.id})
    usergroup.gusertype = (params[:as_manager].to_s == "true" ? "manager" : "user")
    usergroup.position = (self.usergroups.any?) ? self.usergroups.last.position + 1 : 0
    if usergroup.save
      user.blocked = 1 if usergroup.gusertype == "user"
      user.save
    else
      success = false
    end
    return usergroup, success
  end

  def update_simple_session(params = {})
    if params[:simple_session].blank?
      self.balance = 0
      self.postpaid = -1
      self.simple_session = 0
    else
      if params[:postpaid].to_i == 1
        self.balance = 0
      else
        unless params[:balance].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/
          self.errors.add(:balance, _('balance_numerical'))
        end
      end
    end

    self.errors.empty? && self.save
  end

end
