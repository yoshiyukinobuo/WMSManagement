class ReadingImportsController < ApplicationController
  before_action -> { authorize!(:record_temperature) }

  def new
    @sensors = Sensor.accessible_by(Current.user).active.where(source_type: "csv").includes(:zone, :device_profile).order(:zone_id, :name)
  end

  def create
    sensor = Sensor.accessible_by(Current.user).find(params[:sensor_id])
    file = params[:file] or raise WmsError, "ファイルを選択してください"
    batch = ImportBatch.create!(kind: "temperature_csv", filename: file.original_filename, sensor: sensor,
                                site_id: sensor.zone.site_id, uploaded_by: Current.user)
    batch.file.attach(file)
    Temperature::CsvImporter.call(batch: batch, sensor: sensor, data: batch.file.download)
    redirect_to import_path(batch), notice: "取り込みました。"
  end
end
