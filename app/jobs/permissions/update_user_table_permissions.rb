module Jobs
  module Permissions
    ##
    # Updates user table permissions defined in RedShift
    #
    class UpdateUserTablePermissions < Base
      extend Jobs::BaseReportNoJobId

      #
      # this touches a lot of rows on each run (cross join of users and tables, starts at 60000 for us),
      # so this is optimizied to minimize queries (find_by lookup caches, mass touch).
      # That obviously makes the code harder to read than a straightforward implementation,
      # but increases the speed a lot.
      #
      def execute(job_id, user_id, options={})
        # retrieve user table permissions from RedShift
        results = RSPool.with do |connection|
          self.class.make_boolean(SQL.execute(connection, 'permissions/users_tables'))
        end
        now = Time.now.utc
        # update or touch everything we found
        @user_cache  = {}
        @table_cache = {}
        @permissions_cache = {}
        touch_list = []
        Models::Permission.transaction do
          results.each do |data|
            begin
              u = get_user(data['username'])
              t = get_table(data['schema_name'], data['table_name'])

              p = get_permission(t, u)
              p.update!(has_select: data['has_select'], has_insert: data['has_insert'],
                has_update: data['has_update'], has_delete: data['has_delete'],
                has_references: data['has_references'])
              touch_list << p.id
            rescue
              Que.log level: :error, message: "error while processing #{data}"
              raise
            end
          end
          # this creates a huge sql query [id IN (thousands of id's)], but still seems worth it
          Models::Permission.where(id: touch_list).update_all(updated_at: now)
        end
        # delete everything that wasn't touched
        Models::Permission.where('entity_type = ? AND dbobject_type = ? AND updated_at < ?',
          'Models::DatabaseUser', 'Models::Table', now).destroy_all
        Models::Permission.connection.execute('VACUUM ANALYZE permissions')
        true
      end

      private

      ##
      # cached retrieval of DatabaseUser model
      #
      def get_user(name)
        u = @user_cache[name]
        if u.nil?
          u = Models::DatabaseUser.where(name: name).first
          fail "user #{name} could not be found, make sure the local copy of users is up to date" if u.nil?
          @user_cache[name] = u
        end
        u
      end

      ##
      # cached retrieval of Table model
      #
      def get_table(schema_name, table_name)
        t = @table_cache.fetch(schema_name, {})[table_name]
        if t.nil?
          t = Models::Table.where(name: table_name).includes(:schema).where(
            'schemas.name' => schema_name).first
          fail "table #{schema_name}.#{table_name} could not be found, make sure the local copy of tables is up to date" if t.nil?
          @table_cache[schema_name] ||= {}
          @table_cache[schema_name][table_name] = t
        end
        t
      end

      ##
      # cached retrieval of Permission model
      #
      def get_permission(dbobject, entity)
        p = @permissions_cache.fetch(dbobject, {})[entity]
        if p.nil?
          # pre-fetch more permissions than necessary
          Models::Permission.where(entity: entity).includes(:entity).includes(:dbobject).includes(dbobject: :schema).each do |tmp|
            @permissions_cache[tmp.dbobject] ||= {}
            @permissions_cache[tmp.dbobject][tmp.entity] = tmp
            @user_cache[tmp.entity.name] = tmp.entity
            @table_cache[tmp.dbobject.schema.name] ||= {}
            @table_cache[tmp.dbobject.schema.name][tmp.dbobject.name] = tmp.dbobject
            p = tmp if tmp.dbobject == dbobject && tmp.entity == entity
          end
          # not found initialize a new one
          p = Models::Permission.new(dbobject: dbobject, entity: entity) if p.nil?
        end
        p
      end
    end
  end
end
