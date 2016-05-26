class CreateStockMovements < ActiveRecord::Migration[8.0]
  def change
    create_table :stock_movements do |t|
      t.references :lot, null: false, foreign_key: true
      t.references :from_location, foreign_key: { to_table: :locations }
      t.references :to_location, foreign_key: { to_table: :locations }
      t.decimal :quantity, precision: 12, scale: 3, null: false
      t.string :movement_type, null: false
      t.references :performed_by, foreign_key: { to_table: :users }
      t.datetime :performed_at, null: false
      t.string :reference_type
      t.bigint :reference_id
      t.references :import_batch, foreign_key: true
      t.text :note
      t.datetime :created_at, null: false
    end
    add_index :stock_movements, %i[reference_type reference_id]
    add_index :stock_movements, %i[lot_id performed_at]
    add_check_constraint :stock_movements, "quantity > 0", name: "stock_movements_quantity_check"
    add_check_constraint :stock_movements,
      "movement_type IN ('receive','putaway','move','pick','ship','adjust','discard')",
      name: "stock_movements_type_check"

    # Current stock is DERIVED from the append-only ledger.
    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE VIEW stock_levels AS
          SELECT lot_id, location_id, SUM(delta) AS quantity
          FROM (
            SELECT lot_id, to_location_id AS location_id, quantity AS delta
              FROM stock_movements WHERE to_location_id IS NOT NULL
            UNION ALL
            SELECT lot_id, from_location_id AS location_id, -quantity AS delta
              FROM stock_movements WHERE from_location_id IS NOT NULL
          ) m
          GROUP BY lot_id, location_id
          HAVING SUM(delta) <> 0
        SQL
      end
      dir.down { execute "DROP VIEW IF EXISTS stock_levels" }
    end
  end
end
