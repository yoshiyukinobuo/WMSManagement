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
