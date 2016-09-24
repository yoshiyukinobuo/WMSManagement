class StocktakeLine < ApplicationRecord
  belongs_to :stocktake
  belongs_to :lot
  belongs_to :location

  validates :counted_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def variance
    counted_quantity.nil? ? nil : counted_quantity - system_quantity
  end
end
