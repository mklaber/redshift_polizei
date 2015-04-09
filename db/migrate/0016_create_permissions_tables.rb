class CreatePermissionsTables < ActiveRecord::Migration
  def change
    create_table(:database_users) do |t|
      t.integer :database_id, null: false
      t.string :name, null: false
      t.boolean :superuser, null: false
      t.timestamps null: false
    end
    add_index :database_users, :database_id, unique: true
    add_index :database_users, :name, unique: true
    add_index :database_users, :updated_at

    create_table(:database_groups) do |t|
      t.integer :database_id, null: true # default group has no ID
      t.string :name, null: false
      t.timestamps null: false
    end
    add_index :database_groups, :database_id, unique: true
    add_index :database_groups, :name, unique: true
    add_index :database_groups, :updated_at

    create_table(:database_group_memberships) do |t|
      t.belongs_to :database_user, null: false, index: true
      t.belongs_to :database_group, null: false, index: true
      t.timestamps null: false
    end
    add_index :database_group_memberships, :updated_at

    create_table(:schemas) do |t|
      t.integer :database_id, null: false
      t.string :name, null: false
      t.belongs_to :database_user, null: false, index: true
      t.timestamps null: false
    end
    add_index :schemas, :name, :unique => true
    add_index :schemas, :updated_at

    create_table(:tables) do |t|
      t.belongs_to :schema, null: false, index: true
      t.integer :database_id, null: false
      t.string :name, null: false
      t.belongs_to :database_user, null: false, index: true
      t.timestamps null: false
    end
    add_index :tables, :name
    add_index :tables, :updated_at

    create_table(:permissions) do |t|
      t.references :entity, polymorphic: true, null: false, index: true
      t.references :dbobject, polymorphic: true, null: false, index: true
      t.boolean :has_select, null: false
      t.boolean :has_insert, null: false
      t.boolean :has_update, null: false
      t.boolean :has_delete, null: false
      t.boolean :has_references, null: false
      t.timestamps null: false
    end
    add_index :permissions, [:entity_id, :entity_type, :dbobject_id, :dbobject_type], name: 'permissions_unique',:unique => true
    add_index :permissions, :updated_at
  end
end
