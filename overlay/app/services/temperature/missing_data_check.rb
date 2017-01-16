module Temperature
  # FR-T6: a zone with no reading within its expected interval raises ONE alert per gap.
  class MissingDataCheck
    def self.call(now: Time.current)
      Zone.active.includes(:site).find_each do |zone|
        next unless zone.missing_data?(now)

        last_alert = zone.missing_data_alerted_at
        next if last_alert && last_alert > (zone.last_reading_at || zone.created_at)

        Alerts.missing_data(zone)
        zone.update_columns(missing_data_alerted_at: now)
      end
    end
  end
end
