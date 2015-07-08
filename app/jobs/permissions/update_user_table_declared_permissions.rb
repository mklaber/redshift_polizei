module Jobs
  module Permissions
    ##
    # Updates group table permissions defined in RedShift
    #
    class UpdateUserTableDeclaredPermissions < Base

      def execute(job_id, user_id, options={})
        # retrieve user table permissions from RedShift
        results =  RSPool.with do |connection|
          self.class.make_boolean(SQL.execute(connection,
            'permissions/tables_for_users_declared').to_a).each do |perm|
                perm['user'] = perm['grantee']
          end
        end

        now = Time.now.utc
        # update or touch everything we found
        results.each do |data|
          begin
            u = Models::DatabaseUser.where(name: data['user']).first
            t = Models::Table.where(name: data['table_name']).includes(:schema).where('schemas.name' => data['schema_name']).first
            fail 'user could not be found, make sure the local copy of users is up to date' if u.nil?
            fail 'table could not be found, make sure the local copy of tables is up to date' if t.nil?
            p = Models::Permission.find_or_initialize_by(dbobject: t, entity: u, declared: true)
            p.update!(has_select: data['has_select'], has_insert: data['has_insert'],
              has_update: data['has_update'], has_delete: data['has_delete'],
              has_references: data['has_references'])
            p.touch
          rescue
            Que.log level: :error, message: "error while processing #{data}"
            raise
          end
        end
        # delete everything that wasn't touched
        Models::Permission.where('entity_type = ? AND dbobject_type = ? AND declared = ? AND updated_at < ?',
          'Models::DatabaseUser', 'Models::Table', true, now).destroy_all
        Models::Permission.connection.execute('VACUUM ANALYZE permissions')
        true
      end
    end
  end
end
