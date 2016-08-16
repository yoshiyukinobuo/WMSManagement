class Receipt < ApplicationRecord
  include Auditable

  STATUSES = %w[open completed].freeze

  belongs_to :site
  belongs_to :customer
  belongs_to :created_by, class_name: "User", optional: true
  has_many :receipt_lines, dependent: :restrict_with_error
  has_many_attached :slip_photos # FR-R6: photos of handwritten slips

  validates :arrival_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  def self.accessible_by(user) = where(site_id: user.accessible_site_ids)
  def site_id_for_access = site_id
  def completed? = status == "completed"
  def complete! = update!(status: "completed")
  def discrepancy? = receipt_lines.where("source_mismatch OR quantity_discrepancy").exists?
  def to_s = "入荷 ##{id}"
end
