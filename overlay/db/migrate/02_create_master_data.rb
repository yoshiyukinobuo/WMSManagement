class CreateMasterData < ActiveRecord::Migration[8.0]
  def change
    create_table :sites do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :address
      t.string :time_zone, null: false, default: "Asia/Tokyo"
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :sites, :code, unique: true

    create_table :user_site_scopes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.timestamps
    end
    add_index :user_site_scopes, %i[user_id site_id], unique: true

    create_table :zones do |t|
      t.references :site, null: false, foreign_key: true
      t.string :name, null: false
      t.string :zone_type, null: false
      t.decimal :target_min, precision: 5, scale: 1
      t.decimal :target_max, precision: 5, scale: 1
      t.decimal :alert_min, precision: 5, scale: 1
      t.decimal :alert_max, precision: 5, scale: 1
      t.integer :expected_interval_minutes, null: false, default: 60
      t.integer :tolerance_minutes, null: false, default: 0
      t.integer :close_after_in_range, null: false, default: 3
      t.datetime :missing_data_alerted_at
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :zones, %i[site_id name], unique: true
    add_check_constraint :zones, "zone_type IN ('frozen','chilled','constant','ambient')", name: "zones_zone_type_check"
    add_check_constraint :zones, "alert_min IS NULL OR alert_max IS NULL OR alert_min <= alert_max", name: "zones_alert_order_check"

    create_table :locations do |t|
      t.references :zone, null: false, foreign_key: true
      t.string :code, null: false
      t.string :description
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :locations, %i[zone_id code], unique: true

    create_table :customers do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :customers, :code, unique: true

    create_table :items do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :required_temperature_type
      t.string :unit, null: false, default: "個"
      t.timestamps
    end
    add_index :items, %i[customer_id code], unique: true

    create_table :device_profiles do |t|
      t.string :name, null: false
      t.string :timestamp_column, null: false
      t.string :value_column, null: false
      t.string :time_format, null: false, default: "%Y-%m-%d %H:%M:%S"
      t.string :time_zone, null: false, default: "Asia/Tokyo"
      t.integer :skip_lines, null: false, default: 0
      t.string :delimiter, null: false, default: ","
      t.string :encoding, null: false, default: "UTF-8"
      t.text :notes
      t.timestamps
    end

    create_table :sensors do |t|
      t.references :zone, null: false, foreign_key: true
      t.references :device_profile, foreign_key: true
      t.string :name, null: false
      t.string :maker
      t.string :sensor_model
      t.string :external_id
      t.string :source_type, null: false, default: "manual"
      t.date :calibration_due_on
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :sensors, :external_id
    add_check_constraint :sensors, "source_type IN ('manual','csv','api')", name: "sensors_source_type_check"
  end
end
