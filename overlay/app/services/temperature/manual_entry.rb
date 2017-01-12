module Temperature
  # FR-T2: manual (round sheet) entry. Feeds the same reading record as CSV and API sources.
  class ManualEntry
    def self.call(zone:, measured_at:, value:, user: Current.user)
      v = BigDecimal(value.to_s.tr(",", "."), exception: false)
      raise WmsError, "#{zone}: 数値を入力してください" if v.nil?

      reading = TemperatureReading.create!(
        zone: zone, sensor: Sensor.manual_for(zone), measured_at: measured_at.utc, value: v,
        source: "manual", recorded_by: user
      )
      Detector.call(zone, since: reading.measured_at, via: "live")
      reading
    rescue ActiveRecord::RecordNotUnique
      raise WmsError, "#{zone}: この時刻の測定値はすでに登録されています(修正する場合は訂正機能を使用してください)"
    end
  end
end
