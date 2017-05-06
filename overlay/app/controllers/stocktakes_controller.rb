class StocktakesController < ApplicationController
  before_action -> { authorize!(:operate_stock) }, only: %i[new create submit]
  before_action -> { authorize!(:approve_stocktake) }, only: :approve
  before_action :set_stocktake, only: %i[show submit approve]

  def index
    @stocktakes, @page, @has_next = paginate(Stocktake.accessible_by(Current.user).includes(:site, :zone).order(created_at: :desc))
  end

  def new
    @sites = accessible_sites
    @zones = Zone.accessible_by(Current.user).includes(:site).order(:site_id, :name)
  end

  def create
    site = accessible_sites.find(params[:site_id])
    zone = site.zones.find(params[:zone_id]) if params[:zone_id].present?
    stocktake = Stocktakes::Start.call(site: site, zone: zone, note: params[:note])
    redirect_to stocktake, notice: "棚卸シートを作成しました(#{stocktake.stocktake_lines.count}件)。"
  end

  def show
    @lines = @stocktake.stocktake_lines.includes(:lot, location: { zone: :site }).sort_by { |l| [l.location.code, l.lot.internal_id] }
  end

  def submit
    raise WmsError, "カウント中の棚卸のみ提出できます" unless @stocktake.counting?
    raise WmsError, "未カウントの明細があります" if @stocktake.stocktake_lines.where(counted_quantity: nil).exists?

    @stocktake.update!(status: "submitted", submitted_at: Time.current)
    redirect_to @stocktake, notice: "提出しました。責任者の承認待ちです。"
  end

  def approve
    Stocktakes::Approve.call(stocktake: @stocktake)
    redirect_to @stocktake, notice: "承認し、差異を在庫に反映しました。"
  end

  private

  def set_stocktake = @stocktake = Stocktake.accessible_by(Current.user).find(params[:id])
end
