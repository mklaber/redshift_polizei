module Jobs
  module Permissions
    class Update < Desmond::BaseJobNoJobId
      extend Jobs::BaseReportNoJobId
      
      def execute(job_id, user_id, options={})
        # update our list of groups and users with the real deal
        Jobs::Permissions::UpdateUsersAndGroups.run(user_id)
        # update our list of schemas and tables with the real deal
        Jobs::Tables::UpdateList.run(user_id)
        # update our list of table permissions
        Jobs::Permissions::UpdateUserTablePermissions.run(user_id)
        Jobs::Permissions::UpdateGroupTablePermissions.run(user_id)
      end
    end
  end
end