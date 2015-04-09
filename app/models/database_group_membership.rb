module Models
  ##
  # RedShift group memberships
  #
  class DatabaseGroupMemberships < ActiveRecord::Base
    # id                     :integer          not null, primary key
    # database_user_id       :integer          not null
    # database_group_id      :integer          not null

    belongs_to :user, class_name: 'DatabaseUser', foreign_key: :database_user_id
    belongs_to :group, class_name: 'DatabaseGroup', foreign_key: :database_group_id

    validates :database_user_id, :database_group_id, presence: true
    validate :validate_unqiueness

    private

    def validate_unqiueness
      if self.class.where(user: self.user, group: self.group).exists?
        errors.add(:user, "already defined as member in group")
      end
    end
  end
end
