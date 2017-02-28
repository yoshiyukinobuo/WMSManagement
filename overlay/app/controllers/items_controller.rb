class ItemsController < MasterCrudController
  private

  def model = Item
  def title = "品目"
  def order = %i[customer_id code]
  def scope = super.includes(:customer)
  def columns = %i[customer code name required_temperature_type unit]
  def permitted = %i[customer_id code name required_temperature_type unit]
  def form_fields
    [
      { name: :customer_id, as: :select, collection: customer_options },
      { name: :code }, { name: :name },
      { name: :required_temperature_type, as: :select, collection: temperature_options(:required_temperature_type), blank: true },
      { name: :unit }
    ]
  end
end
