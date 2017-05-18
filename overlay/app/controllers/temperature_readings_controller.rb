class TemperatureReadingsController < ApplicationController
  before_action -> { authorize!(:record_temperature) }, only: %i[new create new_correction create_correction]

  def index
    scope = TemperatureReading.accessible_by(Current.user).effective.includes(:sensor, zone: :site).order(measured_at: :desc)
    scope = scope.where(zone_id: params[:zone_id]) if params[:zone_id].present?
    scope = scope.where(measured_at: parse_time(params[:from], default: nil)..) if params[:from].present?
    scope = scope.where(measured_at: ..parse_time(params[:to], default: nil)) if params[:to].present?
    @readings, @page, @has_next = paginate(scope)
    @zones = Zone.accessible_by(Current.user).includes(:site).order(:site_id, :name)
  end

  # Round sheet: one value per zone of a site.
  def new
    @sites = accessible_sites
    @site = @sites.find_by(id: params[:site_id]) || @sites.first
    @zones = @site ? @site.zones.active.order(:name) : []
  end

  def create
    site = accessible_sites.find(params[:site_id])
    measured_at = parse_time(params[:measured_at])
    values = params.fetch(:values, {}).to_unsafe_h.reject { |_, v| v.blank? }
    saved = 0
    errors = []
    values.each do |zone_id, value|
      Temperature::ManualEntry.call(zone: site.zones.find(zone_id), measured_at: measured_at, value: value)
      saved += 1
    rescue WmsError, ActiveRecord::RecordInvalid => e
      errors << e.message
    end
    if errors.empty?
      redirect_to temperature_path, notice: "#{saved}件の測定値を登録しました。"
    else
      redirect_to new_temperature_reading_path(site_id: site.id), alert: "#{saved}件登録、エラー: #{errors.join(' / ')}"
    end
  end

  def new_correction
    @reading = find_reading
  end

  def create_correction
    reading = find_reading
    corrected = reading.correct!(value: params[:value], reason: params[:reason])
    Temperature::Detector.call(reading.zone, since: corrected.measured_at, via: "live")
    redirect_to temperature_readings_path(zone_id: reading.zone_id), notice: "訂正を登録しました(元の値は履歴として保持されます)。"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to correct_temperature_reading_path(reading), alert: e.message
  end

  private

  def find_reading = TemperatureReading.accessible_by(Current.user).effective.find(params[:id])
end
