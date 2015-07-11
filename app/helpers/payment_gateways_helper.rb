# -*- encoding : utf-8 -*-
module PaymentGatewaysHelper
  def pg_testing(gateway)
    return (
      ((!gateway.settings['testing']) ||
      (gateway.settings['testing'] && Confline.get_value("test_production_environment") == "true"))
      )
  end
end
