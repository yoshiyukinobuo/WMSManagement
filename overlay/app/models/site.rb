class Site < ApplicationRecord
  include Auditable

  has_many :zones, dependent: :restrict_with_error
  has_many :locations, through: :zones
  has_many :user_site_scopes, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validate :time_zone_known

  scope :active, -> { where(active: true) }

  def self.accessible_by(user) = where(id: user.accessible_site_ids)
  def site_id_for_access = id
  def to_s = "#{code} #{name}"

  private

  def time_zone_known
    errors.add(:time_zone, :invalid) unless ActiveSupport::TimeZone[time_zone.to_s]
  end
end
