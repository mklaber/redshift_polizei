module Jobs
  module Permissions
    #
    # Updates the local list of users and groups exisitng in RedShift
    #
    class UpdateUsersAndGroups < Desmond::BaseJobNoJobId
      extend Jobs::BaseReportNoJobId
      
      def execute(job_id, user_id, options={})
        # retrieve the current list of users and groups from RedShift
        results = RSPool.with do |connection|
          SQL.execute(connection, 'permissions/users_in_groups')
        end
        # update our local copy, at least touching them, so old entries can be deleted
        now = Time.now.utc
        Models::DatabaseGroup.transaction do
          results.each do |data|
            begin
              group = Models::DatabaseGroup.find_or_initialize_by(database_id: data['group_id'])
              group.update!(name: data['group'])
              group.touch
              user = Models::DatabaseUser.find_or_initialize_by(database_id: data['user_id'])
              user.update!(name: data['username'], superuser: (data['is_superuser'] == 't'))
              user.touch
              unless Models::DatabaseGroupMemberships.where(user: user, group: group).exists?
                Models::DatabaseGroupMemberships.create!(user: user, group: group)
              end
            rescue
              Que.log level: :error, message: "error while processing #{data}"
              raise
            end
            public_group = Models::DatabaseGroup.find_or_initialize_by(name: 'public')
            public_group.update!(database_id: 0)
            Models::DatabaseUser.all.each do |user|
              unless Models::DatabaseGroupMemberships.where(user: user, group: public_group).exists?
                Models::DatabaseGroupMemberships.create!(user: user, group: public_group)
              end
            end
          end
        end
        # remove groups and users which were deleted (not touched by code above)
        Models::DatabaseUser.where('updated_at < ?', now).destroy_all
        Models::DatabaseGroup.where('updated_at < ?', now).destroy_all
        Models::DatabaseUser.connection.execute('VACUUM ANALYZE database_users')
        Models::DatabaseGroup.connection.execute('VACUUM ANALYZE database_groups')
        true
      end
    end
  end
end
