module Models
  ##
  # RedShift table
  #
  class Table < ActiveRecord::Base
    # id                     :integer          not null, primary key
    # schema_id              :integer          not null
    # database_id            :integer          not null, unique
    # name                   :integer          not null
    # owner                  :database_user    not null

    belongs_to :schema
    belongs_to :owner, class_name: 'Models::DatabaseUser', foreign_key: :database_user_id
    has_many :permissions, as: :dbobject, dependent: :destroy

    validates :schema_id, :database_id, :name, presence: true

    def self.find_by_full_name(schema_name, table_name)
      Models::Table.find_by!(schema: Models::Schema.find_by!(name: schema_name), name: table_name)
    end

    def as_json(options={})
      {
        type: 'table',
        schema_name: self.schema.name,
        table_name: self.name,
        owner: self.owner
      }
    end
  end
end
