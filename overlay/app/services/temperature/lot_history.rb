module Temperature
  # FR-T7: temperature history per lot = the readings of every zone the lot sat in, over the time it was there.
  class LotHistory
    Segment = Struct.new(:zone, :from, :to, :min, :max, :count, :excursions)

    def self.call(lot, now: Time.current)
      moves = lot.stock_movements.order(:performed_at, :id).to_a
      location_zone = Location.where(id: moves.flat_map { |m| [m.from_location_id, m.to_location_id] }.compact.uniq)
                              .includes(zone: :site).index_by(&:id).transform_values(&:zone)
      zones = location_zone.values.uniq

      segments = zones.flat_map do |zone|
        ids = location_zone.select { |_, z| z.id == zone.id }.keys
        Presence.intervals(moves, ids).map do |from, to|
          upto = to || now
          scope = zone.temperature_readings.effective.where(measured_at: from..upto)
          min, max, count = scope.pick(Arel.sql("MIN(value)"), Arel.sql("MAX(value)"), Arel.sql("COUNT(*)"))
          excursions = zone.excursions.where("started_at <= ? AND (ended_at IS NULL OR ended_at >= ?)", upto, from).to_a
          Segment.new(zone, from, to, min, max, count, excursions)
        end
      end
      segments.sort_by(&:from)
    end
  end
end
