class DeviceProfilesController < MasterCrudController
  private

  def model = DeviceProfile
  def title = "デバイスプロファイル(CSV取込設定)"
  def ability = :manage_temperature_config
  def order = :name
  def columns = %i[name timestamp_column value_column time_format encoding skip_lines]
  def permitted = %i[name timestamp_column value_column time_format time_zone skip_lines delimiter encoding notes]
  def form_fields
    [
      { name: :name },
      { name: :timestamp_column, hint: "CSVのヘッダー名(日時の列)" },
      { name: :value_column, hint: "CSVのヘッダー名(温度の列)" },
      { name: :time_format, hint: "例: %Y-%m-%d %H:%M:%S / %Y/%m/%d %H:%M" },
      { name: :time_zone },
      { name: :skip_lines, as: :integer, hint: "ヘッダー行の前に読み飛ばす行数" },
      { name: :delimiter },
      { name: :encoding, as: :select, collection: DeviceProfile::ENCODINGS.map { |e| [e, e] } },
      { name: :notes, as: :textarea }
    ]
  end
end
