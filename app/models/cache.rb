module Models
  #
  # Model representing a cache item if ActiveRecord is used
  #
  class Cache < ActiveRecord::Base
    self.table_name = :cache
    # id                     :integer          not null, primary key
    # hashid                 :string(255)      not null
    # expires                :integer          not null
    # data                   :string(255)      not null
  end
end
