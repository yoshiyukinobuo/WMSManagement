require "test_helper"
require "support/builders"

class TemperatureTest < ActiveSupport::TestCase
  include Builders
  include ActionMailer::TestHelper

  setup do
    @site = make_site
    @zone = make_zone(@site, type: "frozen", alert_max: -20, close_after: 2)
    @loc = make_location(@zone)
    @customer = make_customer
    @t0 = Time.utc(2026, 10, 1, 0, 0)
  end

  def feed(values, start: @t0, step: 10.minutes)
    values.each_with_index { |v, i| add_reading(@zone, start + step * i, v) }
    Temperature::Detector.call(@zone, since: start)
  end

  test "out-of-range reading opens an excursion; consecutive in-range readings close it" do
    feed([-25, -19, -18, -25, -25])
    ex = @zone.excursions.first
    assert_equal 1, @zone.excursions.count
    assert_equal @t0 + 10.minutes, ex.started_at
    assert_equal @t0 + 30.minutes, ex.ended_at
    assert_equal(-18, ex.peak_value)
    assert_equal "closed", ex.status
  end

  test "excursion stays open until enough in-range readings arrive" do
    feed([-25, -19, -25])
    assert_equal "open", @zone.excursions.first.status
  end

  test "detection is idempotent" do
    feed([-25, -19, -18, -25, -25])
    assert_no_difference -> { Excursion.count } do
      Temperature::Detector.call(@zone, since: @t0)
      Temperature::Detector.call(@zone, since: @t0)
    end
  end

  test "tolerance suppresses short spikes" do
    zone = make_zone(@site, alert_max: -20, tolerance: 15, close_after: 1)
    [-25, -19, -25, -25].each_with_index { |v, i| add_reading(zone, @t0 + 10.minutes * i, v) }
    Temperature::Detector.call(zone, since: @t0)
    assert_equal 0, zone.excursions.count
  end

  test "exposed lots come from movement history overlapping the excursion window" do
    inside = make_lot(site: @site, customer: @customer, qty: 5, location: @loc, at: @t0 - 1.hour)
    arrives_later = make_lot(site: @site, customer: @customer, qty: 5, location: @loc, at: @t0 + 20.minutes)
    gone = make_lot(site: @site, customer: @customer, qty: 5, location: @loc, at: @t0 - 3.hours)
    Inventory::Ledger.record!(lot: gone, type: "ship", quantity: 5, from: @loc, at: @t0 - 1.hour)

    feed([-25, -19, -19, -19, -25, -25]) # excursion 00:10 .. 00:50

    impacts = @zone.excursions.first.lot_impacts.index_by(&:lot_id)
    assert impacts[inside.id], "lot present for the whole window is exposed"
    assert impacts[arrives_later.id], "lot arriving during the window is exposed"
    assert_nil impacts[gone.id], "lot that left before the window is not exposed"
    assert_equal "hold", inside.reload.status
    assert_operator impacts[inside.id].exposure_minutes, :>, impacts[arrives_later.id].exposure_minutes
  end

  test "late batch data marks the excursion as detected at import and flags lots that already left" do
    lot = make_lot(site: @site, customer: @customer, qty: 5, location: @loc, at: @t0 - 1.hour)
    Inventory::Ledger.record!(lot: lot, type: "ship", quantity: 5, from: @loc, at: @t0 + 1.hour)
    [-25, -19, -19, -25, -25].each_with_index { |v, i| add_reading(@zone, @t0 + 10.minutes * i, v) }
    Temperature::Detector.call(@zone, since: @t0, via: "import")
    ex = @zone.excursions.first
    assert ex.detected_at_import?
    assert ex.lot_impacts.find_by(lot_id: lot.id).already_left, "lot has no stock left at detection time"
  end

  test "release and discard decisions are logged; discard removes stock" do
    keep = make_lot(site: @site, customer: @customer, qty: 5, location: @loc, at: @t0 - 1.hour)
    toss = make_lot(site: @site, customer: @customer, qty: 5, location: @loc, at: @t0 - 1.hour)
    feed([-25, -19, -19, -25, -25])
    ex = @zone.excursions.first
    user = make_user(role: "quality")

    assert_raises(Inventory::Error) { Excursions::Decide.call(impact: ex.lot_impacts.find_by(lot_id: keep.id), disposition: "release", comment: "", user: user) }
    Excursions::Decide.call(impact: ex.lot_impacts.find_by(lot_id: keep.id), disposition: "release", comment: "品質確認済", user: user)
    Excursions::Decide.call(impact: ex.lot_impacts.find_by(lot_id: toss.id), disposition: "discard", comment: "規格外", user: user)

    assert_equal "available", keep.reload.status
    assert_equal "discarded", toss.reload.status
    assert_equal 0, toss.total_quantity
    assert_equal 2, ExcursionDecision.count
  end

  test "corrections supersede the original reading without editing it" do
    reading = add_reading(@zone, @t0, -10)
    corrected = reading.correct!(value: -25, reason: "入力ミス", user: make_user)
    effective = @zone.temperature_readings.effective
    assert_includes effective, corrected
    refute_includes effective, reading
    assert_equal(-10, reading.reload.value)
  end

  test "csv import maps columns, skips duplicates on re-import and reports bad rows" do
    profile = DeviceProfile.create!(name: "p", timestamp_column: "Time", value_column: "Temp", time_format: "%Y/%m/%d %H:%M")
    sensor = Sensor.create!(zone: @zone, name: "S", source_type: "csv", device_profile: profile)
    csv = "Time,Temp\n2026/10/01 09:00,-25.0\n2026/10/01 09:10,-18.5\nbad,xx\n"
    batch = ImportBatch.create!(kind: "temperature_csv", sensor: sensor)
    Temperature::CsvImporter.call(batch: batch, sensor: sensor, data: csv)
    assert_equal 2, batch.reload.success_rows
    assert_equal 1, batch.error_rows
    assert_equal Time.utc(2026, 10, 1, 0, 0), @zone.temperature_readings.order(:measured_at).first.measured_at.utc # JST -> UTC

    again = ImportBatch.create!(kind: "temperature_csv", sensor: sensor)
    Temperature::CsvImporter.call(batch: again, sensor: sensor, data: csv)
    assert_equal 0, again.reload.success_rows
    assert_equal 2, again.skipped_rows
    assert_equal 2, @zone.temperature_readings.count
  end

  test "missing data check alerts once per gap" do
    zone = make_zone(@site, interval: 60)
    zone.update_columns(created_at: 3.hours.ago)
    make_user(role: "quality", sites: [zone.site])
    assert_enqueued_emails(1) { Temperature::MissingDataCheck.call }
    assert_enqueued_emails(0) { Temperature::MissingDataCheck.call }
  end
end
