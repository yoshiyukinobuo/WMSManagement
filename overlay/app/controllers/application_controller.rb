require "csv"

class ApplicationController < ActionController::Base
  # NOTE: allow_browser is intentionally NOT used: handheld terminals on the floor often run older browsers.
  include Authentication
  include Authorization

  before_action :ensure_active_user
  rescue_from WmsError, with: :handle_wms_error

  PER_PAGE = 50

  private

  def ensure_active_user
    return unless Current.user && !Current.user.active?

    terminate_session
    redirect_to new_session_path, alert: "このアカウントは無効です。"
  end

  def handle_wms_error(error)
    redirect_back fallback_location: root_path, alert: error.message
  end

  # Minimal offset pagination: fetch one extra row to know whether a next page exists.
  def paginate(relation)
    page = [params[:page].to_i, 1].max
    records = relation.offset((page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
    [records.first(PER_PAGE), page, records.size > PER_PAGE]
  end

  def accessible_site_ids
    @accessible_site_ids ||= Current.user.accessible_site_ids
  end

  def accessible_sites
    Site.accessible_by(Current.user).active.order(:code)
  end

  def parse_time(value, default: Time.current)
    return default if value.blank?

    Time.zone.parse(value.to_s) || default
  end

  # UTF-8 with BOM so Excel (Japanese locale) opens it correctly.
  def send_csv(filename, headers, rows)
    data = CSV.generate do |csv|
      csv << headers
      rows.each { |r| csv << r }
    end
    send_data "\uFEFF#{data}", filename: filename, type: "text/csv; charset=utf-8"
  end
end
