module Authorization
  extend ActiveSupport::Concern

  class NotAuthorized < StandardError; end

  included do
    rescue_from NotAuthorized, with: :render_forbidden
    helper_method :can?
  end

  private

  def can?(ability)
    Current.user&.can?(ability) || false
  end

  def authorize!(ability)
    raise NotAuthorized unless can?(ability)
  end

  def authorize_site!(site_id)
    raise NotAuthorized unless Current.user.accessible_site_ids.include?(site_id.to_i)
  end

  def render_forbidden
    render "shared/forbidden", status: :forbidden
  end
end
