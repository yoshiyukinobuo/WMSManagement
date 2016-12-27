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
