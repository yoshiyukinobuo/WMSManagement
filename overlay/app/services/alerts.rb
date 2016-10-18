# FR-T4: alerts by email first (other channels later).
module Alerts
  module_function

  ROLES = %w[quality site_supervisor system_admin].freeze

  def recipients_for(site)
    User.where(active: true, role: ROLES).select { |u| u.accessible_site_ids.include?(site.id) }
  end

  def excursion_opened(excursion)
    recipients_for(excursion.zone.site).each { |u| AlertMailer.excursion_opened(u, excursion).deliver_later }
  end

  def missing_data(zone)
    recipients_for(zone.site).each { |u| AlertMailer.missing_data(u, zone).deliver_later }
  end
end
