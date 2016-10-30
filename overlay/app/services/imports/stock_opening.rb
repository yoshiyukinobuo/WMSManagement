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
