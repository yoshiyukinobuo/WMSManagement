# Writes an AuditLog row (who / what / before-after / when) for every create, update and destroy.
module Auditable
  extend ActiveSupport::Concern

  SENSITIVE = %w[password_digest].freeze

  included do
    after_create  { write_audit("create", saved_changes) }
    after_update  { write_audit("update", saved_changes.except("updated_at")) }
    after_destroy { write_audit("destroy", attributes) }
  end

  private

  def write_audit(action, changes)
    return if changes.blank?

    AuditLog.create!(
      actor_id: Current.user&.id,
      action: action,
      entity_type: self.class.name,
      entity_id: id,
      changeset: changes.except(*SENSITIVE),
      occurred_at: Time.current
    )
  end
end
