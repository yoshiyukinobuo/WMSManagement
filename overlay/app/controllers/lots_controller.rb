class LotsController < ApplicationController
  before_action -> { authorize!(:place_hold) }, only: %i[hold unhold]
  before_action :set_lot, only: %i[show hold unhold]

  def index
    scope = Lot.accessible_by(Current.user).includes(:customer, :site).order(created_at: :desc)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(site_id: params[:site_id]) if params[:site_id].present?
    if params[:q].present?
      q = "%#{Lot.sanitize_sql_like(params[:q])}%"
      scope = scope.where("lot_number ILIKE :q OR internal_id ILIKE :q", q: q)
    end
    @lots, @page, @has_next = paginate(scope)
  end

  def show
    @levels = StockLevel.where(lot_id: @lot.id).includes(location: { zone: :site })
    @movements = @lot.stock_movements.includes(:from_location, :to_location, :performed_by).order(:performed_at, :id)
    @impacts = @lot.excursion_impacts.includes(excursion: { zone: :site }).order(created_at: :desc)
    @segments = Temperature::LotHistory.call(@lot)
  end

  def hold
    @lot.hold!(reason: params[:reason].presence || "手動保留") or raise WmsError, "このロットは保留できません"
    redirect_to @lot, notice: "保留にしました。"
  end

  def unhold
    raise WmsError, "保留中のロットのみ解除できます" unless @lot.hold?
    raise WmsError, "温度逸脱の判定が未了のため解除できません" if @lot.excursion_impacts.where(disposition: "hold").exists?

    @lot.update!(status: "available", hold_reason: nil)
    redirect_to @lot, notice: "保留を解除しました。"
  end

  private

  def set_lot = @lot = Lot.accessible_by(Current.user).find(params[:id])
end
