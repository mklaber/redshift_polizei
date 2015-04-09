module Models
  ##
  # RedShift users
  #
  class DatabaseUser < ActiveRecord::Base
    # id                     :integer          not null, primary key
    # database_id            :integer          not null, unique
    # name                   :integer          not null, unique
    # superuser              :boolean          not null

    has_and_belongs_to_many :groups, class_name: 'DatabaseGroup', join_table: :database_group_memberships
    has_many :permissions, as: :entity, dependent: :destroy

    validates :database_id, :name, presence: true
    validates_inclusion_of :superuser, :in => [true, false]
    
    validates :name, uniqueness: true

    def as_json(options={})
      tmp = self.attributes
      tmp['type'] = 'user'
      tmp
    end
  end
end
