module Stocktakes
  # FR-I4: snapshot current stock for a site (optionally one zone) as the count sheet.
  class Start
    def self.call(site:, zone: nil, user: Current.user, note: nil)
      ActiveRecord::Base.transaction do
        stocktake = Stocktake.create!(site: site, zone: zone, started_by: user, note: note)
        levels = StockLevel.joins(location: :zone).where(zones: { site_id: site.id }).where("stock_levels.quantity > 0")
        levels = levels.where(zones: { id: zone.id }) if zone
        levels.each do |level|
          stocktake.stocktake_lines.create!(lot_id: level.lot_id, location_id: level.location_id, system_quantity: level.quantity)
        end
        stocktake
      end
    end
  end
end
