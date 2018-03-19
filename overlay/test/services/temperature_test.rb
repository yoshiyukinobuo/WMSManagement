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
