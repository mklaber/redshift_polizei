module Reports
  
  class Permission < Base
  
    attr_reader :options
  
    def initialize(unsanitized_options = {})
      # Ensure options are valid
      # this includes dealing with start_date, end_date
      @options = self.class.filter(unsanitized_options)
    end 
  	
    def result
	    
        users, groups, tables = [], [], []

        user_sql = <<-SQL
            SELECT u.usename FROM pg_user u;
        SQL
        
        table_sql = <<-SQL
            SELECT t.schemaname, t.tablename FROM pg_tables t;
        SQL
        
        group_sql = <<-SQL
            SELECT groname FROM pg_group;
        SQL
        
        users_as_dicts = self.class.connection.select_all(self.class.sanitize([user_sql, @options])) 
        users_as_dicts.each do |use_dict|
            users.append(use_dict["usename"])
        end

        tables_as_dicts = self.class.connection.select_all(self.class.sanitize([table_sql, @options]))
        tables_as_dicts.each do |table_dict|
            tables.append(table_dict["schemaname"] + "-->" + table_dict["tablename"])
        end
        
        groups_as_dicts = self.class.connection.select_all(self.class.sanitize([group_sql, @options]))
        groups_as_dicts.each do |group_dict|
            groups.append(group_dict["groname"])
        end
        
        @result = [users.sort, groups.sort, tables.sort]
	
    end

    def get_users_with_access(schemaname, tablename)
        
        #We want to find all access types every user has for the specified schema + table
        sql = <<-SQL
            SELECT u.usename AS value,
            has_table_privilege(u.usename, '#{schemaname}' || '.' || '#{tablename}', 'select') AS has_select,    
            has_table_privilege(u.usename, '#{schemaname}' || '.' || '#{tablename}', 'delete') AS has_delete,
            has_table_privilege(u.usename, '#{schemaname}' || '.' || '#{tablename}', 'update') AS has_update,
            has_table_privilege(u.usename, '#{schemaname}' || '.' || '#{tablename}', 'references') AS has_references,
            has_table_privilege(u.usename, '#{schemaname}' || '.' || '#{tablename}', 'insert') AS has_insert
            FROM pg_user u
            WHERE has_table_privilege(u.usename, '#{schemaname}' || '.' || '#{tablename}', 'select') = true
                OR has_table_privilege(u.usename, '#{schemaname}' || '.' || '#{tablename}', 'delete') = true
                OR has_table_privilege(u.usename, '#{schemaname}' || '.' || '#{tablename}', 'update') = true
                OR has_table_privilege(u.usename, '#{schemaname}' || '.' || '#{tablename}', 'references') = true
                OR has_table_privilege(u.usename, '#{schemaname}' || '.' || '#{tablename}', 'insert') = true
                ;
        SQL
        
        #We want to grab the sql results and map t --> "Yes" and f --> "No"
        keys = ["has_select", "has_delete", "has_update", "has_references", "has_insert"]
        results = self.class.connection.select_all(self.class.sanitize([sql, @options]))
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
            has_table_privilege('#{username}', t.schemaname || '.' || t.tablename, 'select') AS has_select,    
            has_table_privilege('#{username}', t.schemaname || '.' || t.tablename, 'delete') AS has_delete,
            has_table_privilege('#{username}', t.schemaname || '.' || t.tablename, 'update') AS has_update,
            has_table_privilege('#{username}', t.schemaname || '.' || t.tablename, 'references') AS has_references,
            has_table_privilege('#{username}', t.schemaname || '.' || t.tablename, 'insert') AS has_insert
            FROM pg_tables t
            WHERE (has_table_privilege('#{username}', t.schemaname || '.' || t.tablename, 'select') = true
                OR has_table_privilege('#{username}', t.schemaname || '.' || t.tablename, 'delete') = true
                OR has_table_privilege('#{username}', t.schemaname || '.' || t.tablename, 'update') = true
                OR has_table_privilege('#{username}', t.schemaname || '.' || t.tablename, 'references') = true
                OR has_table_privilege('#{username}', t.schemaname || '.' || t.tablename, 'insert') = true)
                AND t.schemaname != 'pg_catalog';
        SQL
        
        #We want to grab the sql results and map t --> "Yes" and f --> "No"
        keys = ["has_select", "has_delete", "has_update", "has_references", "has_insert"]
        results = self.class.connection.select_all(self.class.sanitize([sql, @options]))
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
