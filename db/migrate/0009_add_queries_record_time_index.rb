class AddQueriesRecordTimeIndex < ActiveRecord::Migration
  def change
    add_index :queries, :record_time, order: { record_time: :desc }
  end
end
