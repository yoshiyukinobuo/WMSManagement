class StocktakeLinesController < ApplicationController
  before_action -> { authorize!(:operate_stock) }

  def update
    stocktake = Stocktake.accessible_by(Current.user).find(params[:stocktake_id])
    raise WmsError, "カウント中ではありません" unless stocktake.counting?

    @line = stocktake.stocktake_lines.find(params[:id])
    @line.update(counted_quantity: params.dig(:stocktake_line, :counted_quantity).presence)
    @stocktake = stocktake
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to stocktake }
    end
  end
end
