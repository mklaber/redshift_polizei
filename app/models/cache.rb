class Cache < ActiveRecord::Base
  self.table_name = :cache
  using(:postgres)
  # id                     :integer          not null, primary key
  # hashid                 :string(255)      not null
  # expires                :integer          not null
  # data                   :string(255)      not null
end
