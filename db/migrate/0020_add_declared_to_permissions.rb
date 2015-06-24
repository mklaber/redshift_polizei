class AddDeclaredToPermissions < ActiveRecord::Migration
  def up
    execute "truncate permissions"
    add_column   :permissions, :declared, :bool, :null => false
    remove_index :permissions, name: 'permissions_unique'
    add_index    :permissions, [:entity_id, :entity_type, :dbobject_id, :dbobject_type, :declared], name: 'permissions_unique', unique: true
    add_index    :permissions, :declared
  end

  def down
    execute "truncate permissions"
    remove_index  :permissions, name: 'permissions_unique'
    remove_index  :permissions, :declared
    add_index     :permissions, [:entity_id, :entity_type, :dbobject_id, :dbobject_type], name: 'permissions_unique', unique: true
    remove_column :permissions, :declared
  end
end
