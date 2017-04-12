class SensorsController < MasterCrudController
  private

  def model = Sensor
  def title = "センサー"
  def ability = :manage_temperature_config
  def order = %i[zone_id name]
  def scope = super.includes(:zone, :device_profile)
  def columns = %i[zone name maker sensor_model source_type device_profile calibration_due_on active]
  def permitted = %i[zone_id device_profile_id name maker sensor_model external_id source_type calibration_due_on active]
  def form_fields
    [
      { name: :zone_id, as: :select, collection: zone_options },
      { name: :name }, { name: :maker }, { name: :sensor_model }, { name: :external_id },
      { name: :source_type, as: :select, collection: Sensor::SOURCE_TYPES.map { |t| [I18n.t("wms.enums.source_type.#{t}"), t] } },
      { name: :device_profile_id, as: :select, collection: DeviceProfile.order(:name).map { |d| [d.name, d.id] }, blank: true },
      { name: :calibration_due_on, as: :date },
      { name: :active, as: :boolean }
    ]
  end
end
