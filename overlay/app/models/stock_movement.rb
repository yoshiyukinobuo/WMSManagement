# Append-only ledger. Current stock is derived from this table (see the stock_levels view).
class StockMovement < ApplicationRecord
  include AppendOnly

  TYPES = %w[receive putaway move pick ship adjust discard].freeze

  # Which location columns each movement type must / must not have.
  SHAPES = {
    "receive" => { from: false, to: false },
    "putaway" => { from: false, to: true },
    "move"    => { from: true,  to: true },
    "pick"    => { from: true,  to: false },
    "ship"    => { from: true,  to: false },
    "discard" => { from: true,  to: false }
  }.freeze

  belongs_to :lot
  belongs_to :from_location, class_name: "Location", optional: true
  belongs_to :to_location, class_name: "Location", optional: true
  belongs_to :performed_by, class_name: "User", optional: true
  belongs_to :reference, polymorphic: true, optional: true
  belongs_to :import_batch, optional: true

  before_validation :set_defaults

  validates :movement_type, inclusion: { in: TYPES }
  validates :quantity, numericality: { greater_than: 0 }
  validates :performed_at, presence: true
  validate :locations_match_type

  private

  def set_defaults
    self.performed_at ||= Time.current
    self.performed_by ||= Current.user
  end

  def locations_match_type
    if movement_type == "adjust"
      errors.add(:base, "調整は移動元か移動先のどちらか一方のみ指定します") if from_location.present? == to_location.present?
      return
    end
    shape = SHAPES[movement_type] or return
    errors.add(:from_location, "が不正です") if shape[:from] != from_location.present?
    errors.add(:to_location, "が不正です") if shape[:to] != to_location.present?
  end
end
