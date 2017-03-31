class ReceiptsController < ApplicationController
  before_action -> { authorize!(:operate_stock) }, only: %i[new create complete attach_photos]
  before_action :set_receipt, only: %i[show complete attach_photos]

  def index
    scope = Receipt.accessible_by(Current.user).includes(:site, :customer).order(arrival_at: :desc)
    scope = scope.where(site_id: params[:site_id]) if params[:site_id].present?
    if params[:q].present?
      scope = scope.where("manifest_ref ILIKE :q OR vehicle ILIKE :q OR driver ILIKE :q", q: "%#{Receipt.sanitize_sql_like(params[:q])}%")
    end
    @receipts, @page, @has_next = paginate(scope)
  end

  def show
    @line = ReceiptLine.new
  end

  def new
    @receipt = Receipt.new(arrival_at: Time.current, site_id: accessible_sites.first&.id)
  end

  def create
    @receipt = Receipt.new(receipt_params.merge(created_by: Current.user))
    authorize_site!(@receipt.site_id) if @receipt.site_id.present?
    if @receipt.save
      redirect_to @receipt, notice: "入荷伝票を作成しました。ロットを登録してください。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def complete
    @receipt.complete!
    redirect_to @receipt, notice: @receipt.discrepancy? ? "入荷を完了しました。差異があるため責任者の確認が必要です。" : "入荷を完了しました。"
  end

  def attach_photos
    files = Array(params[:photos]).reject(&:blank?)
    @receipt.slip_photos.attach(files) if files.any?
    redirect_to @receipt, notice: "写真を追加しました。"
  end

  private

  def set_receipt = @receipt = Receipt.accessible_by(Current.user).find(params[:id])
  def receipt_params = params.require(:receipt).permit(:site_id, :customer_id, :arrival_at, :vehicle, :driver, :manifest_ref, :notes)
end
