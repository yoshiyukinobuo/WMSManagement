class AuditLogsController < ApplicationController
  before_action -> { authorize!(:view_audit) }

  def index
    scope = AuditLog.includes(:actor).order(occurred_at: :desc, id: :desc)
    scope = scope.where(entity_type: params[:entity_type]) if params[:entity_type].present?
    scope = scope.where(actor_id: params[:actor_id]) if params[:actor_id].present?
    scope = scope.where(entity_id: params[:entity_id]) if params[:entity_id].present?
    scope = scope.where(occurred_at: parse_time(params[:from], default: nil)..) if params[:from].present?
    @logs, @page, @has_next = paginate(scope)
    @entity_types = AuditLog.distinct.order(:entity_type).pluck(:entity_type)
  end
end
