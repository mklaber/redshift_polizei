module Reports
  class Permission < Base

    def run
      users, groups, tables = self.result
      users.each  { |user| self.get_tables_for_user(user) }
      tables.each do |table|
        table_parts = table.split("-->")
        self.get_users_with_access(table_parts[0], table_parts[1])
      end
    end

    def result
      users, groups, tables = [], [], []

      user_sql = <<-SQL
        SELECT u.usename FROM pg_user u;
      SQL
      users_as_dicts = cache(user_sql, expires: 30) do
        self.redshift_select_all(user_sql)
      end
      users_as_dicts.each do |use_dict|
        users.append(use_dict["usename"])
      end

      table_sql = <<-SQL
        SELECT t.schemaname, t.tablename FROM pg_tables t;
      SQL
      tables_as_dicts = cache(table_sql, expires: 30) do
        self.redshift_select_all(table_sql)
      end
      tables_as_dicts.each do |table_dict|
        tables.append(table_dict["schemaname"] + "-->" + table_dict["tablename"])
      end

      group_sql = <<-SQL
        SELECT groname FROM pg_group;
      SQL
      groups_as_dicts = cache(group_sql, expires: 30) do
        self.redshift_select_all(group_sql)
      end
      groups_as_dicts.each do |group_dict|
        groups.append(group_dict["groname"])
      end

      @result = [users.sort, groups.sort, tables.sort]
    end

    def get_users_with_access(schemaname, tablename)
      #We want to find all access types every user has for the specified schema + table
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
      sql = self.sanitize_sql(sql, [schemaname, tablename] * 10)

      #We want to grab the sql results and map t --> "Yes" and f --> "No"
      keys = ["has_select", "has_delete", "has_update", "has_references", "has_insert"]
      results = cache(sql, expires: 30) do
        self.redshift_select_all(sql)
      end
      results.each do |result|
        keys.each do |key|
          if result[key] == "t"
            result[key] = "Yes"
          else
            result[key] = "No"
          end
        end
      end
      @results = results.sort_by { |r| r["value"] }
    end

    def get_tables_for_user(username)
      #We want to grab all the tables and the permissions the specified user has to them
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
      sql = self.sanitize_sql(sql, [username] * 10)

      #We want to grab the sql results and map t --> "Yes" and f --> "No"
      keys = ["has_select", "has_delete", "has_update", "has_references", "has_insert"]
      results = cache(sql, expires: 30) do
        self.redshift_select_all(sql)
      end
      results.each do |result|
        keys.each do |key|
          if result[key] == "t"
            result[key] = "Yes"
          else
            result[key] = "No"
          end
        end
      end
      @results = results.sort_by { |r| r["value"] }
    end
  end
end
