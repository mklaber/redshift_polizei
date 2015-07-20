require_relative '../../main'

module Jobs
  ##
  # job updating the comment on a postgres table
  #
  # Please see `BaseJob` class documentation on how to run
  # any job using its general interface.
  #
  class CommentJob < Desmond::BaseJob
    ##
    # the following +options+ are required:
    # - schema_name
    # - table_name
    # - comment: if not specified or nil, will NULL out the comment
    def execute(job_id, user_id, options={})
      schema_name = options[:schema_name]
      fail 'Empty schema name!' if schema_name.nil? || schema_name.empty?
      table_name = options[:table_name]
      fail 'Empty table name!' if table_name.nil? || table_name.empty?
      comment = options[:comment]

      RSPool.with do |c|
        full_table_name = "#{Desmond::PGUtil.escape_identifier(schema_name)}.#{Desmond::PGUtil.escape_identifier(table_name)}"
        if comment.nil?
          sql = "COMMENT ON TABLE #{full_table_name} IS NULL;"
        else
          sql = "COMMENT ON TABLE #{full_table_name} IS '#{Desmond::PGUtil.escape_string(comment)}';"
        end
        c.exec(sql)
      end

      # Update the comment locally.
      table_info = Models::TableReport.find_by(schema_name: schema_name, table_name: table_name)
      table_info.update!({comment: comment})

      # Returns true on success.
      true
    end
  end
end
