# Idempotent seeds. Creates the first system admin and (outside production) a small demo data set.
admin_email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
admin = User.find_by(email_address: admin_email)
unless admin
  password = ENV["ADMIN_PASSWORD"].presence || SecureRandom.alphanumeric(16)
  User.create!(name: "システム管理者", email_address: admin_email, password: password, role: "system_admin")
  puts "Created admin #{admin_email} / password: #{password}  (change it after first login)"
end

unless Rails.env.production?
  # Demo master data only. Real sites, zones and limits must come from Yokoun staff (design doc section 16).
  site = Site.find_or_create_by!(code: "AKT-01") { |s| s.name = "秋田第1センター(デモ)"; s.address = "秋田県横手市" }
  frozen = site.zones.find_or_create_by!(name: "冷凍庫A") do |z|
    z.zone_type = "frozen"; z.target_max = -24; z.alert_max = -20; z.expected_interval_minutes = 60
  end
  chilled = site.zones.find_or_create_by!(name: "冷蔵庫A") do |z|
    z.zone_type = "chilled"; z.target_max = 5; z.alert_max = 7; z.alert_min = 0; z.expected_interval_minutes = 60
  end
  dry = site.zones.find_or_create_by!(name: "常温A") { |z| z.zone_type = "ambient"; z.expected_interval_minutes = 240 }
  frozen.locations.find_or_create_by!(code: "F-01-01")
  frozen.locations.find_or_create_by!(code: "F-01-02")
  chilled.locations.find_or_create_by!(code: "C-01-01")
  dry.locations.find_or_create_by!(code: "D-01-01")
  customer = Customer.find_or_create_by!(code: "C001") { |c| c.name = "デモ荷主" }
  customer.items.find_or_create_by!(code: "ICE-001") { |i| i.name = "冷凍食品A"; i.required_temperature_type = "frozen"; i.unit = "ケース" }
  Sensor.manual_for(frozen)
  Sensor.manual_for(chilled)
  DeviceProfile.find_or_create_by!(name: "汎用CSV(例)") do |d|
    d.timestamp_column = "Time"; d.value_column = "Temperature"; d.time_format = "%Y/%m/%d %H:%M"
  end
  User.find_by(email_address: admin_email)&.then { |u| u.update!(site_ids: Site.pluck(:id)) if u.site_ids.empty? }
end
