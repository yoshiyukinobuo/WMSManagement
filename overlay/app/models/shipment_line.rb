class ShipmentLine < ApplicationRecord
  include Auditable

  belongs_to :shipment
  belongs_to :lot
  belongs_to :location

  validates :quantity, numericality: { greater_than: 0 }
  validate :lot_not_on_hold, on: :create
  validate :enough_free_stock, on: :create

  # Quantity already promised to other unshipped orders for the same lot and location.
  def self.reserved(lot_id, location_id)
    joins(:shipment).where(lot_id: lot_id, location_id: location_id).where.not(shipments: { status: "shipped" }).sum(:quantity)
  end

  def picked? = picked_at.present?

  private

  # FR-S5: held lots can never be allocated.
  def lot_not_on_hold
    errors.add(:lot, "は保留中または出荷不可のため引当できません") unless lot&.available?
  end

  def enough_free_stock
    return unless lot && location && quantity

    on_hand = StockLevel.where(lot_id: lot_id, location_id: location_id).sum(:quantity)
    free = on_hand - self.class.reserved(lot_id, location_id)
    errors.add(:quantity, "が引当可能数量(#{free.to_s('F')})を超えています") if quantity > free
  end
end
