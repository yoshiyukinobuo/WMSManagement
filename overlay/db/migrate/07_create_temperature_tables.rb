class CreateTemperatureTables < ActiveRecord::Migration[8.0]
  def change
    create_table :temperature_readings do |t|
      t.references :zone, null: false, foreign_key: true
      t.references :sensor, null: false, foreign_key: true
      t.datetime :measured_at, null: false # stored in UTC
      t.decimal :value, precision: 6, scale: 2, null: false # degrees C
      t.string :source, null: false
      t.references :import_batch, foreign_key: true
      t.references :recorded_by, foreign_key: { to_table: :users }
      t.references :corrects, foreign_key: { to_table: :temperature_readings }
      t.string :correction_reason
      t.datetime :created_at, null: false
    end
    add_index :temperature_readings, %i[zone_id measured_at]
    # Re-importing a file must not duplicate data. Corrections (new rows referencing the original) are exempt.
    add_index :temperature_readings, %i[sensor_id measured_at],
      unique: true, where: "corrects_id IS NULL", name: "idx_readings_sensor_time"
    add_check_constraint :temperature_readings, "source IN ('manual','csv','api')", name: "readings_source_check"

    create_table :excursions do |t|
      t.references :zone, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.decimal :peak_value, precision: 6, scale: 2
      t.string :breach_type
      t.string :status, null: false, default: "open"
      t.datetime :detected_at, null: false
      t.string :detected_via, null: false, default: "live"
      t.timestamps
    end
    add_index :excursions, %i[zone_id started_at], unique: true

    create_table :excursion_lot_impacts do |t|
      t.references :excursion, null: false, foreign_key: true
      t.references :lot, null: false, foreign_key: true
      t.integer :exposure_minutes, null: false, default: 0
      t.string :disposition, null: false, default: "hold"
      t.boolean :already_left, null: false, default: false
      t.references :decided_by, foreign_key: { to_table: :users }
      t.datetime :decided_at
      t.text :comment
      t.timestamps
    end
    add_index :excursion_lot_impacts, %i[excursion_id lot_id], unique: true
    add_check_constraint :excursion_lot_impacts, "disposition IN ('hold','release','discard')", name: "impacts_disposition_check"

    # Append-only decision log; the impact row is a projection of the latest decision.
    create_table :excursion_decisions do |t|
      t.references :excursion_lot_impact, null: false, foreign_key: true
      t.string :disposition, null: false
      t.references :decided_by, foreign_key: { to_table: :users }
      t.text :comment, null: false
      t.datetime :created_at, null: false
    end
  end
end
