class TemperatureBoardController < ApplicationController
  def show
    @zones = Zone.accessible_by(Current.user).active.includes(:site).order(:site_id, :name)
    ids = @zones.map(&:id)
    @latest = TemperatureReading.effective.where(zone_id: ids).group(:zone_id).maximum(:measured_at)
    @open = Excursion.ongoing.where(zone_id: ids).index_by(&:zone_id)
  end
end
