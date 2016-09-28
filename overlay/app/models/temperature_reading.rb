class TemperatureReading < ApplicationRecord
  include Auditable
  include AppendOnly

  SOURCES = %w[manual csv api].freeze

  belongs_to :zone
  belongs_to :sensor
  belongs_to :import_batch, optional: true
  belongs_to :recorded_by, class_name: "User", optional: true
  belongs_to :corrects, class_name: "TemperatureReading", optional: true

  validates :measured_at, presence: true
  validates :value, numericality: true
  validates :source, inclusion: { in: SOURCES }
  validates :correction_reason, presence: true, if: :corrects_id?

  # Readings are never edited: a correction is a new row pointing at the original.
  # "Effective" = every reading that has not itself been superseded by a correction.
  scope :effective, lambda {
    where.not(id: TemperatureReading.where.not(corrects_id: nil).select(:corrects_id))
  }

  def self.accessible_by(user) = where(zone_id: Zone.accessible_by(user).select(:id))

  def correct!(value:, reason:, user: Current.user)
    self.class.create!(zone: zone, sensor: sensor, measured_at: measured_at, value: value, source: source,
                       recorded_by: user, corrects: self, correction_reason: reason)
  end
end
