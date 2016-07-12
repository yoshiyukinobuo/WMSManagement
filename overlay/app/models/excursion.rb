class Excursion < ApplicationRecord
  include Auditable

  belongs_to :zone
  has_many :lot_impacts, class_name: "ExcursionLotImpact", dependent: :restrict_with_error

  validates :started_at, presence: true
  validates :status, inclusion: { in: %w[open closed] }

  scope :ongoing, -> { where(status: "open") }

  def self.accessible_by(user) = where(zone_id: Zone.accessible_by(user).select(:id))
  def site_id_for_access = zone&.site_id
  def open? = status == "open"
  def detected_at_import? = detected_via == "import"

  def duration_minutes
    (((ended_at || Time.current) - started_at) / 60).round
  end

  def to_s = "逸脱 ##{id}"
end
