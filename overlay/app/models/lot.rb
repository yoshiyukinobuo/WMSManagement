class Lot < ApplicationRecord
  include Auditable

  STATUSES = %w[available hold shipped discarded].freeze
  ID_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ".chars.freeze # Crockford base32 (no I, L, O, U)

  belongs_to :customer
  belongs_to :item, optional: true
  belongs_to :site
  belongs_to :import_batch, optional: true
  has_many :stock_movements, dependent: :restrict_with_error
  has_many :excursion_impacts, class_name: "ExcursionLotImpact", dependent: :restrict_with_error

  before_validation :assign_internal_id, on: :create

  validates :internal_id, presence: true, uniqueness: true
  validates :lot_number, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :required_temperature_type, inclusion: { in: Zone::TYPES }, allow_blank: true

  # Lots whose received quantity has not been fully put away yet.
  scope :unplaced, lambda {
    where(id: StockMovement.where(movement_type: %w[receive putaway]).group(:lot_id)
      .having("SUM(CASE WHEN movement_type = 'receive' THEN quantity ELSE -quantity END) > 0").select(:lot_id))
  }

  def self.accessible_by(user) = where(site_id: user.accessible_site_ids)
  def site_id_for_access = site_id

  # Stable, unique, label-ready id (FR-B1). Encoded into a QR code in Phase 2.
  def self.generate_internal_id
    loop do
      candidate = "YK-" + Array.new(8) { ID_ALPHABET.sample }.join
      return candidate unless exists?(internal_id: candidate)
    end
  end

  def total_quantity
