class Zone < ApplicationRecord
  include Auditable

  TYPES = %w[frozen chilled constant ambient].freeze

  belongs_to :site
  has_many :locations, dependent: :restrict_with_error
  has_many :sensors, dependent: :restrict_with_error
  has_many :temperature_readings, dependent: :restrict_with_error
  has_many :excursions, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :site_id }
  validates :zone_type, inclusion: { in: TYPES }
  validates :expected_interval_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :tolerance_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :close_after_in_range, numericality: { only_integer: true, greater_than: 0 }
  validate :alert_limits_ordered

  scope :active, -> { where(active: true) }

  def self.accessible_by(user) = where(site_id: user.accessible_site_ids)
  def site_id_for_access = site_id
  def to_s = "#{site&.code}/#{name}"

  # A location in this zone can hold a lot that requires `required` (blank = any zone).
  def satisfies?(required)
    required.blank? || zone_type == required
  end

  def out_of_limits?(value)
    (alert_min.present? && value < alert_min) || (alert_max.present? && value > alert_max)
  end

  # How far outside the alert limits a value is (0 when inside).
  def deviation(value)
    return value - alert_max if alert_max.present? && value > alert_max
    return alert_min - value if alert_min.present? && value < alert_min

    0
  end

  def breach_type_for(value)
    (alert_max.present? && value > alert_max) ? "high" : "low"
  end

  def last_reading_at
    temperature_readings.effective.maximum(:measured_at)
  end

  # A silent sensor is a risk (FR-T6).
  def missing_data?(now = Time.current)
    reference = last_reading_at || created_at
    reference < now - expected_interval_minutes.minutes
  end

  def open_excursion
    excursions.find_by(status: "open")
  end

  private

  def alert_limits_ordered
    return if alert_min.blank? || alert_max.blank?

    errors.add(:alert_min, "は上限以下にしてください") if alert_min > alert_max
  end
end
