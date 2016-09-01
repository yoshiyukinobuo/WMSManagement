class Shipment < ApplicationRecord
  include Auditable

  STATUSES = %w[draft shipped].freeze

  belongs_to :site
  belongs_to :customer
  belongs_to :created_by, class_name: "User", optional: true
  has_many :shipment_lines, dependent: :restrict_with_error

  validates :status, inclusion: { in: STATUSES }

  def self.accessible_by(user) = where(site_id: user.accessible_site_ids)
  def site_id_for_access = site_id
  def shipped? = status == "shipped"
  def all_picked? = shipment_lines.any? && shipment_lines.where(picked_at: nil).none?
  def to_s = "出荷 ##{id}"
end
