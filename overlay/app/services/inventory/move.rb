module Inventory
  class Move
    def self.call(lot:, from:, to:, quantity:, force: false, note: nil)
      raise Error, "移動元と移動先が同じです" if from.id == to.id
      unless force || to.zone.satisfies?(lot.required_temperature_type)
        raise ZoneMismatch, "移動先 #{to.code} の温度帯はロットの要求温度帯を満たしません"
      end

      Ledger.record!(lot: lot, type: "move", quantity: quantity, from: from, to: to, note: note)
    end
  end
end
