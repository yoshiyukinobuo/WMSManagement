# Role -> ability matrix (design doc section 5). Reading is open to every signed-in user (site-scoped);
# every write action maps to one of these abilities.
module Permissions
  ALL = %w[floor_staff site_supervisor quality office management system_admin].freeze

  MATRIX = {
    manage_master:            %w[office system_admin],
    manage_temperature_config: %w[quality site_supervisor office system_admin],
    operate_stock:            %w[floor_staff site_supervisor office system_admin],
    record_temperature:       %w[floor_staff site_supervisor quality system_admin],
    place_hold:               %w[site_supervisor quality system_admin],
    override_zone_mismatch:   %w[site_supervisor system_admin],
    decide_excursion:         %w[quality system_admin],
    approve_stocktake:        %w[site_supervisor system_admin],
    import_data:              %w[office system_admin],
    view_audit:               %w[quality system_admin],
    manage_users:             %w[system_admin]
  }.freeze

  def self.allow?(role, ability)
    MATRIX.fetch(ability.to_sym).include?(role.to_s)
  end
end
