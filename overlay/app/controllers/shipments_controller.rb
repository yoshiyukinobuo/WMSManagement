class ShipmentsController < ApplicationController
  before_action -> { authorize!(:operate_stock) }, only: %i[new create ship]
  before_action :set_shipment, only: %i[show ship]

  def index
    scope = Shipment.accessible_by(Current.user).includes(:site, :customer).order(created_at: :desc)
    scope = scope.where(status: params[:status]) if params[:status].present?
    @shipments, @page, @has_next = paginate(scope)
  end

  def show
    @lines = @shipment.shipment_lines.includes(:lot, location: { zone: :site }).sort_by { |l| l.location.code }
    @items = Item.where(customer_id: @shipment.customer_id).order(:code)
  end

  def new
    @shipment = Shipment.new(site_id: accessible_sites.first&.id)
  end

  def create
    @shipment = Shipment.new(shipment_params.merge(created_by: Current.user))
    authorize_site!(@shipment.site_id) if @shipment.site_id.present?
    if @shipment.save
      redirect_to @shipment, notice: "出荷指示を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def ship
    Shipping::Confirm.call(shipment: @shipment, vehicle: params[:vehicle], driver: params[:driver])
    redirect_to @shipment, notice: "出荷を確定しました。"
  end

  private

  def set_shipment = @shipment = Shipment.accessible_by(Current.user).find(params[:id])
  def shipment_params = params.require(:shipment).permit(:site_id, :customer_id, :destination, :reference)
end
