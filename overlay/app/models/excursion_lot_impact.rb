class ExcursionLotImpact < ApplicationRecord
  include Auditable

  DISPOSITIONS = %w[hold release discard].freeze

  belongs_to :excursion
  belongs_to :lot
  belongs_to :decided_by, class_name: "User", optional: true
  has_many :decisions, class_name: "ExcursionDecision", dependent: :restrict_with_error

  validates :disposition, inclusion: { in: DISPOSITIONS }

  def decided? = disposition != "hold"
end
