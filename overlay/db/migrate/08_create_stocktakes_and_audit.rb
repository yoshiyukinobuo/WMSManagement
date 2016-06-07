class CreateStocktakesAndAudit < ActiveRecord::Migration[8.0]
  def change
    create_table :stocktakes do |t|
      t.references :site, null: false, foreign_key: true
      t.references :zone, foreign_key: true
      t.string :status, null: false, default: "counting"
      t.references :started_by, foreign_key: { to_table: :users }
      t.datetime :submitted_at
      t.references :approved_by, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.text :note
      t.timestamps
    end

    create_table :stocktake_lines do |t|
      t.references :stocktake, null: false, foreign_key: true
      t.references :lot, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.decimal :system_quantity, precision: 12, scale: 3, null: false
      t.decimal :counted_quantity, precision: 12, scale: 3
      t.timestamps
    end
    add_index :stocktake_lines, %i[stocktake_id lot_id location_id], unique: true, name: "idx_stocktake_lines_unique"

    create_table :audit_logs do |t|
      t.references :actor, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :entity_type, null: false
      t.bigint :entity_id
      t.jsonb :changeset, null: false, default: {}
      t.datetime :occurred_at, null: false
    end
    add_index :audit_logs, %i[entity_type entity_id]
    add_index :audit_logs, :occurred_at
  end
end
