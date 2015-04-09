module Models
  ##
  # RedShift groups
  #
  class DatabaseGroup < ActiveRecord::Base
    # id                     :integer          not null, primary key
    # database_id            :integer          null, unique
    # name                   :integer          not null, unique

    has_and_belongs_to_many :users, class_name: 'DatabaseUser', join_table: :database_group_memberships
    has_many :permissions, as: :entity, dependent: :destroy

    validates :name, presence: true
    validates :name, uniqueness: true

    def as_json(options={})
      tmp = self.attributes
      tmp['type'] = 'group'
      tmp['members'] = self.users
      tmp
    end
  end
end
