class ReceiptLine < ApplicationRecord
  include Auditable

  belongs_to :receipt
  belongs_to :lot, optional: true
  belongs_to :item, optional: true

  before_validation :reconcile_sources

  validates :lot_number, presence: { message: "(ロット番号・伝票・マニフェストのいずれか)を入力してください" }
  validates :received_quantity, numericality: { greater_than: 0 }
  validates :unit, presence: true
  validates :required_temperature_type, inclusion: { in: Zone::TYPES }, allow_blank: true

  scope :flagged, -> { where("source_mismatch OR quantity_discrepancy") }

  private

  # FR-R5: compare the three identification sources and FLAG disagreement instead of overwriting.
  # FR-R4: flag expected vs received quantity differences.
  def reconcile_sources
    given = [lot_number, slip_lot_number, manifest_lot_number].map { |v| v.to_s.strip.presence }.compact
    self.lot_number = given.first
    self.source_mismatch = given.uniq.size > 1
    self.quantity_discrepancy = expected_quantity.present? && received_quantity.present? && expected_quantity != received_quantity
  end
end
