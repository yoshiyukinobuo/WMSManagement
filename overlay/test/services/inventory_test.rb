require "test_helper"
require "support/builders"

class InventoryTest < ActiveSupport::TestCase
  include Builders

  setup do
    @site = make_site
    @frozen = make_zone(@site, type: "frozen")
    @chilled = make_zone(@site, type: "chilled", alert_max: 7)
    @f_loc = make_location(@frozen)
    @c_loc = make_location(@chilled)
    @customer = make_customer
  end

  test "stock is derived from the ledger" do
    lot = make_lot(site: @site, customer: @customer, qty: 10, location: @f_loc)
    assert_equal 10, StockLevel.where(lot_id: lot.id, location_id: @f_loc.id).sum(:quantity)
    Inventory::Ledger.record!(lot: lot, type: "ship", quantity: 4, from: @f_loc)
    assert_equal 6, lot.total_quantity
  end

  test "cannot remove more than is on hand" do
    lot = make_lot(site: @site, customer: @customer, qty: 5, location: @f_loc)
    assert_raises(Inventory::InsufficientStock) { Inventory::Ledger.record!(lot: lot, type: "ship", quantity: 6, from: @f_loc) }
  end

  test "movements are append-only" do
    lot = make_lot(site: @site, customer: @customer, location: @f_loc)
    movement = lot.stock_movements.first
    assert_raises(ActiveRecord::ReadOnlyRecord) { movement.update!(note: "edit") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { movement.destroy }
  end

  test "putaway into the wrong temperature zone is blocked unless forced" do
    lot = make_lot(site: @site, customer: @customer, type: "frozen", qty: 3)
    assert_raises(Inventory::ZoneMismatch) { Inventory::Putaway.call(lot: lot, location: @c_loc, quantity: 3) }
    Inventory::Putaway.call(lot: lot, location: @c_loc, quantity: 3, force: true)
    assert_equal 3, lot.total_quantity
  end

  test "putaway cannot exceed the unplaced quantity" do
    lot = make_lot(site: @site, customer: @customer, qty: 3)
    assert_equal 3, lot.unplaced_quantity
    assert_raises(Inventory::InsufficientStock) { Inventory::Putaway.call(lot: lot, location: @f_loc, quantity: 4) }
  end

  test "lot internal ids are unique and label-ready" do
    a = make_lot(site: @site, customer: @customer)
    b = make_lot(site: @site, customer: @customer)
    assert_match(/\AYK-[0-9A-Z]{8}\z/, a.internal_id)
    refute_equal a.internal_id, b.internal_id
  end

  test "receiving flags source mismatch and quantity discrepancy instead of overwriting" do
    receipt = Receipt.create!(site: @site, customer: @customer, arrival_at: Time.current)
    line = Receiving::AddLine.call(
      receipt: receipt, location: @f_loc,
      attrs: { lot_number: "A1", slip_lot_number: "A7", expected_quantity: 10, received_quantity: 9, unit: "個", required_temperature_type: "frozen" }
    )
    assert line.source_mismatch
    assert line.quantity_discrepancy
    assert_equal "A1", line.lot_number
    assert_equal 9, line.lot.total_quantity
    assert_equal 0, line.lot.unplaced_quantity
  end
end
