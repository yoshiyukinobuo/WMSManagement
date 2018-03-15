require "test_helper"
require "support/builders"

class ShippingTest < ActiveSupport::TestCase
  include Builders

  setup do
    @site = make_site
    @zone = make_zone(@site)
    @loc = make_location(@zone)
    @customer = make_customer
    @shipment = Shipment.create!(site: @site, customer: @customer)
  end

  test "FIFO allocates the oldest lot first, FEFO the earliest expiry" do
    old = make_lot(site: @site, customer: @customer, qty: 5, location: @loc, at: 10.days.ago)
    new = make_lot(site: @site, customer: @customer, qty: 5, location: @loc, at: 1.day.ago)
    old.update!(expires_on: 30.days.from_now)
    new.update!(expires_on: 5.days.from_now)

    lines = Shipping::Allocate.call(shipment: @shipment, quantity: 3, rule: "fifo")
    assert_equal [old.id], lines.map(&:lot_id)
    @shipment.shipment_lines.destroy_all

    lines = Shipping::Allocate.call(shipment: @shipment, quantity: 3, rule: "fefo")
    assert_equal [new.id], lines.map(&:lot_id)
  end

  test "allocation fails when stock is short and creates nothing" do
    make_lot(site: @site, customer: @customer, qty: 2, location: @loc)
    assert_raises(Inventory::InsufficientStock) { Shipping::Allocate.call(shipment: @shipment, quantity: 5) }
    assert_equal 0, @shipment.shipment_lines.count
  end

  test "stock promised to another order is not allocated twice" do
    make_lot(site: @site, customer: @customer, qty: 5, location: @loc)
    Shipping::Allocate.call(shipment: @shipment, quantity: 4)
    other = Shipment.create!(site: @site, customer: @customer)
    assert_raises(Inventory::InsufficientStock) { Shipping::Allocate.call(shipment: other, quantity: 3) }
  end

  test "held lots cannot be allocated or shipped" do
    lot = make_lot(site: @site, customer: @customer, qty: 5, location: @loc)
    Shipping::Allocate.call(shipment: @shipment, quantity: 2)
    lot.hold!(reason: "test")
    @shipment.shipment_lines.update_all(picked_at: Time.current)
    error = assert_raises(Inventory::Error) { Shipping::Confirm.call(shipment: @shipment, vehicle: "秋田100", driver: "山田") }
    assert_match(/保留/, error.message)
    assert_equal 5, lot.total_quantity
    other = Shipment.create!(site: @site, customer: @customer)
    assert_raises(Inventory::InsufficientStock) { Shipping::Allocate.call(shipment: other, quantity: 1) }
  end

  test "confirm writes ship movements and marks an emptied lot shipped" do
    lot = make_lot(site: @site, customer: @customer, qty: 5, location: @loc)
    Shipping::Allocate.call(shipment: @shipment, quantity: 5)
    assert_raises(Inventory::Error) { Shipping::Confirm.call(shipment: @shipment, vehicle: "v", driver: "d") } # not picked yet
    @shipment.shipment_lines.update_all(picked_at: Time.current)
    Shipping::Confirm.call(shipment: @shipment, vehicle: "秋田100", driver: "山田")
    assert @shipment.reload.shipped?
    assert_equal 0, lot.total_quantity
    assert_equal "shipped", lot.reload.status
  end
end
