module Inventory
  # The ONLY place that writes stock movements. Stock quantity is never updated directly:
  # every change is an immutable StockMovement row, written under a row lock on the lot.
  class Ledger
    def self.available_at(lot, location)
      StockLevel.where(lot_id: lot.id, location_id: location.id).sum(:quantity)
    end

    def self.record!(lot:, type:, quantity:, from: nil, to: nil, reference: nil, note: nil, at: nil, import_batch: nil)
      qty = BigDecimal(quantity.to_s, exception: false)
      raise Error, "数量が不正です" if qty.nil? || qty <= 0

      lot.with_lock do
        if from && available_at(lot, from) < qty
          raise InsufficientStock, "ロケーション #{from.code} の在庫が不足しています(在庫 #{available_at(lot, from).to_s('F')})"
        end
        raise InsufficientStock, "未格納数量(#{lot.unplaced_quantity.to_s('F')})を超えています" if type == "putaway" && lot.unplaced_quantity < qty

        movement = StockMovement.create!(
          lot: lot, movement_type: type, quantity: qty, from_location: from, to_location: to,
          reference: reference, note: note, performed_at: at || Time.current, import_batch: import_batch
        )
        lot.update_columns(site_id: to.zone.site_id) if to && lot.site_id != to.zone.site_id
        movement
      end
    end
  end
end
