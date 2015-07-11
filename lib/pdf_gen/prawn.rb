class Prawn::Document
  include ApplicationHelper

  def text(string, options = {})
    string = fix_hebrew(string) if string.is_a?(String) and is_hebrew?(string)

    super
  end

  def draw_text(data, options)
    options = inspect_options_for_draw_text(options.dup)

    # dup because normalize_encoding changes the string
    data = data.to_s.dup
    data = fix_hebrew(data) if data.is_a?(String) and is_hebrew?(data)

    save_font do
      process_text_options(options)
      font.normalize_encoding!(data) unless @skip_encoding
      font_size(options[:size]) { draw_text!(data, options) }
    end
  end
end
