class ReceiptLinesController < ApplicationController
  before_action -> { authorize!(:operate_stock) }
  before_action :set_receipt

  def create
    force = can?(:override_zone_mismatch) && params[:force] == "1"
    attrs = line_params.to_h
    begin
      Receiving::AddLine.call(receipt: @receipt, attrs: attrs, location: find_location(params.dig(:receipt_line, :location_id)), force: force)
      @line = ReceiptLine.new
      @message = "ロットを登録しました。"
      @error = nil
    rescue ActiveRecord::RecordInvalid => e
      @line = ReceiptLine.new(attrs)
      @error = e.record.errors.full_messages.to_sentence
    rescue WmsError => e
      @line = ReceiptLine.new(attrs)
      @error = e.message
    end
    respond_panel
  end

  def putaway
    line = @receipt.receipt_lines.find(params[:id])
    lot = line.lot
    force = can?(:override_zone_mismatch) && params[:force] == "1"
    location = find_location(params[:location_id]) or raise WmsError, "ロケーションを選択してください"
    Inventory::Putaway.call(lot: lot, location: location, quantity: lot.unplaced_quantity, force: force, reference: line)
    @line = ReceiptLine.new
    @message = "格納しました。"
    respond_panel
  rescue WmsError => e
    @line = ReceiptLine.new
    @error = e.message
    respond_panel
  end

  private

  def respond_panel
    respond_to do |format|
      format.turbo_stream { render :panel, status: (@error ? :unprocessable_entity : :ok) }
      format.html { redirect_to @receipt, @error ? { alert: @error } : { notice: @message } }
    end
  end

  def set_receipt = @receipt = Receipt.accessible_by(Current.user).find(params[:receipt_id])

  def find_location(id)
    return nil if id.blank?

    location = Location.accessible_by(Current.user).find(id)
    raise WmsError, "入荷先拠点以外のロケーションは指定できません" unless location.zone.site_id == @receipt.site_id

    location
  end

  def line_params
    params.require(:receipt_line).permit(:lot_number, :slip_lot_number, :manifest_lot_number, :item_id, :expected_quantity,
                                         :received_quantity, :unit, :required_temperature_type, :expires_on, :note)
  end
end
