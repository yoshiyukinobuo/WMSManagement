class SitesController < MasterCrudController
  private

  def model = Site
  def title = "拠点"
  def order = :code
  def columns = %i[code name address time_zone active]
  def permitted = %i[code name address time_zone active]
  def form_fields
    [{ name: :code }, { name: :name }, { name: :address }, { name: :time_zone }, { name: :active, as: :boolean }]
  end
end
