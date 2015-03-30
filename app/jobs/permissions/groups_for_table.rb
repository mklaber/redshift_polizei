module Jobs
  module Permissions
    #
    # Job retrieving all groups permissions on a table
    #
    class GroupsForTable < Base
      def execute(job_id, user_id, options={})
        table = {}
        table['trim(n.nspname)'] = options[:schema_name] unless options[:schema_name].blank?
        table['trim(c.relname)'] = options[:table_name] unless options[:table_name].blank?

        RSPool.with do |connection|
          groups = SQL.execute(connection, 'permissions/groups').map { |result| result['group'] }
          groups.map do |group|
            self.class.make_boolean(SQL.execute(connection,
              'permissions/tables_for_group',
              parameters: [group, group, group, group, group, group], filters: table).to_a)
          end
        end
      end
    end
  end
end
