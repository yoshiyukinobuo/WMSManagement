module Inventory
  class Discard
    # Discard `quantity` from one location (partial discard keeps the lot alive).
    def self.call(lot:, location:, quantity:, note: nil)
      mv = Ledger.record!(lot: lot, type: "discard", quantity: quantity, from: location, note: note)
      lot.update!(status: "discarded") if lot.total_quantity.zero? && lot.unplaced_quantity.zero? && %w[available hold].include?(lot.status)
      mv
    end

    # Discard everything left of a lot (used by excursion decisions).
    def self.all!(lot:, note: nil)
      StockLevel.where(lot_id: lot.id).where("quantity > 0").each do |level|
        Ledger.record!(lot: lot, type: "discard", quantity: level.quantity, from: level.location, note: note)
      end
      lot.update!(status: "discarded", hold_reason: note)
    end
  end
end
