module Models
  #
  # User Model
  #
  class User < ActiveRecord::Base
    # id                     :integer          not null, primary key
    # email                  :string(255)      not null
    # google_id              :string(255)      not null

    has_many :export_jobs

    def name
      self[:email][0, self[:email].index('@')]
    end
  end
end
