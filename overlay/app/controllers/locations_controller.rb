class LocationsController < MasterCrudController
  private

  def model = Location
  def title = "ロケーション"
  def order = %i[zone_id code]
  def scope = super.includes(zone: :site)
  def columns = %i[zone code description active]
  def permitted = %i[zone_id code description active]
  def form_fields
    [{ name: :zone_id, as: :select, collection: zone_options }, { name: :code }, { name: :description }, { name: :active, as: :boolean }]
  end
end
