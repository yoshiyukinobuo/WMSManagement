class CreateImportBatches < ActiveRecord::Migration[8.0]
  def change
    create_table :import_batches do |t|
      t.string :kind, null: false
      t.string :filename
      t.string :status, null: false, default: "validated"
      t.references :site, foreign_key: true
      t.references :sensor, foreign_key: true
      t.references :uploaded_by, foreign_key: { to_table: :users }
      t.integer :total_rows, null: false, default: 0
      t.integer :success_rows, null: false, default: 0
      t.integer :skipped_rows, null: false, default: 0
      t.integer :error_rows, null: false, default: 0
      t.jsonb :row_errors, null: false, default: []
      t.jsonb :payload, null: false, default: []
      t.datetime :committed_at
      t.datetime :rolled_back_at
      t.timestamps
    end
  end
end
