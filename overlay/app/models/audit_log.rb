class AuditLog < ApplicationRecord
  include AppendOnly

  belongs_to :actor, class_name: "User", optional: true

  def self.record!(action:, entity:, changeset: {})
    create!(actor_id: Current.user&.id, action: action, entity_type: entity.class.name,
            entity_id: entity.id, changeset: changeset, occurred_at: Time.current)
  end
end
