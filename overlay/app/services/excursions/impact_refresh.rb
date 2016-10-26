module Excursions
  # Creates / updates one impact record per exposed lot and places newly exposed lots on hold.
  # Lots that already left before detection (late batch data) are recorded with already_left = true.
  class ImpactRefresh
    def self.call(excursion)
      window_end = excursion.ended_at || Time.current
      exposures = Temperature::ExposureCalculator.call(zone: excursion.zone, from: excursion.started_at, to: window_end)

      exposures.each do |lot_id, minutes|
        lot = Lot.find(lot_id)
        impact = excursion.lot_impacts.find_or_initialize_by(lot_id: lot_id)
        if impact.new_record?
          impact.disposition = "hold"
          impact.already_left = lot.total_quantity.zero?
        end
        impact.exposure_minutes = minutes
        impact.save!
        lot.hold!(reason: "温度逸脱 ##{excursion.id}") if impact.disposition == "hold" && !impact.already_left?
      end
    end
  end
end
