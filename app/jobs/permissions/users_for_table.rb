module Jobs
  module Permissions
    #
    # Job retrieving users permissions on a table
    #
    class UsersForTable < Base
      def execute(job_id, user_id, options={})
        table = {}
        table['t.schemaname'] = options[:schema_name] unless options[:schema_name].blank?
        table['t.tablename'] = options[:table_name] unless options[:table_name].blank?

        RSPool.with do |connection|
          self.class.make_boolean(SQL.execute_grouped(connection,
            'permissions/users_tables',
            filters: table) do |result|
            "#{result['schema_name']}.#{result['table_name']}"
          end).hmap do |full_table_name, data_arr|
            data_arr.map { |data| data['username'] }
          end
        end
      end
    end
  end
end
