class ImportBatch < ApplicationRecord
  include Auditable

  KINDS = %w[stock_opening temperature_csv].freeze
  STATUSES = %w[validated failed completed rolled_back].freeze

  belongs_to :uploaded_by, class_name: "User", optional: true
  belongs_to :site, optional: true
  belongs_to :sensor, optional: true
  has_one_attached :file

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  def self.accessible_by(user)
    where(site_id: user.accessible_site_ids).or(where(site_id: nil))
  end

  def stock_opening? = kind == "stock_opening"
  def to_s = "取込 ##{id}"
end
