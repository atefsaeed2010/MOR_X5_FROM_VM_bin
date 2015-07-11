module PermissionsHelper

  def check_selectable_field(name)
    exceptions = %w{ users_usage_create1 devices_usage_create1 calls_statistics_usage_active2
                     finances_statistics_usage_active2 various_statistics_usage_active2  }
    return exceptions.member?(name) ? false : true
  end

  def b_cross_disabled(options = {})
    options[:id] = "icon_cross_"+options[:id].to_s if options[:id]
    image_tag('icons/cross_disabled.png', {:title => "disabled"}.merge(options)) + " "
  end
end
