module Jobs
  module Permissions
    #
    # Job retrieving all table permissions for a user
    #
    class TablesForUser < Base
      def execute(job_id, user_id, options={})
        user = {}
        user = { 'u.usename' => options[:username] } unless options[:username].blank?

        RSPool.with do |connection|
          self.class.make_boolean(SQL.execute_grouped(connection,
            'permissions/users_tables',
            filters: user) do |result|
            result['username']
          end)
        end
      end
    end
  end
end
