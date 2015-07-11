class Did::BulkFactory
  ATTRIBUTES = [:start_number, :end_number, :provider]

  attr_accessor *ATTRIBUTES
  attr_reader :invalid_dids
  attr_reader :dids_created

  def initialize(attributes)
    attributes.each do |attribute, value|
      send("#{attribute}=", value)
    end
  end

  def fabricate!
    fields = [:did, :status, :user_id, :device_id, :subscription_id, :reseller_id, :provider_id]
    values = []

    range = (start_number.to_s..end_number.to_s)
    current_user = User.current
    corrected_user_id = User.current.get_corrected_owner_id

    #Already existing DIDs
    invalid_dids = Did.where(did: range).where("length(did) = #{start_number.length}").all
    invalid_dids.each do |did|
      did.errors.add(:did, _('DID_must_be_unique'))
    end

    interval = range.to_a - invalid_dids.map(&:did)

    #Foreign QuickForward rule collisions
    if current_user.is_reseller?
      rules = []
      QuickforwardsRule.where.not(user_id: current_user.id).includes(:user).each do |quickforward_rule|
        regular_expression = Regexp.new(quickforward_rule.rule_regexp.gsub('%', '\d+').gsub('|', '|^').prepend('^'))
        rules << OpenStruct.new(regexp: regular_expression, user: quickforward_rule.user.username)
      end

      interval.each do |did_number|
        rules.each do |rule|
          did = Did.new(did: did_number)
          if rule.regexp.match(did_number.to_s)
            invalid_dids << did if did.errors.blank?
            did.errors.add(:did, _('collisions_with_qf_rules_belonging_to', rule.user.to_s.upcase))
          end
        end
      end
      interval -= invalid_dids.map(&:did)
    end

    interval.each do |did_number|
      values << [did_number, 'free', 0, 0, 0, corrected_user_id, provider]
    end

    Did.import fields, values, validate: false

    valid_dids = Did.where(did: range).where("length(did) = #{start_number.length}").all - invalid_dids

    create_rates_and_actions(valid_dids)

    @invalid_dids = invalid_dids
    @dids_created = valid_dids.size
  end

  private

  def create_rates_and_actions(dids)
    rate_types = ['provider', 'owner', 'incoming']
    rate_fields = [:rate_type, :did_id]
    rate_values = []

    action_fields = [:date, :user_id, :action, :data]
    action_values = []

    current_user_id = User.current.id
    current_time = Time.now

    dids.each do |did|
      did_id = did.id
      rate_types.each do |type|
        rate_values << [type, did_id]
      end
      action_values << [Time.now, current_user_id, 'did_created', did_id]
    end

    Didrate.import rate_fields, rate_values, validate: false
    Action.import action_fields, action_values, validate: false
  end
end
