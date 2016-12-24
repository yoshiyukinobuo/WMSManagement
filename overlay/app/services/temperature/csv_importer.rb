require "csv"

module Temperature
  # FR-T2: CSV import using a per-device mapping profile. Re-importing the same file is safe
  # (unique index on sensor + measured_at; duplicates are skipped and counted).
  class CsvImporter
    def self.call(batch:, sensor:, data:) = new(batch, sensor, data).call

    def initialize(batch, sensor, data)
      @batch = batch
      @sensor = sensor
      @data = data
    end

    def call
      profile = @sensor.device_profile or raise WmsError, "センサーにデバイスプロファイルが設定されていません"
      table = CSV.parse(normalize(@data, profile.encoding).lines.drop(profile.skip_lines).join,
                        headers: true, col_sep: profile.delimiter.presence || ",")
      zone = @sensor.zone
      tz = ActiveSupport::TimeZone[profile.time_zone] || Time.zone
      rows = []
      errors = []

      table.each.with_index(profile.skip_lines + 2) do |row, line_no|
        ts = row[profile.timestamp_column].to_s.strip
        val = row[profile.value_column].to_s.strip
        next if ts.empty? && val.empty?

        begin
          measured = tz.strptime(ts, profile.time_format)
          value = BigDecimal(val.tr(",", "."), exception: false)
          raise ArgumentError, "数値ではありません: #{val}" if value.nil?
        rescue ArgumentError, TypeError => e
          errors << { "row" => line_no, "message" => "#{e.message} (#{ts})" }
          next
        end
        rows << { zone_id: zone.id, sensor_id: @sensor.id, measured_at: measured.utc, value: value, source: "csv",
                  import_batch_id: @batch.id, created_at: Time.current }
      end

      inserted = 0
      rows.each_slice(1000) do |slice|
        inserted += TemperatureReading.insert_all(slice, unique_by: :idx_readings_sensor_time, returning: %w[id]).length
      end

      @batch.update!(status: "completed", total_rows: rows.size + errors.size, success_rows: inserted,
                     skipped_rows: rows.size - inserted, error_rows: errors.size, row_errors: errors.first(200),
                     committed_at: Time.current)
      Detector.call(zone, since: rows.map { |r| r[:measured_at] }.min, via: "import") if rows.any?
      @batch
    end

    private

    def normalize(data, encoding)
      text = data.dup.force_encoding(encoding.presence || "UTF-8")
      text = text.encode("UTF-8", invalid: :replace, undef: :replace) unless text.encoding == Encoding::UTF_8
      text.scrub.delete_prefix("\uFEFF")
    end
  end
end
