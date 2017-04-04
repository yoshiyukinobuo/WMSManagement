class ReportsController < ApplicationController
  def index
    @sites = accessible_sites
    @zones = Zone.accessible_by(Current.user).includes(:site).order(:site_id, :name)
  end

  # FR-X1 / FR-I1: current stock.
  def stock
    levels = StockLevel.joins(location: :zone).where(zones: { site_id: accessible_site_ids })
                       .includes(lot: :customer, location: { zone: :site })
    send_csv("stock_#{Date.current}.csv",
             %w[拠点 ゾーン ロケーション 荷主 ロットID ロット番号 数量 状態 賞味期限],
             levels.map { |l| [l.location.zone.site.code, l.location.zone.name, l.location.code, l.lot.customer.name, l.lot.internal_id, l.lot.lot_number, l.quantity.to_s("F"), l.lot.status, l.lot.expires_on] })
  end

  # FR-X2: daily stock report per site (as of end of the chosen day).
  def daily_stock
    site = accessible_sites.find(params[:site_id])
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @site = site
    @date = date
    @rows = Inventory::StockAsOf.call(site_ids: [site.id], at: date.end_of_day)
    respond_to do |format|
      format.html
      format.csv do
        send_csv("daily_stock_#{site.code}_#{date}.csv", %w[ロケーション ロットID ロット番号 荷主 数量],
                 @rows.map { |r| [r.location.to_s, r.lot.internal_id, r.lot.lot_number, r.lot.customer.name, r.quantity.to_s("F")] })
      end
    end
  end

  def movements
    scope = StockMovement.joins(:lot).where(lots: { site_id: accessible_site_ids }).includes(:lot, :from_location, :to_location, :performed_by).order(:performed_at, :id)
    scope = scope.where(performed_at: parse_time(params[:from], default: nil)..) if params[:from].present?
