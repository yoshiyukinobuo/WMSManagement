# Keep background jobs (alert mails) inline-testable and out of real threads.
ActiveJob::Base.queue_adapter = :test

module Builders
  def next_seq = (@@seq = (defined?(@@seq) ? @@seq : 0) + 1)

  def make_user(role: "system_admin", sites: [])
    n = next_seq
    user = User.create!(name: "テスト#{n}", email_address: "t#{n}@example.com", password: "password1234", role: role)
    user.update!(site_ids: sites.map(&:id)) if sites.any?
    user
  end

  def make_site(code: nil)
    Site.create!(code: code || "S#{next_seq}", name: "拠点")
  end

  def make_zone(site, type: "frozen", alert_max: -20, alert_min: nil, tolerance: 0, close_after: 2, interval: 60)
    Zone.create!(site: site, name: "Z#{next_seq}", zone_type: type, alert_max: alert_max, alert_min: alert_min,
                 tolerance_minutes: tolerance, close_after_in_range: close_after, expected_interval_minutes: interval)
  end

  def make_location(zone)
    Location.create!(zone: zone, code: "L#{next_seq}")
  end

  def make_customer
    Customer.create!(code: "C#{next_seq}", name: "荷主")
  end

  def make_lot(site:, customer:, type: "frozen", qty: 10, location: nil, at: Time.current)
    lot = Lot.create!(site: site, customer: customer, lot_number: "LOT#{next_seq}", required_temperature_type: type, received_on: at.to_date)
    Inventory::Ledger.record!(lot: lot, type: "receive", quantity: qty, at: at)
    Inventory::Ledger.record!(lot: lot, type: "putaway", quantity: qty, to: location, at: at) if location
    lot
  end

  def add_reading(zone, time, value, sensor: nil)
    TemperatureReading.create!(zone: zone, sensor: sensor || Sensor.manual_for(zone), measured_at: time, value: value, source: "manual")
  end
end
