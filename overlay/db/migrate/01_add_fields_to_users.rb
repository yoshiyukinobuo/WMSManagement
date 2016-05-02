class AddFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :name, :string
    add_column :users, :role, :string, null: false, default: "floor_staff"
    add_column :users, :active, :boolean, null: false, default: true
  end
end
