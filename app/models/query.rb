module Models
  #
  # Audit Log Query Model
  #
  class Query < ActiveRecord::Base
    # id                     :integer          not null, primary key
    # record_time            :integer          not null
    # db                     :string(255)      not null
    # user                   :string(255)      not null
    # pid                    :integer          not null
    # userid                 :integer          not null
    # xid                    :integer          not null
    # query                  :text             not null
    # logfile                :string(255)      not null
    # query_type             :integer          not null, 0 => select, 1 => non-select
  end
end
