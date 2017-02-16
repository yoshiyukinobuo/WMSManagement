class ExcursionLotImpactsController < ApplicationController
  before_action -> { authorize!(:decide_excursion) }

  def update
    impact = ExcursionLotImpact.joins(:excursion).where(excursions: { zone_id: Zone.accessible_by(Current.user).select(:id) }).find(params[:id])
    Excursions::Decide.call(impact: impact, disposition: params[:disposition], comment: params[:comment])
    redirect_to excursion_path(impact.excursion_id), notice: "判定を記録しました。"
  end
end
