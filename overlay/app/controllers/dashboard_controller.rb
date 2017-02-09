class DashboardController < ApplicationController
  def show
    site_ids = accessible_site_ids
    zones = Zone.active.where(site_id: site_ids).includes(:site)
    @open_excursions = Excursion.ongoing.where(zone_id: zones.select(:id)).includes(zone: :site).order(started_at: :desc)
    @pending_impacts = ExcursionLotImpact.where(disposition: "hold", excursion_id: Excursion.where(zone_id: zones.select(:id)).select(:id)).count
    @held_lots = Lot.where(site_id: site_ids, status: "hold").count
    @missing_zones = zones.select(&:missing_data?)
    @flagged_lines = ReceiptLine.flagged.joins(:receipt).where(receipts: { site_id: site_ids })
                                .where("receipt_lines.created_at > ?", 7.days.ago).includes(receipt: :site).order(created_at: :desc).limit(10)
    @unplaced = Lot.accessible_by(Current.user).unplaced.includes(:customer).limit(10)
    @recent_receipts = Receipt.where(site_id: site_ids).includes(:site, :customer).order(arrival_at: :desc).limit(5)
    @open_shipments = Shipment.where(site_id: site_ids, status: "draft").includes(:site, :customer).order(created_at: :desc).limit(5)
  end
end
