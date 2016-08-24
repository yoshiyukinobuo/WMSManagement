class Sensor < ApplicationRecord
  include Auditable

  SOURCE_TYPES = %w[manual csv api].freeze

  belongs_to :zone
  belongs_to :device_profile, optional: true
  has_many :temperature_readings, dependent: :restrict_with_error

  validates :name, presence: true
  validates :source_type, inclusion: { in: SOURCE_TYPES }

  scope :active, -> { where(active: true) }

  def self.accessible_by(user) = joins(:zone).where(zones: { site_id: user.accessible_site_ids })
  def site_id_for_access = zone&.site_id
  def to_s = "#{zone} #{name}"

  # Round-sheet entries are attached to one virtual "manual" sensor per zone.
  def self.manual_for(zone)
    find_or_create_by!(zone: zone, source_type: "manual") { |s| s.name = "手入力" }
  end
end
