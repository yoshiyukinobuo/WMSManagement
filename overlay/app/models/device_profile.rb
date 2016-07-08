# Per-device-type CSV mapping (design doc section 9: source-agnostic readings, adapters per device).
class DeviceProfile < ApplicationRecord
  include Auditable

  ENCODINGS = %w[UTF-8 Shift_JIS Windows-31J].freeze

  has_many :sensors, dependent: :restrict_with_error

  validates :name, :timestamp_column, :value_column, :time_format, presence: true
  validates :skip_lines, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :encoding, inclusion: { in: ENCODINGS }
  validate :time_zone_known

  def to_s = name

  private

  def time_zone_known
    errors.add(:time_zone, :invalid) unless ActiveSupport::TimeZone[time_zone.to_s]
  end
end
