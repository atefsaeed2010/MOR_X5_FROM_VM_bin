class Forms::FormObject
  # ActiveModel plumbing to make `form_for` work
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations

  ATTRIBUTES = []

  def persisted?
    false
  end

  def initialize(attributes = {})
    attributes ||= {}
    @attributes = @attributes = self.class::ATTRIBUTES
    attributes.each do |attribute, value|
      send("#{attribute}=", value)
    end
  end

  #returns a hash of attributes and their values
  def attributes
    hashed_attributes = {}

    @attributes.each do |attribute|
      hashed_attributes[attribute] = send(attribute)
    end

    hashed_attributes
  end
end