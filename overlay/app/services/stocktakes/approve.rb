module Stocktakes
  # Approved variances become `adjust` movements, so the ledger stays the single source of truth.
  class Approve
    def self.call(stocktake:, user: Current.user)
      stocktake.with_lock do
        raise Inventory::Error, "提出済みの棚卸のみ承認できます" unless stocktake.submitted?

        stocktake.stocktake_lines.includes(:lot, :location).each do |line|
          current = Inventory::Ledger.available_at(line.lot, line.location)
          diff = line.counted_quantity - current
          next if diff.zero?

          if diff.positive?
            Inventory::Ledger.record!(lot: line.lot, type: "adjust", quantity: diff, to: line.location, reference: stocktake, note: "棚卸差異")
          else
            Inventory::Ledger.record!(lot: line.lot, type: "adjust", quantity: -diff, from: line.location, reference: stocktake, note: "棚卸差異")
          end
        end
        stocktake.update!(status: "approved", approved_by: user, approved_at: Time.current)
      end
    end
  end
end
