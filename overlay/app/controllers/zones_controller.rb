class ZonesController < MasterCrudController
  private

  def model = Zone
  def title = "温度帯(ゾーン)"
  def ability = :manage_temperature_config
  def order = %i[site_id name]
  def scope = super.includes(:site)
  def columns = %i[site name zone_type target_min target_max alert_min alert_max expected_interval_minutes active]
  def permitted
    %i[site_id name zone_type target_min target_max alert_min alert_max expected_interval_minutes
       tolerance_minutes close_after_in_range active]
  end

  def form_fields
    [
      { name: :site_id, as: :select, collection: site_options },
      { name: :name },
      { name: :zone_type, as: :select, collection: temperature_options },
      { name: :target_min, as: :number }, { name: :target_max, as: :number },
      { name: :alert_min, as: :number }, { name: :alert_max, as: :number },
      { name: :expected_interval_minutes, as: :integer },
      { name: :tolerance_minutes, as: :integer, hint: "この時間以上、範囲外が続いた場合のみ逸脱とする(0=即時)。運用・契約上の可否は要確認。" },
      { name: :close_after_in_range, as: :integer, hint: "逸脱を終了とみなす連続正常測定回数" },
      { name: :active, as: :boolean }
    ]
  end
end
