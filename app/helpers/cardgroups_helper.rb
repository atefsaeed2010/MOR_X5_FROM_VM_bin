# -*- encoding : utf-8 -*-
module CardgroupsHelper
  def check_if_cg_owner(cg)
    (cg.lcr and ((reseller? and cg.lcr.user_id == current_user.id) or (admin? and cg.lcr.user_id == current_user.id)))
  end

  def b_cardgroup
    image_tag('icons/page_white_stack.png', :title => "") + " "
  end
end
