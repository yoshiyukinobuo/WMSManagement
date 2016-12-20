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
