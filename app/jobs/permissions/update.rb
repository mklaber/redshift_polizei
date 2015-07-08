module Jobs
  module Permissions
    class Update < Desmond::BaseJobNoJobId
      
      def execute(job_id, user_id, options={})
        # update our list of groups and users with the real deal
        Jobs::Permissions::UpdateUsersAndGroups.run(user_id)
        # update our list of schemas and tables with the real deal
        Jobs::Tables::UpdateList.run(user_id)
        # update our list of table permissions
        Jobs::Permissions::UpdateGroupTableDeclaredPermissions.run(user_id)
        Jobs::Permissions::UpdateUserTableDeclaredPermissions.run(user_id)
        Jobs::Permissions::UpdateUserTableEffectivePermissions.run(user_id)
      end
    end
  end
end