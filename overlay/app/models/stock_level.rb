# Read-only model over the stock_levels SQL view (derived from the movement ledger).
class StockLevel < ApplicationRecord
  self.table_name = "stock_levels"
  self.primary_key = nil

  belongs_to :lot
  belongs_to :location

  def readonly? = true
end
