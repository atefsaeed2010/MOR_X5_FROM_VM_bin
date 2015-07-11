module Forms
  module CallingCards
    class BulkForm < FormObject
      ATTRIBUTES = [:start_number, :end_number, :min_balance, :batch_number, :language, :distributor_id, :card_group]
      DEFAULTS = {language: 'en'}

      attr_accessor *ATTRIBUTES

      validates :start_number, numericality: {message: _('Number_is_not_numerical_value')}
      validates :end_number, numericality: {message: _('Number_is_not_numerical_value'), unless: :invalid_interval?}

      validate :must_have_correct_length
      validate :must_have_correct_interval
      validate :must_have_available_interval

      def initialize(attributes = {})
        super(DEFAULTS.merge(attributes))
      end

      def must_have_correct_interval
        unless invalid_interval?
          if end_number.to_i < start_number.to_i
            errors.add(:start_number, _('Bad_interval_start_and_end'))
            return false
          end
        end
        true
      end

      def must_have_available_interval
        unless invalid_interval?
          unless card_group.pins_available?(total)
            errors.add(:start_number, "#{_('Bad_number_interval_max')}: #{card_group.total_pins_available} #{_('cards')}")
            return false
          end
        end
        true
      end

      def must_have_correct_length
        unless invalid_interval?
          number_length = card_group.number_length
          if end_number.to_s.length != number_length || start_number.to_s.length != number_length
            errors.add(:start_number, "#{_('Bad_number_length_should_be')}: #{card_group.number_length}")
            return false
          end
        end
        true
      end

      def total
        end_number.to_i - start_number.to_i + 1
      end

      private

      def invalid_interval?
        errors.get(:start_number) || errors.get(:end_number)
      end
    end
  end
end