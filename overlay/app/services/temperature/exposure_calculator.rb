module Temperature
  # THE key join (design doc section 8): which lots were stored in a zone during an excursion window,
  # computed from StockMovement history. Returns { lot_id => exposed_minutes }.
  class ExposureCalculator
    def self.call(zone:, from:, to:)
      location_ids = zone.locations.pluck(:id)
      return {} if location_ids.empty?

      moves = StockMovement.where(performed_at: ..to)
                           .where("to_location_id IN (:ids) OR from_location_id IN (:ids)", ids: location_ids)
                           .order(:performed_at, :id).group_by(&:lot_id)

      moves.each_with_object({}) do |(lot_id, lot_moves), result|
        seconds = Presence.intervals(lot_moves, location_ids).sum { |i| Presence.overlap_seconds(i, from, to) }
        result[lot_id] = (seconds / 60.0).round if seconds.positive?
      end
    end
  end
end
