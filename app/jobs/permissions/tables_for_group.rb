module Jobs
  module Permissions
    #
    # Job retrieving a groups permissions on all tables
    #
    class TablesForGroup < Base
      def execute(job_id, user_id, options={})
        fail 'No group given' if options[:group].blank?
        group = "%group #{group}%"

        RSPool.with do |connection|
          self.class.make_boolean(SQL.execute(connection,
            'permissions/tables_for_group',
            parameters: group).to_a)
        end
      end
    end
  end
end
