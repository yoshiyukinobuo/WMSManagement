module Inventory
  # Stock per lot and location at a point in time, rebuilt from the ledger (daily report FR-X2).
  class StockAsOf
    SQL = <<~SQL.freeze
      SELECT lot_id, location_id, SUM(delta) AS quantity FROM (
        SELECT lot_id, to_location_id AS location_id, quantity AS delta
          FROM stock_movements WHERE to_location_id IS NOT NULL AND performed_at <= :at
        UNION ALL
        SELECT lot_id, from_location_id AS location_id, -quantity AS delta
          FROM stock_movements WHERE from_location_id IS NOT NULL AND performed_at <= :at
      ) m GROUP BY lot_id, location_id HAVING SUM(delta) <> 0
    SQL

    Row = Struct.new(:lot, :location, :quantity)

    def self.call(site_ids:, at: Time.current)
      rows = ActiveRecord::Base.connection.select_all(ActiveRecord::Base.sanitize_sql_array([SQL, { at: at }])).to_a
      lots = Lot.includes(:customer).where(id: rows.map { |r| r["lot_id"] }).index_by(&:id)
      locations = Location.includes(zone: :site).where(id: rows.map { |r| r["location_id"] }).index_by(&:id)
      rows.filter_map do |r|
        loc = locations[r["location_id"]]
        next unless loc && site_ids.include?(loc.zone.site_id)

        Row.new(lots[r["lot_id"]], loc, BigDecimal(r["quantity"].to_s))
      end.sort_by { |r| [r.location.to_s, r.lot.internal_id] }
    end
  end
end
