require "test_helper"
require "support/builders"

class ReceivingFlowTest < ActionDispatch::IntegrationTest
  include Builders

  setup do
    @site = make_site
    @other_site = make_site
    @zone = make_zone(@site)
    @loc = make_location(@zone)
    @customer = make_customer
    @user = make_user(role: "floor_staff", sites: [@site])
  end

  def login(user)
    post session_path, params: { email_address: user.email_address, password: "password1234" }
  end

  test "requires login" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "receive a lot end to end and see it in stock" do
    login(@user)
    get root_path
    assert_response :success

    post receipts_path, params: { receipt: { site_id: @site.id, customer_id: @customer.id, arrival_at: Time.current.iso8601, vehicle: "秋田100", driver: "山田" } }
    receipt = Receipt.last
    assert_redirected_to receipt_path(receipt)

    post receipt_receipt_lines_path(receipt),
         params: { receipt_line: { lot_number: "A-1", received_quantity: 12, unit: "ケース", required_temperature_type: "frozen", location_id: @loc.id } },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    lot = Lot.find_by!(lot_number: "A-1")
    assert_equal 12, lot.total_quantity

    get stock_path
    assert_response :success
    assert_match lot.internal_id, response.body
  end

  test "cannot create a receipt for a site the user is not assigned to" do
    login(@user)
    post receipts_path, params: { receipt: { site_id: @other_site.id, customer_id: @customer.id, arrival_at: Time.current.iso8601 } }
    assert_response :forbidden
  end

  test "floor staff cannot decide excursions" do
    login(@user)
    patch excursion_lot_impact_path(0), params: { disposition: "release", comment: "x" }
    assert_response :forbidden
  end
end
