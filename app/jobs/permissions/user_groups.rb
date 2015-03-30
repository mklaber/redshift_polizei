module Jobs
  module Permissions
    #
    # Job retrieving groups a user is the member of
    #
    class UserGroups < Base
      def execute(job_id, user_id, options={})
        user = {}
        user = { 'username' => options[:username] } unless options[:username].blank?

        RSPool.with do |connection|
          SQL.execute_grouped(connection,
            'permissions/users_groups',
            filters: user) do |result|
            result['username']
          end.hmap do |group, data_arr|
            data_arr.map { |data| data['group'] }
          end
        end
      end
    end
  end
end
