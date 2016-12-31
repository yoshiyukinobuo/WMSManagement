module Temperature
  # FR-T3 / design doc 7.3 + 9. Stateless and idempotent: re-scans the readings from `since`
  # (or from the start of any open excursion) and upserts excursions keyed by (zone, started_at).
  # Because it works over the time window the readings cover, late batch data (SD card / USB) is handled;
  # excursions found that way are marked detected_via = "import".
  #
  # Rule: a reading outside the alert limits starts a breach. It becomes an excursion once the breach has lasted
  # at least `tolerance_minutes` (0 = immediately). It closes after `close_after_in_range` consecutive
  # in-range readings; ended_at is the first of those readings.
  class Detector
    def self.call(zone, since:, via: "live") = new(zone, since, via).call

    def initialize(zone, since, via)
      @zone = zone
      @since = since
      @via = via
    end

    def call
      from = [@since, @zone.excursions.ongoing.minimum(:started_at)].compact.min
      return [] unless from

      readings = @zone.temperature_readings.effective.where(measured_at: from..).order(:measured_at, :id).pluck(:measured_at, :value)
      persist(scan(readings))
    end

    private

    def scan(readings)
      found = []
      active = nil   # confirmed excursion in progress
      pending = nil  # breach not yet long enough to count (tolerance)
      streak = 0
      recovery_at = nil

      readings.each do |at, value|
        if @zone.out_of_limits?(value)
          if active
            track_peak(active, value)
            streak = 0
            recovery_at = nil
          else
            pending ||= { started_at: at, breach_type: @zone.breach_type_for(value), peak_value: value, peak_dev: -1 }
            track_peak(pending, value)
            if (at - pending[:started_at]) >= @zone.tolerance_minutes * 60
              active = pending
              pending = nil
              streak = 0
              recovery_at = nil
            end
          end
        else
          pending = nil unless active
          next unless active

          recovery_at ||= at
          streak += 1
          if streak >= @zone.close_after_in_range
            found << active.merge(ended_at: recovery_at)
            active = nil
            streak = 0
            recovery_at = nil
          end
        end
      end
      found << active.merge(ended_at: nil) if active
      found
    end

    def track_peak(state, value)
      dev = @zone.deviation(value)
      return unless dev > state[:peak_dev].to_d

      state[:peak_dev] = dev
      state[:peak_value] = value
    end

    def persist(results)
      results.map do |r|
        excursion = @zone.excursions.find_or_initialize_by(started_at: r[:started_at])
        next excursion if excursion.persisted? && excursion.status == "closed" # decisions are kept; never rewrite

        is_new = excursion.new_record?
        excursion.assign_attributes(peak_value: r[:peak_value], breach_type: r[:breach_type], ended_at: r[:ended_at],
                                    status: r[:ended_at] ? "closed" : "open")
        if is_new
          excursion.detected_at = Time.current
          excursion.detected_via = @via
        end
        excursion.save!
        Excursions::ImpactRefresh.call(excursion)
        Alerts.excursion_opened(excursion) if is_new
        excursion
      end
    end
  end
end
