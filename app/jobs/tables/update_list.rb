module Jobs
  module Tables
    ##
    # Updates the local list of schemas and tables exisitng in RedShift
    #
    class UpdateList < Desmond::BaseJobNoJobId
      extend Jobs::BaseReportNoJobId
      
      def execute(job_id, user_id, options={})
        # retrieve latest set of schemas and tables from RedShift
        tables = RSPool.with do |connection|
          TableUtils.get_all_table_names(connection)
        end
        # go through all schemas and tables in RedShift now and update them if necessary
        # at least touching them so we can filter what exists
        now = Time.now.utc
        Models::Schema.transaction do
          tables.values.each do |table|
            begin
              schema_owner = Models::DatabaseUser.where(name: table['schema_owner_name']).first
              fail 'schema owner could not be found, make sure the local list of users is up to date' if schema_owner.nil?
              schema = Models::Schema.find_or_initialize_by(
                name: table['schema_name'])
              schema.update!(database_id: table['schema_id'], owner: schema_owner)
              schema.touch
              tbl_owner = Models::DatabaseUser.where(name: table['table_owner_name']).first
              fail 'table owner could not be found, make sure the local list of users is up to date' if tbl_owner.nil?
              dbtbl = Models::Table.find_or_initialize_by(
                schema: schema, name: table['table_name'])
              dbtbl.update!(database_id: table['table_id'], owner: tbl_owner)
              dbtbl.touch
            rescue
              Que.log level: :error, message: "error while processing #{table}"
              raise
            end
          end
        end
        # remove schema and tables which were deleted (not touched by code above)
        Models::Table.where('updated_at < ?', now).destroy_all
        Models::Schema.where('updated_at < ?', now).destroy_all
        Models::Table.connection.execute('VACUUM ANALYZE tables')
        Models::Schema.connection.execute('VACUUM ANALYZE schemas')
        true
      end
    end
  end
end
