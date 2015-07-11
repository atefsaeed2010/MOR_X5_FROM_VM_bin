# -*- encoding : utf-8 -*-
# Represents logger for system administrator.
class Application

  def self.change_separators(options, separator)
    options.map do |key, value|
      value = value.to_s.try(:sub!, /[\,\.\;]/, separator)
    end
  end

  def self.nice_value(value)
    value = sprintf("%0.2f",value) if value.is_a?(BigDecimal)
    value.to_s.sub('.', ',')
  end

  def self.reset_user_warning_email_sent_status(user)
    user_balance = user.balance.to_d
    if user_balance > user.warning_email_balance.to_d
      user.warning_email_sent = 0
    end

    if user_balance > user.warning_email_balance_admin.to_d
      user.warning_email_sent_admin = 0
    end

    if user_balance > user.warning_email_balance_manager.to_d
      user.warning_email_sent_manager = 0
    end
    user.save
  end

  def self.nice_number(number, options = {})
    rezult = "0.00"
    number_decimal = number.to_d
    nice_number_digits = options[:nice_number_digits].to_i
    if nice_number_digits > 0
      rezult = sprintf("%0.#{nice_number_digits}f", number_decimal) if number
    else
      digits = Confline.get_value("Nice_Number_Digits").to_i
      digits = 2 if digits.zero?
      rezult = sprintf("%0.#{digits}f", number_decimal) if number
    end
    if options[:change_decimal]
      rezult = rezult.gsub('.', options[:global_decimal])
    end
    rezult
  end

  def self.valid_page_number(page_no, total_pages)
    #parameters:
    #  page_no - current page number, expected to be positive integer or 0 if total_pages is 0
    #  total_pages - expected to be not negative integer.
    #returns:
    #  page_no - validated page number, iteger, at least 1 or 0 if total pages is 0
    first_page = 1
    page_no = page_no.to_i
    page_no = first_page if page_no < first_page
    page_no = total_pages.to_i if total_pages < page_no

    return page_no
  end

  def self.query_limit(total_items, items_per_group, item_group_number)
    #parameters:s
    #  total_items - total items returned be query, extected to be not negative integer
    #  items_per_group - items that should be returned be query count, expected to be positive integer
    #  items_group_number - eg page number, expected to be at least 1 or 0 if total items 0
    #returns:
    #  offset - not negative integer, at least 1 or 0 if total items 0
    #  limit - not negative integer
    items_per_group = items_per_group.to_i
    offset = total_items < 1 ? 0 : items_per_group * (item_group_number -1)
    limit = items_per_group
    return offset, limit
  end

  def self.pages_validator(session, options, total, page = 1)
    options[:page] = options[:page].to_i < 1 ? 1 : options[:page].to_i
    total_pages = (total.to_d / session[:items_per_page].to_d).ceil
    options[:page] = total_pages if options[:page].to_i > total_pages.to_i and total_pages.to_i > 0
    fpage = ((options[:page] -1) * session[:items_per_page]).to_i
    return fpage, total_pages, options
  end

  def self.validate_date(year, month, day)
    good = 1
    year = year.to_i
    month = month.to_i
    day = day.to_i

    if (day == 31 && (month == 4 || month == 6 || month == 9 || month == 11)) || (month == 2 && day > 29) ||
      (year.remainder(4) != 0 && month == 2 && day == 29)
      good = 0
    end

    return good
  end

  def self.nice_unsigned_integer(value, max_value = nil)
    value = value.to_s.gsub(/[^0-9,.-]/, "").to_i
    value = value < 0 ? 0 : (value > 4294967295 ? 4294967295 : value)
    value = max_value.to_i if (max_value and max_value.to_i > 0 and value > max_value.to_i)

    return value
  end

  def self.nice_action_session_csv(params, session, correct_owner_id)
    action = params[:controller].to_s + "_" + params[:action].to_s
    options = session["import_csv_#{action}_options".to_sym] ? session["import_csv_#{action}_options".to_sym] : {}

    if params[:step].to_i > 1
      if params[:use_suggestion].to_i >= 1
        options[:sep] = params[:use_suggestion].to_i == 1 ? params[:sepn].to_s : params[:sepn2].to_s
        options[:dec] = params[:use_suggestion].to_i == 1 ? params[:decn].to_s : params[:decn2].to_s
      else
        if options[:sep].blank?
          confl_sep = Confline.get_value("CSV_Separator", ).to_s
          options[:sep] = confl_sep.blank? ? ',' : confl_sep.to_s
        else
          options[:sep] = options[:sep]
        end
        if options[:dec].blank?
          confl_dec = Confline.get_value("CSV_Decimal", correct_owner_id).to_s
          options[:dec] = confl_dec.blank? ? '.' : confl_dec.to_s
        else
          options[:dec] = options[:dec]
        end
      end
    else
      confl_sep = Confline.get_value("CSV_Separator", correct_owner_id).to_s
      confl_dec = Confline.get_value("CSV_Decimal", correct_owner_id).to_s
      options[:sep] = confl_sep.blank? ? ',' : confl_sep.to_s
      options[:dec] = confl_dec.blank? ? '.' : confl_dec.to_s
    end

    session["import_csv_#{action}_options".to_sym] = options
    return options[:sep].to_s, options[:dec].to_s
  end

  def self.items_per_page_count(session_items_per_page)
    items_per_page = session_items_per_page ? session_items_per_page.to_i : Confline.get_value("Items_Per_Page", 0).to_i
    # currently "items per page" default value is 1, user can only set it to at least 1
    items_per_page = 1 if items_per_page.to_i < 1

    return items_per_page, items_per_page
  end


  def self.common_use_provider(prov_id)
    common_use_prov = nil
    current_user = User.current
    if current_user.is_reseller? && current_user.can_own_providers?
      common_use_prov = CommonUseProvider.where( 'reseller_id = ? AND provider_id = ?', current_user.id, prov_id).first
    end
    common_use_prov
  end

  def self.seek_by_filter_sql(record, object_number, empty_click, livesearch)
    style = "width='177px' style='margin-left:20px;padding-left:6px;font-size:10px;font-weight: normal;'"
    output = []

    row = ->(id, text){ ["<tr><td id='" << id.to_s << "' #{style}>" << text << '</td></tr>'] }

    if livesearch.present?
      seek = record.limit(20).map { |user| row.call(user.id, user[:nice_user]) }

      output << [seek]
      if object_number > 20
        text = _('Found') + ' ' + (object_number - 20).to_s
        output << row.call(-2, text)
      elsif object_number == 0
        output << row.call(-2, _('No_value_found'))
      end
    end

    if empty_click == 'true'
      output << row.call(-2, _('Enter_value_here'))
    end

    return output.join
  end

  def self.find_like_user_sql(string)
    if string.present?
      name_cond = []
      name_cond << "users.username LIKE '#{string}%'"
      name_cond << "CONCAT(users.first_name, ' ', users.last_name) LIKE '#{string}%'"
      name_cond << "users.last_name LIKE '#{string}%'"
      like_user_sql = "AND (#{name_cond.join(' OR ')})"
    end
    like_user_sql.to_s
  end

  # for validating threshold values
  # def self.validate_routing_threshold_values(routing_thresholds, blacklist_lcrs, validate_with_letters)
  #   notice = nil
  #   err = 0
  #   routing_threshold = routing_thresholds[:routing_threshold]
  #   routing_threshold_2 = routing_thresholds[:routing_threshold_2]
  #   routing_threshold_3 = routing_thresholds[:routing_threshold_3]

  #   if validate_with_letters
  #     [routing_threshold, routing_threshold_2, routing_threshold_3].each do |threshold|
  #       if !threshold.blank? and not threshold.to_s =~ /^\d+$/
  #         notice = _('Threshold_should_be_a_number')
  #         err = 1
  #       end
  #     end
  #   end

  #   if err != 1
  #     routing_threshold_equal_to_zero = routing_threshold.to_i.zero?
  #     routing_threshold_2_equal_to_zero = routing_threshold_2.to_i.zero?
  #     routing_threshold_3_equal_to_zero = routing_threshold_3.to_i.zero?
  #     # check if all values are blank
  #     if (routing_threshold_equal_to_zero && routing_threshold_2_equal_to_zero && routing_threshold_3_equal_to_zero) ||
  #       # check if first values is blank and others are not
  #       (routing_threshold_equal_to_zero && ( !routing_threshold_2_equal_to_zero || !routing_threshold_3_equal_to_zero)) ||
  #       # check if second values is blank and the third one is not
  #       (routing_threshold_2_equal_to_zero && !routing_threshold_3_equal_to_zero) ||
  #       # check if second value is greater than the first one
  #       (( !routing_threshold_equal_to_zero && !routing_threshold_2_equal_to_zero) &&
  #         ((routing_threshold.to_i >= routing_threshold_2.to_i) ||
  #           # check if second value is greater than the third one
  #           ( !routing_threshold_3_equal_to_zero && (routing_threshold_2.to_i >= routing_threshold_3.to_i))))
  #         notice = _('Threshold_must_increase')
  #         err = 1
  #     end
  #   end

  #   return notice, err
  # end
end
