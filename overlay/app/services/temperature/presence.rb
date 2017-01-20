module Temperature
  # Works out when a lot was physically inside a set of locations, from its movement history.
  module Presence
    # moves: StockMovement rows for ONE lot ordered by time. Returns [[entered_at, left_at_or_nil], ...].
    def self.intervals(moves, location_ids)
      qty = BigDecimal("0")
      entered = nil
      result = []
      moves.each do |m|
        delta = (location_ids.include?(m.to_location_id) ? m.quantity : 0) -
                (location_ids.include?(m.from_location_id) ? m.quantity : 0)
        next if delta.zero?

        was_in = qty.positive?
        qty += delta
        is_in = qty.positive?
        if !was_in && is_in
          entered = m.performed_at
        elsif was_in && !is_in
          result << [entered, m.performed_at]
          entered = nil
        end
      end
      result << [entered, nil] if entered
      result
    end

    # Seconds of overlap between an interval and the window [from, to].
    def self.overlap_seconds(interval, from, to)
      start = [interval[0], from].max
      finish = [interval[1] || to, to].min
      [finish - start, 0].max
    end
  end
end
