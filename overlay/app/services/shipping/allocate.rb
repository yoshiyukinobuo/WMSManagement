module Shipping
  # FR-S2: allocate stock to an order by FIFO or FEFO. Held lots and stock already promised to other orders are skipped.
  class Allocate
    def self.call(shipment:, quantity:, item: nil, lot_number: nil, rule: nil)
      rule ||= Rails.configuration.x.allocation_rule
      needed = BigDecimal(quantity.to_s, exception: false)
      raise Inventory::Error, "数量が不正です" if needed.nil? || needed <= 0
      raise Inventory::Error, "出荷済みの出荷指示には追加できません" if shipment.shipped?

      candidates(shipment, item, lot_number, rule).then do |rows|
        created = []
        ActiveRecord::Base.transaction do
          rows.each do |row|
            break if needed <= 0

            free = row.quantity - ShipmentLine.reserved(row.lot_id, row.location_id)
            take = [free, needed].min
            next unless take.positive?

            created << shipment.shipment_lines.create!(lot_id: row.lot_id, location_id: row.location_id, quantity: take)
            needed -= take
          end
          raise Inventory::InsufficientStock, "在庫が不足しています(不足 #{needed.to_s('F')})" if needed.positive?
        end
        created
      end
    end

    def self.candidates(shipment, item, lot_number, rule)
      rows = StockLevel.joins(:lot, location: :zone)
                       .where(lots: { customer_id: shipment.customer_id, status: "available" },
                              zones: { site_id: shipment.site_id })
                       .where("stock_levels.quantity > 0")
      rows = rows.where(lots: { item_id: item.id }) if item
      rows = rows.where("lots.lot_number ILIKE ?", "#{ActiveRecord::Base.sanitize_sql_like(lot_number)}%") if lot_number.present?
      order = if rule.to_s == "fefo"
                "lots.expires_on ASC NULLS LAST, lots.received_on ASC, lots.id ASC"
              else
                "lots.received_on ASC, lots.id ASC"
              end
      rows.order(Arel.sql(order)).select("stock_levels.lot_id, stock_levels.location_id, stock_levels.quantity").to_a
    end
    private_class_method :candidates
  end
end
