class StockController < ApplicationController
  def index
    scope = StockLevel.joins(:lot, location: { zone: :site })
                      .where(zones: { site_id: accessible_site_ids })
                      .includes(lot: :customer, location: { zone: :site })
                      .order("sites.code, zones.name, locations.code, lots.received_on, lots.id")
    scope = scope.where(zones: { site_id: params[:site_id] }) if params[:site_id].present?
    scope = scope.where(zones: { id: params[:zone_id] }) if params[:zone_id].present?
    scope = scope.where("locations.code ILIKE ?", "#{Location.sanitize_sql_like(params[:location])}%") if params[:location].present?
    scope = scope.where(lots: { status: params[:status] }) if params[:status].present?
    scope = scope.where(lots: { received_on: params[:from].presence..params[:to].presence }) if params[:from].present? || params[:to].present?
    if params[:q].present?
      q = "%#{Lot.sanitize_sql_like(params[:q])}%"
      scope = scope.joins(lot: :customer).where("lots.lot_number ILIKE :q OR lots.internal_id ILIKE :q OR customers.name ILIKE :q OR customers.code ILIKE :q", q: q)
    end
    @levels, @page, @has_next = paginate(scope)
    @unplaced = Lot.accessible_by(Current.user).unplaced.includes(:customer).limit(20)
    @zones = Zone.accessible_by(Current.user).includes(:site).order(:site_id, :name)
  end
end
