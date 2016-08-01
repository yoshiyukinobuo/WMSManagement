class Location < ApplicationRecord
  include Auditable

  belongs_to :zone
  has_one :site, through: :zone
  has_many :stock_movements_in, class_name: "StockMovement", foreign_key: :to_location_id, dependent: :restrict_with_error
  has_many :stock_movements_out, class_name: "StockMovement", foreign_key: :from_location_id, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: { scope: :zone_id }
  validate :code_unique_within_site

  scope :active, -> { where(active: true) }

  def self.accessible_by(user) = joins(:zone).where(zones: { site_id: user.accessible_site_ids })
  def site_id_for_access = zone&.site_id
  def to_s = "#{zone&.site&.code}/#{zone&.name}/#{code}"

  private

  def code_unique_within_site
    return unless zone

    clash = Location.joins(:zone).where(zones: { site_id: zone.site_id }, code: code).where.not(id: id).exists?
    errors.add(:code, :taken) if clash
  end
end
