module Forms
  module Dids
    class BulkForm < FormObject
      ATTRIBUTES = [:start_number, :end_number, :provider]

      attr_accessor *ATTRIBUTES

      validates :start_number, :end_number, presence: {message: _('Bad_interval_start_or_end')}
      validates :start_number, :end_number, numericality: {message: _('Bad_interval_start_or_end')}


      validate :existing_provider
      validate :must_have_correct_interval

      def must_have_correct_interval
        if end_number.to_i < start_number.to_i
          errors.add(:start_number, _('Bad_interval_start_or_end'))
          return false
        end
        true
      end

      def existing_provider
        prov = nil
        current_user = User.current
        if current_user.is_reseller?
          pr_id = current_user.allow_manage_providers_tariffs? ? provider : Confline.get_value("DID_default_provider_to_resellers").to_i.to_s
          prov = Provider.where(["id=?", pr_id]).first
          self.provider = prov.try(:id)
        else
          prov = Provider.where(["id=?", provider]).first if provider
        end

        unless prov
          errors.add(:provider, _('Provider_Not_Found'))
          return false
        end

        true
      end

      def total
        end_number.to_i - start_number.to_i + 1
      end
    end
  end
end