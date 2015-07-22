module Models
  #
  # Model representing statistics of Redshift tables
  #
  class TableReport < ActiveRecord::Base
    # id                     :integer          not null, primary key
    # schema_name            :string(255)      not null
    # table_name             :string(255)      not null
    # table_id               :integer          not null
    # size_in_mb             :integer          not null
    # pct_skew_across_slices :float            not null
    # pct_slices_populated   :float            not null
    # dist_key               :string(255)      not null
    # sort_keys              :json             not null
    # has_col_encodings      :boolean          not null
    # dist_style             :string(255)      null
    # sort_style             :string(255)      null
    # comment                :string(255)      null
    # columns                :json             null
  end
end
