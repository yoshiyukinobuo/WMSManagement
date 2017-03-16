class MovementsController < ApplicationController
  before_action -> { authorize!(:operate_stock) }, only: %i[new create]

  def index
    scope = StockMovement.joins(:lot).where(lots: { site_id: accessible_site_ids })
                         .includes(:lot, :from_location, :to_location, :performed_by).order(performed_at: :desc, id: :desc)
    scope = scope.where(movement_type: params[:movement_type]) if params[:movement_type].present?
    scope = scope.where(lot_id: params[:lot_id]) if params[:lot_id].present?
    if params[:q].present?
      scope = scope.where("lots.lot_number ILIKE :q OR lots.internal_id ILIKE :q", q: "%#{Lot.sanitize_sql_like(params[:q])}%")
    end
    scope = scope.where(performed_at: parse_time(params[:from], default: nil)..) if params[:from].present?
    @movements, @page, @has_next = paginate(scope)
  end

  def new
    @lot = Lot.accessible_by(Current.user).find(params[:lot_id])
    @from = Location.accessible_by(Current.user).find(params[:from_location_id])
    @available = Inventory::Ledger.available_at(@lot, @from)
    @destinations = destination_options(@from)
  end

  def create
    lot = Lot.accessible_by(Current.user).find(params[:lot_id])
    from = Location.accessible_by(Current.user).find(params[:from_location_id])
    force = can?(:override_zone_mismatch) && params[:force] == "1"
    if params[:kind] == "discard"
      Inventory::Discard.call(lot: lot, location: from, quantity: params[:quantity], note: params[:note])
      redirect_to lot, notice: "廃棄を記録しました。"
    else
      to = Location.accessible_by(Current.user).find(params[:to_location_id])
      Inventory::Move.call(lot: lot, from: from, to: to, quantity: params[:quantity], force: force, note: params[:note])
      redirect_to lot, notice: "移動を記録しました。"
    end
  end

  private

  def destination_options(from)
    Location.accessible_by(Current.user).active.includes(zone: :site).order(:zone_id, :code).where.not(id: from.id)
  end
end
