module Models
  ##
  # RedShift schema
  #
  class Schema < ActiveRecord::Base
    # id                     :integer          not null, primary key
    # database_id            :integer          not null, unique
    # name                   :integer          not null, unique

    has_many :tables, dependent: :destroy
    belongs_to :owner, class_name: 'Models::DatabaseUser', foreign_key: :database_user_id
    has_many :permissions, as: :dbobject, dependent: :destroy

    validates :database_id, :name, presence: true
    validates :name, uniqueness: true
  end
end
