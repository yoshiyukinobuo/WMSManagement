class CreateShipments < ActiveRecord::Migration[8.0]
  def change
    create_table :shipments do |t|
      t.references :site, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.string :destination
      t.string :reference
      t.string :vehicle
      t.string :driver
      t.string :status, null: false, default: "draft"
      t.datetime :shipped_at
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :shipment_lines do |t|
      t.references :shipment, null: false, foreign_key: true
      t.references :lot, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.decimal :quantity, precision: 12, scale: 3, null: false
      t.datetime :picked_at
      t.timestamps
    end
  end
end
