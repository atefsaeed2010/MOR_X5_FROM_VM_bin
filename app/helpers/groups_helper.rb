# -*- encoding : utf-8 -*-
module GroupsHelper
  def options_for_translations(group)
    options_for_select(Translation.all.collect { |t| [t.name, t.id] }.sort_by { |lang_name, lang_id| lang_name.downcase}, group.try(:translation_id))
  end

  def b_up
    image_tag('icons/arrow_up.png', :title => _('Up')) + " "
  end

  def b_change_type
    image_tag('icons/user_edit.png', :title => _('Change_type')) + " "
  end

  def postpaid?(group, params = {})
    postpaid = params.try(:[],:postpaid)
    if postpaid.blank?
      postpaid = group.postpaid.to_i
    else
      postpaid = postpaid.to_i
    end
    postpaid == 1 || postpaid == -1
  end
end
