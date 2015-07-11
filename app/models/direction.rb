# -*- encoding : utf-8 -*-
class Direction < ActiveRecord::Base
  attr_protected

  has_many :destinations, -> { order(:prefix) }, foreign_key: 'direction_code'

  validates_uniqueness_of :name, :message => _('Such_name_already')
  validates_uniqueness_of :code, :message => _('Such_code_already')
  validates_presence_of :name, :message => _('Name_cannot_be_empty')
  validates_presence_of :code, :message => _('Code_cannot_be_empty')

  def dest_count
    sql = "SELECT COUNT(*) FROM destinations WHERE direction_code = '#{self.code}'"
    ActiveRecord::Base.connection.select_value(sql)
  end

  def destroy_everything
    for dest in self.destinations
      dest.destroy
    end
    self.destroy
  end

  def Direction::get_direction_by_country(country)
    dir = Direction.where(name: country).first
    if dir
      return dir.id.to_i
    else
      return Confline.get_value("Default_Country_ID")
    end

  end

  def destinations_with_groups
    Destination.find_by_sql ["SELECT *,destinations.id as id, destinationgroups.id as dg_id, destinations.name as name, destinationgroups.name as dg_name FROM destinations LEFT JOIN destinationgroups ON destinations.destinationgroup_id = destinationgroups.id WHERE destinations.direction_code = ? ORDER BY destinations.prefix", code]
  end

  def Direction.name_by_prefix(prefix)

    if dest = Destination.select("directions.name").
        joins("LEFT JOIN directions ON (directions.code = destinations.direction_code)").
        where(["destinations.prefix = ?", prefix.to_s]).first
      dest["name"]
    else
      ""
    end
  end

  def Direction.get_calls_for_graph(options={})
    cond = []
    var = []

    cond << "calls.calldate BETWEEN ? AND ?"
    var += ["#{options[:a1]} 00:00:00", "#{options[:a2]} 23:23:59"]

    cond << 'directions.code = ?'; var << options[:code]
    if options[:destination]
      cond << 'destinations.prefix = ?'; var << options[:destination]
    end

    calls_all = Call.joins('LEFT JOIN destinations ON (destinations.prefix = calls.prefix) JOIN directions ON (directions.code = destinations.direction_code)').
        where([cond.join(' AND ').to_s] + var).count

    calls = Call.select("COUNT(*) AS 'calls', disposition , ((COUNT(*)/#{calls_all.size.to_i}) * 100) AS asr_c").
        joins('LEFT JOIN destinations ON (destinations.prefix = calls.prefix) JOIN directions ON (directions.code = destinations.direction_code)').
        where([cond.join(' AND ').to_s] + var).
        group('calls.disposition').
        order('calls.disposition ASC').all

    ca =[nil, nil, nil, nil]
    for c in calls
      case c.disposition
        when 'ANSWERED'
          ca[0] = c;
        when 'NO ANSWER'
          ca[1] = c;
        when 'BUSY'
          ca[2] = c;
        when 'FAILED'
          ca[3] = c;
      end
    end

    #===== Graph =====================

    calls_graph = "\""
    if calls_all and calls_all.to_d > 0
      calls_graph += _('ANSWERED') +";" + (ca[0] ? ca[0].calls : 0).to_s + ";" + "false" + "\\n"
      calls_graph += _('NO_ANSWER') +";" + (ca[1] ? ca[1].calls : 0).to_s + ";" + "false" + "\\n"
      calls_graph += _('BUSY') +";" + (ca[2] ? ca[2].calls : 0).to_s + ";" + "false" + "\\n"
      calls_graph += _('FAILED') +";" + (ca[3] ? ca[3].calls : 0).to_s + ";" + "false" + "\\n"
      calls_graph += "\""
    else
      calls_graph = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
    end

    return calls_all.to_i, calls_graph, *ca
  end

  def Direction.directions_order_by(params, options)
    case options[:order_by].to_s.strip
      when "name"
        order_by = " directions.name "
      when "code"
        order_by = " directions.code "
      else
        options[:order_by] ? order_by = "directions.name" : order_by = "directions.name"
    end
    order_by << " ASC" if options[:order_desc].to_i == 0 and order_by != ""
    order_by << " DESC" if options[:order_desc].to_i == 1 and order_by != ""
    return order_by

  end

end
