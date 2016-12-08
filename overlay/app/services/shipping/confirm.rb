module Shipping
  # FR-S4/S5: confirm shipment. Writes `ship` movements; refuses lots that went on hold since allocation.
  class Confirm
    def self.call(shipment:, vehicle:, driver:)
      shipment.with_lock do
        raise Inventory::Error, "すでに出荷済みです" if shipment.shipped?
        raise Inventory::Error, "明細がありません" if shipment.shipment_lines.empty?
        raise Inventory::Error, "ピッキングが完了していない明細があります" unless shipment.all_picked?
        raise Inventory::Error, "車両とドライバーを入力してください" if vehicle.blank? || driver.blank?

        shipment.shipment_lines.includes(:lot, :location).each do |line|
          unless line.lot.available?
            raise Inventory::Error, "ロット #{line.lot.internal_id} は保留中のため出荷できません"
          end

          Inventory::Ledger.record!(lot: line.lot, type: "ship", quantity: line.quantity, from: line.location, reference: shipment)
          line.lot.mark_shipped_if_empty!
        end
        shipment.update!(vehicle: vehicle, driver: driver, status: "shipped", shipped_at: Time.current)
      end
    end
  end
end
