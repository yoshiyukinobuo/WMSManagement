module Inventory
  class Putaway
    # FR-R3: the location's zone must satisfy the lot's required temperature band.
    def self.call(lot:, location:, quantity:, force: false, reference: nil)
      unless force || location.zone.satisfies?(lot.required_temperature_type)
        raise ZoneMismatch, "ロケーション #{location.code}(#{I18n.t("wms.enums.zone_type.#{location.zone.zone_type}")})は" \
                            "ロットの要求温度帯(#{I18n.t("wms.enums.zone_type.#{lot.required_temperature_type}")})を満たしません"
      end

      Ledger.record!(lot: lot, type: "putaway", quantity: quantity, to: location, reference: reference)
    end
  end
end
