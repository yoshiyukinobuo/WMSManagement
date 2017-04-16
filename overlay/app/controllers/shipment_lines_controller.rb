class ShipmentLinesController < ApplicationController
  before_action -> { authorize!(:operate_stock) }
  before_action :set_shipment

  # Manual allocation of a specific lot and location.
  def create
    raise WmsError, "出荷済みです" if @shipment.shipped?

    line = @shipment.shipment_lines.new(params.require(:shipment_line).permit(:lot_id, :location_id, :quantity))
    authorize_site!(line.location.zone.site_id) if line.location
    if line.save
      redirect_to @shipment, notice: "引当しました。"
    else
      redirect_to @shipment, alert: line.errors.full_messages.to_sentence
    end
  end

  # FIFO / FEFO allocation.
  def auto
    item = Item.find_by(id: params[:item_id]) if params[:item_id].present?
    lines = Shipping::Allocate.call(shipment: @shipment, quantity: params[:quantity], item: item,
                                    lot_number: params[:lot_number], rule: params[:rule].presence)
    redirect_to @shipment, notice: "#{lines.size}件を引当しました。"
  end

  def pick
    @shipment.shipment_lines.find(params[:id]).update!(picked_at: Time.current)
    redirect_to @shipment, notice: "ピッキング済みにしました。"
  end

  def destroy
    raise WmsError, "出荷済みです" if @shipment.shipped?

    @shipment.shipment_lines.find(params[:id]).destroy!
    redirect_to @shipment, notice: "引当を取り消しました。"
  end

  private

  def set_shipment = @shipment = Shipment.accessible_by(Current.user).find(params[:shipment_id])
end
