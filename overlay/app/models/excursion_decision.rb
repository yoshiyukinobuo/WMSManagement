# Append-only log of quality decisions. Decisions are never edited; a new decision supersedes the old one.
class ExcursionDecision < ApplicationRecord
  include Auditable
  include AppendOnly

  belongs_to :excursion_lot_impact
  belongs_to :decided_by, class_name: "User", optional: true

  validates :disposition, inclusion: { in: %w[release discard] }
  validates :comment, presence: true

  before_validation { self.decided_by ||= Current.user }
end
