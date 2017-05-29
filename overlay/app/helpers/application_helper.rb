module ApplicationHelper
  def fmt_time(time) = time&.in_time_zone&.strftime("%Y-%m-%d %H:%M")
  def fmt_date(date) = date&.strftime("%Y-%m-%d")

  def fmt_qty(qty)
    qty.nil? ? "" : number_with_precision(qty, precision: 3, strip_insignificant_zeros: true, delimiter: ",")
  end

  def enum_label(attr, value)
    value.blank? ? "" : I18n.t("wms.enums.#{attr}.#{value}", default: value.to_s)
  end

  def enum_options(attr, values) = values.map { |v| [enum_label(attr, v), v] }

  # Generic cell rendering for master-data tables.
  def display_value(record, attr)
    value = record.public_send(attr)
    case value
    when true then "○"
    when false then "−"
    when nil then ""
    when Time, ActiveSupport::TimeWithZone then fmt_time(value)
    when Date then fmt_date(value)
    when BigDecimal then fmt_qty(value)
    when String then enum_label(attr, value)
    else value.to_s
    end
  end

  def nav_items
    items = [["ダッシュボード", root_path], ["入荷", receipts_path], ["出荷", shipments_path], ["在庫", stock_path],
             ["棚卸", stocktakes_path], ["温度", temperature_path], ["逸脱", excursions_path], ["レポート", reports_path]]
    items
  end

  def master_links
    [["拠点", sites_path], ["ゾーン", zones_path], ["ロケーション", locations_path], ["荷主", customers_path],
     ["品目", items_path], ["センサー", sensors_path], ["デバイスプロファイル", device_profiles_path]]
  end

  def admin_links
    links = [["移動履歴", movements_path], ["取込", imports_path]]
    links << ["ユーザー", users_path] if can?(:manage_users)
    links << ["監査ログ", audit_logs_path] if can?(:view_audit)
    links
  end

  def lot_status_badge(lot)
    tone = { "available" => :green, "hold" => :amber, "shipped" => :slate, "discarded" => :red }[lot.status] || :slate
    badge(enum_label(:status, lot.status), tone)
  end
end
