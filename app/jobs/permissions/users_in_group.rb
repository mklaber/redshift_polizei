module Jobs
  module Permissions
    #
    # Job retrieving users in a group
    #
    class UsersInGroup < Base
      def execute(job_id, user_id, options={})
        group = {}
        group = { "nvl(groname, 'default')" => options[:group] } unless options[:group].blank?

        RSPool.with do |connection|
          SQL.execute_grouped(connection,
            'permissions/users_groups',
            filters: group) do |result|
            result['group']
          end.hmap do |group, data_arr|
            data_arr.map { |data| data['username'] }
          end
        end
      end
    end
  end
end
