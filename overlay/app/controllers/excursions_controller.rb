class ExcursionsController < ApplicationController
  def index
    scope = Excursion.accessible_by(Current.user).includes(zone: :site).order(started_at: :desc)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(zone_id: params[:zone_id]) if params[:zone_id].present?
    @excursions, @page, @has_next = paginate(scope)
    @zones = Zone.accessible_by(Current.user).includes(:site).order(:site_id, :name)
  end

  def show
    @excursion = Excursion.accessible_by(Current.user).find(params[:id])
    @impacts = @excursion.lot_impacts.includes(lot: :customer).order(:id)
    @decisions = ExcursionDecision.where(excursion_lot_impact_id: @impacts.map(&:id)).includes(:decided_by).order(:created_at)
    @readings = @excursion.zone.temperature_readings.effective
                          .where(measured_at: (@excursion.started_at - 1.hour)..((@excursion.ended_at || Time.current) + 1.hour))
                          .order(:measured_at).limit(500)
  end
end
