class Stocktake < ApplicationRecord
  include Auditable

  STATUSES = %w[counting submitted approved].freeze

  belongs_to :site
  belongs_to :zone, optional: true
  belongs_to :started_by, class_name: "User", optional: true
  belongs_to :approved_by, class_name: "User", optional: true
  has_many :stocktake_lines, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }

  def self.accessible_by(user) = where(site_id: user.accessible_site_ids)
  def site_id_for_access = site_id
  def counting? = status == "counting"
  def submitted? = status == "submitted"
  def approved? = status == "approved"
  def to_s = "棚卸 ##{id}"
end
