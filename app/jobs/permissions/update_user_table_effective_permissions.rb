module Jobs
  module Permissions
    ##
    # Updates user table permissions defined in RedShift
    #
    class UpdateUserTableEffectivePermissions < Base

      #
      # this touches a lot of rows on each run (cross join of users and tables, starts at 60000 for us),
      # so this is optimizied to minimize queries (find_by lookup caches, mass touch).
      # That obviously makes the code harder to read than a straightforward implementation,
      # but increases the speed a lot.
      #
      def execute(job_id, user_id, options={})
        # retrieve user table permissions from RedShift
        results = RSPool.with do |connection|
          self.class.make_boolean(SQL.execute(connection, 'permissions/tables_for_users_effective'))
        end
        now = Time.now.utc
        # update or touch everything we found
        build_user_cache
        build_table_cache
        @permissions_cache = {}
        Models::Permission.transaction do
          Models::Permission.where('entity_type = ? AND dbobject_type = ? AND declared = ?',
            'Models::DatabaseUser', 'Models::Table', false).delete_all
          results.each do |data|
            begin
              u = @user_cache[data['username']]
              t = @table_cache[data['schema_name']][data['table_name']]

              unless u.nil? || t.nil?
                p = Models::Permission.new(entity: u, dbobject: t, declared: false)
                p.update!(has_select: data['has_select'], has_insert: data['has_insert'],
                  has_update: data['has_update'], has_delete: data['has_delete'],
                  has_references: data['has_references'])
              end
            rescue
              Que.log level: :error, message: "error while processing #{data}"
              raise
            end
          end
          # this creates a huge sql query [id IN (thousands of id's)], but still seems worth it
          #Models::Permission.where(id: touch_list).update_all(updated_at: now)
        end
        # delete everything that wasn't touched
        Models::Permission.where('entity_type = ? AND dbobject_type = ? AND declared = ? AND updated_at < ?',
          'Models::DatabaseUser', 'Models::Table', false, now).destroy_all
        Models::Permission.connection.execute('VACUUM ANALYZE permissions')
        true
      end

      private

      ##
      # cached retrieval of DatabaseUser model
      #
      def build_user_cache
        @user_cache  = {}
        Models::DatabaseUser.all.each do |u|
          @user_cache[u.name] = u
        end
      end

      ##
      # cached retrieval of Table model
      #
      def build_table_cache
        @table_cache = {}
        Models::Table.all.includes(:schema).each do |tbl|
          @table_cache[tbl.schema.name] ||= {}
          @table_cache[tbl.schema.name][tbl.name] = tbl
        end
      end

      ##
      # cached retrieval of Permission model
      #
      def get_permission(dbobject, entity)
        p = @permissions_cache.fetch(dbobject, {})[entity]
        if p.nil?
          # pre-fetch more permissions than necessary
          Models::Permission.where(entity: entity, declared: false).each do |tmp|
            @permissions_cache[tmp.dbobject] ||= {}
            @permissions_cache[tmp.dbobject][tmp.entity] = tmp
            p = tmp if tmp.dbobject == dbobject && tmp.entity == entity
          end
          # not found initialize a new one
          p = Models::Permission.new(dbobject: dbobject, entity: entity, declared: false) if p.nil?
        end
        p
      end
    end
  end
end
