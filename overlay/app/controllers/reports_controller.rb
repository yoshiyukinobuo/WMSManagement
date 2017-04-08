class ReportsController < ApplicationController
  def index
    @sites = accessible_sites
    @zones = Zone.accessible_by(Current.user).includes(:site).order(:site_id, :name)
  end

  # FR-X1 / FR-I1: current stock.
  def stock
    levels = StockLevel.joins(location: :zone).where(zones: { site_id: accessible_site_ids })
                       .includes(lot: :customer, location: { zone: :site })
    send_csv("stock_#{Date.current}.csv",
             %w[拠点 ゾーン ロケーション 荷主 ロットID ロット番号 数量 状態 賞味期限],
             levels.map { |l| [l.location.zone.site.code, l.location.zone.name, l.location.code, l.lot.customer.name, l.lot.internal_id, l.lot.lot_number, l.quantity.to_s("F"), l.lot.status, l.lot.expires_on] })
  end

  # FR-X2: daily stock report per site (as of end of the chosen day).
  def daily_stock
    site = accessible_sites.find(params[:site_id])
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @site = site
    @date = date
    @rows = Inventory::StockAsOf.call(site_ids: [site.id], at: date.end_of_day)
    respond_to do |format|
      format.html
      format.csv do
        send_csv("daily_stock_#{site.code}_#{date}.csv", %w[ロケーション ロットID ロット番号 荷主 数量],
                 @rows.map { |r| [r.location.to_s, r.lot.internal_id, r.lot.lot_number, r.lot.customer.name, r.quantity.to_s("F")] })
      end
    end
  end

  def movements
    scope = StockMovement.joins(:lot).where(lots: { site_id: accessible_site_ids }).includes(:lot, :from_location, :to_location, :performed_by).order(:performed_at, :id)
    scope = scope.where(performed_at: parse_time(params[:from], default: nil)..) if params[:from].present?
    scope = scope.where(performed_at: ..parse_time(params[:to], default: nil)) if params[:to].present?
    send_csv("movements_#{Date.current}.csv", %w[日時 種別 ロットID ロット番号 移動元 移動先 数量 担当者 備考],
             scope.map { |m| [m.performed_at, I18n.t("wms.enums.movement_type.#{m.movement_type}"), m.lot.internal_id, m.lot.lot_number, m.from_location, m.to_location, m.quantity.to_s("F"), m.performed_by, m.note] })
  end

  # FR-T7: zone temperature log for audits and customers.
  def zone_log
    @zone = Zone.accessible_by(Current.user).find(params[:zone_id])
    from = parse_time(params[:from], default: 7.days.ago)
    to = parse_time(params[:to])
    @readings = @zone.temperature_readings.effective.includes(:sensor).where(measured_at: from..to).order(:measured_at)
    respond_to do |format|
      format.html { @readings = @readings.limit(2000).to_a; @from = from; @to = to }
      format.csv do
        send_csv("zone_log_#{@zone.name}_#{Date.current}.csv", %w[ゾーン センサー 測定日時 温度(℃) 取得方法],
                 @readings.map { |r| [@zone, r.sensor.name, r.measured_at.in_time_zone, r.value.to_s("F"), r.source] })
      end
    end
  end

  def excursion_history
    scope = Excursion.accessible_by(Current.user).includes(:zone).order(:started_at)
    scope = scope.where(started_at: parse_time(params[:from], default: nil)..) if params[:from].present?
    scope = scope.where(started_at: ..parse_time(params[:to], default: nil)) if params[:to].present?
    send_csv("excursions_#{Date.current}.csv", %w[ID ゾーン 開始 終了 ピーク値 検知方法 該当ロット数 状態],
             scope.map { |e| [e.id, e.zone, e.started_at.in_time_zone, e.ended_at&.in_time_zone, e.peak_value&.to_s("F"), I18n.t("wms.enums.detected_via.#{e.detected_via}"), e.lot_impacts.count, e.status] })
  end

  def lot_temperature
    lot = Lot.accessible_by(Current.user).find(params[:lot_id])
    segments = Temperature::LotHistory.call(lot)
    send_csv("lot_temperature_#{lot.internal_id}.csv", %w[ゾーン 開始 終了 最低℃ 最高℃ 測定数 逸脱],
             segments.map { |s| [s.zone, s.from.in_time_zone, s.to&.in_time_zone, s.min&.to_s("F"), s.max&.to_s("F"), s.count, s.excursions.map(&:id).join(" ")] })
  end
end
