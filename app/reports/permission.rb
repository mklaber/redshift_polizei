module Reports
  #
  # Report retrieving permissions for users, groups, tables
  #
  class Permission < Base

    #
    # caches permissions for all users, groups and tables
    #
    def run
      users, groups, tables = self.result
      users.each  { |user| self.get_tables_for_user(user) }
      groups.each { |group| self.get_tables_with_group(group) }
      tables.each do |table|
        table_parts = table.split("-->")
        self.get_users_with_access(table_parts[0], table_parts[1])
      end
    end

    #
    # retrieves user, group and tables names
    #
    def result
      users, groups, tables = [], [], []

      user_sql = <<-SQL
        SELECT u.usename FROM pg_user u;
      SQL
      users_as_dicts = cache(user_sql) do
        self.class.select_all(user_sql)
      end
      users_as_dicts.each do |use_dict|
        users.append(use_dict["usename"])
      end

      table_sql = <<-SQL
        SELECT t.schemaname, t.tablename FROM pg_tables t;
      SQL
      tables_as_dicts = cache(table_sql) do
        self.class.select_all(table_sql)
      end
      tables_as_dicts.each do |table_dict|
        tables.append(table_dict["schemaname"] + "-->" + table_dict["tablename"])
      end

      group_sql = <<-SQL
        SELECT groname FROM pg_group;
      SQL
      groups_as_dicts = cache(group_sql) do
        self.class.select_all(group_sql)
      end
      groups_as_dicts.each do |group_dict|
        groups.append(group_dict["groname"])
      end

      @result = [users.sort, groups.sort, tables.sort]
    end

    #
    # retrieves users with access to the given table
    #
    def get_users_with_access(schemaname, tablename)
      # we want to find all access types every user has for the specified schema + table
      sql = <<-SQL
        SELECT u.usename AS value,
        has_table_privilege(u.usename, '%s' || '.' || '%s', 'select') AS has_select,
        has_table_privilege(u.usename, '%s' || '.' || '%s', 'delete') AS has_delete,
        has_table_privilege(u.usename, '%s' || '.' || '%s', 'update') AS has_update,
        has_table_privilege(u.usename, '%s' || '.' || '%s', 'references') AS has_references,
        has_table_privilege(u.usename, '%s' || '.' || '%s', 'insert') AS has_insert
        FROM pg_user u
        WHERE has_table_privilege(u.usename, '%s' || '.' || '%s', 'select') = true
          OR has_table_privilege(u.usename, '%s' || '.' || '%s', 'delete') = true
          OR has_table_privilege(u.usename, '%s' || '.' || '%s', 'update') = true
          OR has_table_privilege(u.usename, '%s' || '.' || '%s', 'references') = true
          OR has_table_privilege(u.usename, '%s' || '.' || '%s', 'insert') = true
          ;
      SQL
      sql = self.class.sanitize_sql(sql, [schemaname, tablename] * 10)
      __get_permissions(sql)
    end

    #
    # retrieves tables the given user has access to
    #
    def get_tables_for_user(username)
      # we want to grab all the tables and the permissions the specified user has to them
      sql = <<-SQL
        SELECT t.schemaname || '.' || t.tablename AS value,
        has_table_privilege('%s', t.schemaname || '.' || t.tablename, 'select') AS has_select,
        has_table_privilege('%s', t.schemaname || '.' || t.tablename, 'delete') AS has_delete,
        has_table_privilege('%s', t.schemaname || '.' || t.tablename, 'update') AS has_update,
        has_table_privilege('%s', t.schemaname || '.' || t.tablename, 'references') AS has_references,
        has_table_privilege('%s', t.schemaname || '.' || t.tablename, 'insert') AS has_insert
        FROM pg_tables t
        WHERE (has_table_privilege('%s', t.schemaname || '.' || t.tablename, 'select') = true
          OR has_table_privilege('%s', t.schemaname || '.' || t.tablename, 'delete') = true
          OR has_table_privilege('%s', t.schemaname || '.' || t.tablename, 'update') = true
          OR has_table_privilege('%s', t.schemaname || '.' || t.tablename, 'references') = true
          OR has_table_privilege('%s', t.schemaname || '.' || t.tablename, 'insert') = true)
          AND t.schemaname != 'pg_catalog';
      SQL
      sql = self.class.sanitize_sql(sql, [username] * 10)
      __get_permissions(sql)
    end

    #
    # retrieves tables the given group has access to
    #
    def get_tables_for_group(groupname)
      # this query is a handful.
      # it parses the ACL objects in the pg_class system table
      # ACL example: [grantee=permissions/granter, ...]
      # available permissions:
      #   r => select
      #   d => delete
      #   w => update
      #   x => reference
      #   a => insert
      #   ... for more check PG documentation
      sql = <<-SQL
        SELECT n.nspname || '.' || c.relname AS value,
          case when charindex('r', split_part(split_part(array_to_string(c.relacl, '|'), 'group %s', 2), '/', 1)) > 0 then 't' else 'f' end as has_select,
          case when charindex('d', split_part(split_part(array_to_string(c.relacl, '|'), 'group %s', 2), '/', 1)) > 0 then 't' else 'f' end as has_delete,
          case when charindex('w', split_part(split_part(array_to_string(c.relacl, '|'), 'group %s', 2), '/', 1)) > 0 then 't' else 'f' end as has_update,
          case when charindex('x', split_part(split_part(array_to_string(c.relacl, '|'), 'group %s', 2), '/', 1)) > 0 then 't' else 'f' end as has_references,
          case when charindex('a', split_part(split_part(array_to_string(c.relacl, '|'), 'group %s', 2), '/', 1)) > 0 then 't' else 'f' end as has_insert
        FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE array_to_string(relacl, '|') like '%%group %s%%';
      SQL
      sql = self.class.sanitize_sql(sql, [groupname] * 6)
      __get_permissions(sql)
    end

    private
      #
      # common method for querying permissions from RedShift and
      # transforming result into common data structure
      #
      def __get_permissions(sql)
        results = cache(sql) do
          self.class.select_all(sql)
        end
        keys = ["has_select", "has_delete", "has_update", "has_references", "has_insert"]
        results.each do |result|
          keys.each do |key|
            if result[key] == "t"
              result[key] = true
            else
              result[key] = false
            end
          end
        end
        results.sort_by { |r| r["value"] }
      end
  end
end
