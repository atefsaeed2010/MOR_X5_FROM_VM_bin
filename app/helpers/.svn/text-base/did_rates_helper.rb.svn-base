# -*- encoding : utf-8 -*-
module DidRatesHelper
  def did_not_free(did)
    return (
      did.user and did.status != "free" and not did.dialplan
      )
  end

  def nice_did_rate_explain(type)
    case type
      when 'incoming'
        _('DID_incoming_rate_explained')
      when 'provider'
        _('DID_Provider_rate_explained')
      when 'owner'
        _('DID_owner_rate_explained')
    end
  end
end
