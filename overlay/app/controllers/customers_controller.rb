class CustomersController < MasterCrudController
  private

  def model = Customer
  def title = "荷主"
  def order = :code
  def columns = %i[code name active]
  def permitted = %i[code name active]
  def form_fields = [{ name: :code }, { name: :name }, { name: :active, as: :boolean }]
end
