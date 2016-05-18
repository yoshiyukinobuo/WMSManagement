class CreateLotsAndReceipts < ActiveRecord::Migration[8.0]
  def change
    create_table :lots do |t|
      t.string :internal_id, null: false # stable, unique, label-ready (QR in Phase 2)
      t.references :customer, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.string :lot_number, null: false # as given (free-form)
      t.date :received_on
      t.string :required_temperature_type
      t.date :expires_on
      t.string :status, null: false, default: "available"
      t.string :hold_reason
      t.references :import_batch, foreign_key: true
      t.timestamps
    end
    add_index :lots, :internal_id, unique: true
    add_index :lots, :lot_number
    add_index :lots, :status
    add_check_constraint :lots, "status IN ('available','hold','shipped','discarded')", name: "lots_status_check"

    create_table :receipts do |t|
      t.references :site, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.datetime :arrival_at, null: false
      t.string :vehicle
      t.string :driver
      t.string :manifest_ref
      t.text :notes
      t.string :status, null: false, default: "open"
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :receipts, :arrival_at

    create_table :receipt_lines do |t|
      t.references :receipt, null: false, foreign_key: true
      t.references :lot, foreign_key: true
      t.references :item, foreign_key: true
      t.string :lot_number, null: false
      t.string :slip_lot_number
      t.string :manifest_lot_number
      t.decimal :expected_quantity, precision: 12, scale: 3
      t.decimal :received_quantity, precision: 12, scale: 3, null: false
      t.string :unit, null: false, default: "個"
      t.string :required_temperature_type
      t.date :expires_on
      t.boolean :source_mismatch, null: false, default: false
      t.boolean :quantity_discrepancy, null: false, default: false
      t.text :note
      t.timestamps
    end
  end
end
