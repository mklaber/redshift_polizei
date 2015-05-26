module Models
  #
  # Model representing archives of Redshift tables
  #
  class TableArchive < ActiveRecord::Base
    # id                     :integer          not null, primary key
    # schema_name            :string(255)      not null
    # table_name             :string(255)      not null
    # archive_bucket         :string(255)      not null
    # archive_prefix         :string(255)      not null
    # size_in_mb             :integer          null
    # dist_key               :string(255)      null
    # dist_style             :string(255)      null
    # sort_keys              :json             null
    # has_col_encodings      :boolean          null
    # dist_style             :string(255)      null
  end
end
