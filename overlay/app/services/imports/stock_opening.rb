require "csv"

module Imports
  # FR-A3 / design doc section 12: Excel (.xlsx) or CSV import for opening stock.
  # Two steps: `validate!` parses and checks every row (nothing is written), `commit!` loads the lots as
  # receive + putaway movements tagged with the batch id, so a bad load can be rolled back cleanly.
  class StockOpening
    HEADERS = {
      site_code: %w[site_code 拠点コード 拠点],
      customer_code: %w[customer_code 荷主コード 荷主],
      item_code: %w[item_code 品目コード 商品コード],
      lot_number: %w[lot_number ロット番号 ロットno ロット],
      location_code: %w[location_code ロケーション ロケーションコード 棚番],
      quantity: %w[quantity 数量],
      unit: %w[unit 単位],
      required_temperature_type: %w[required_temperature_type 温度帯],
      received_on: %w[received_on 入荷日],
      expires_on: %w[expires_on 賞味期限 期限]
    }.freeze

    TEMPERATURE_ALIASES = {
      "frozen" => "frozen", "冷凍" => "frozen", "chilled" => "chilled", "冷蔵" => "chilled",
      "constant" => "constant", "定温" => "constant", "ambient" => "ambient", "常温" => "ambient"
    }.freeze

    def self.validate!(batch, user:)
      table = read_table(batch)
      errors = []
      payload = []
      headers = map_headers(table.first || [])
      missing = %i[site_code customer_code lot_number location_code quantity] - headers.values
      if missing.any?
        errors << { "row" => 1, "message" => "必須列がありません: #{missing.join(', ')}" }
      else
        allowed_sites = Site.accessible_by(user).index_by(&:code)
        table.drop(1).each_with_index do |raw, idx|
          line = idx + 2
          next if raw.compact.all? { |c| c.to_s.strip.empty? }

          row = headers.each_with_object({}) { |(col, key), h| h[key] = raw[col].to_s.strip }
          result = check_row(row, allowed_sites)
          if result[:error]
            errors << { "row" => line, "message" => result[:error] }
          else
            payload << result[:data].merge("line" => line)
          end
        end
      end
      batch.update!(status: errors.empty? ? "validated" : "failed", total_rows: payload.size + errors.size,
                    error_rows: errors.size, row_errors: errors.first(200), payload: payload)
    end

    def self.commit!(batch)
      raise WmsError, "検証済みの取込のみ実行できます" unless batch.status == "validated"

      ActiveRecord::Base.transaction do
        batch.payload.each do |row|
          site = Site.find(row["site_id"])
          location = Location.find(row["location_id"])
          lot = Lot.create!(customer_id: row["customer_id"], item_id: row["item_id"], site: site, lot_number: row["lot_number"],
                            received_on: row["received_on"], required_temperature_type: row["required_temperature_type"].presence,
                            expires_on: row["expires_on"], import_batch: batch)
          note = "期首残高(Excel移行 ##{batch.id})"
          Inventory::Ledger.record!(lot: lot, type: "receive", quantity: row["quantity"], note: note, import_batch: batch)
          Inventory::Ledger.record!(lot: lot, type: "putaway", quantity: row["quantity"], to: location, note: note, import_batch: batch)
        end
        batch.update!(status: "completed", success_rows: batch.payload.size, committed_at: Time.current)
      end
    end

    # Rolls back a batch only if nothing else has touched its lots since.
    def self.rollback!(batch)
      raise WmsError, "実行済みの取込のみ取り消せます" unless batch.status == "completed"

      lot_ids = Lot.where(import_batch_id: batch.id).pluck(:id)
      if StockMovement.where(lot_id: lot_ids).where("import_batch_id IS NULL OR import_batch_id <> ?", batch.id).exists?
        raise WmsError, "取込後に入出荷・移動があるため取り消せません"
      end

      ActiveRecord::Base.transaction do
        # Bulk SQL on purpose: the ledger is append-only through ActiveRecord, rollback is the one audited exception.
        StockMovement.where(import_batch_id: batch.id).delete_all
        Lot.where(import_batch_id: batch.id).delete_all
        batch.update!(status: "rolled_back", rolled_back_at: Time.current)
        AuditLog.record!(action: "rollback", entity: batch, changeset: { "lots_removed" => lot_ids.size })
      end
    end

    def self.read_table(batch)
      data = batch.file.download
      if batch.filename.to_s.downcase.end_with?(".xlsx")
        sheet = Roo::Excelx.new(StringIO.new(data)).sheet(0)
        (sheet.first_row..sheet.last_row).map { |i| sheet.row(i) }
      else
        CSV.parse(data.dup.force_encoding("UTF-8").scrub.delete_prefix("\uFEFF"))
      end
    end
    private_class_method :read_table

    def self.map_headers(header_row)
      header_row.each_with_index.each_with_object({}) do |(h, col), map|
        key = HEADERS.find { |_, aliases| aliases.include?(h.to_s.strip.downcase) }&.first
        map[col] = key if key
      end
    end
    private_class_method :map_headers

    def self.check_row(row, allowed_sites)
      site = allowed_sites[row[:site_code]] or return { error: "拠点コードが不明、またはアクセス権がありません: #{row[:site_code]}" }
      customer = Customer.find_by(code: row[:customer_code]) or return { error: "荷主コードが不明です: #{row[:customer_code]}" }
      location = Location.joins(:zone).find_by(code: row[:location_code], zones: { site_id: site.id }) or
        return { error: "ロケーションが見つかりません: #{row[:location_code]}" }
      qty = BigDecimal(row[:quantity].to_s.tr(",", ""), exception: false)
      return { error: "数量が不正です: #{row[:quantity]}" } if qty.nil? || qty <= 0
      return { error: "ロット番号が空です" } if row[:lot_number].blank?

      item = row[:item_code].present? ? Item.find_by(customer_id: customer.id, code: row[:item_code]) : nil
      return { error: "品目コードが不明です: #{row[:item_code]}" } if row[:item_code].present? && item.nil?

      required = row[:required_temperature_type].presence && TEMPERATURE_ALIASES[row[:required_temperature_type].downcase]
      return { error: "温度帯が不正です: #{row[:required_temperature_type]}" } if row[:required_temperature_type].present? && required.nil?

      received_on = parse_date(row[:received_on]) || Date.current
      expires_on = parse_date(row[:expires_on])
      return { error: "日付が不正です" } if row[:expires_on].present? && expires_on.nil?

      { data: { "site_id" => site.id, "customer_id" => customer.id, "item_id" => item&.id, "lot_number" => row[:lot_number],
                "location_id" => location.id, "quantity" => qty.to_s("F"), "required_temperature_type" => required || item&.required_temperature_type,
                "received_on" => received_on.iso8601, "expires_on" => expires_on&.iso8601 } }
    end
    private_class_method :check_row

    def self.parse_date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end
    private_class_method :parse_date
  end
end
