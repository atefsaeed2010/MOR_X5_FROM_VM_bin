# AS: development sees untranslated strings
def _(str, *args)
  hash = {}
  unless args.blank?
    keys = [:s]
    args_size = args.size - 1
    args_size.times {|index| keys << "s#{index.next}".to_sym}
    hash = Hash[keys.zip(args)]
  end
  Rails.env == 'development' ? I18n.t("mor.#{str}", hash) : I18n.t("mor.#{str}", hash.merge(default: str))
end
