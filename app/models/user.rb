class User < ActiveRecord::Base
  using(:postgres)
  # id                     :integer          not null, primary key
  # email                  :string(255)      not null
  # google_id              :string(255)      not null
end
