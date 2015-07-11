class CallingCard::BulkFactory
  ATTRIBUTES = [:start_number, :end_number, :min_balance, :batch_number, :language, :distributor_id, :card_group]

  attr_accessor *ATTRIBUTES
  attr_writer :trial
  attr_reader :invalid_cards
  attr_reader :cards_created

  def initialize(attributes)
    attributes.each do |attribute, value|
      send("#{attribute}=", value)
    end
  end

  def fabricate!

    cards_count = Card.where(cardgroup_id: card_group.id).count

    #Initial data values
    card_price = card_group.read_attribute(:price)
    owner_id = User.current.modified_owner_id
    min_balance ||= 0

    cards = []

    #Determines invalid cards.
    @invalid_cards = Card.select('cards.*, cardgroups.name AS \'ccg_name\'').joins(:cardgroup).where("cards.number BETWEEN #{start_number} AND #{end_number}").all
    @invalid_cards.each do |card|
      card.errors.add(:number, "#{_('Card_with_this_number_already_exists')} : #{card.number} (#{card.ccg_name})") if (card.owner_id.to_i == owner_id or owner_id == 0)
    end

    interval = (start_number..end_number).to_a - @invalid_cards.map(&:number)

    #Reduces the interval, if calling cards are not active
    interval = interval[0...(10 - cards_count)] if @trial

    pin_length = self.card_group.pin_length
    pins = generate_pins(interval.size, [], Card.existing_pins(pin_length), pin_length)
    interval.each_with_index do |card_number, index|
      cards << "(#{distributor_id}, #{card_price}, #{card_group.id}, '#{false}', '#{card_number}', '#{pins[index]}', #{owner_id}, '#{language}', '#{batch_number}', #{min_balance})"
    end

    if cards.any?
      sql = "INSERT INTO cards (`user_id`, `balance`, `cardgroup_id`, `sold`, `number`, `pin`, `owner_id`, `language`, `batch_number`, `min_balance`) VALUES #{cards.join(',')}"
      Card.connection.execute(sql)
    end

    @cards_created = interval.size
  end

  private

  def generate_pins(to_create, pins, existing_pins, pin_length)
    if to_create != 0
      new_pins = []
      to_create.times { new_pins << generate_pin(pin_length) }
      new_pins.uniq!
      new_pins -= existing_pins
      pins += new_pins
      to_create -= new_pins.size
      generate_pins(to_create, pins, existing_pins, pin_length)
    end
    pins
  end

  def generate_pin(length)
    max = ''
    length.times { max << '9' }
    sprintf("%0#{length}d", rand(max.to_i)).to_sym
  end
end