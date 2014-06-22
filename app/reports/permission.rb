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

    def get_users_with_access(schemaname, tablename, permission_type)
        
        sql = <<-SQL
            SELECT u.usename 
            FROM pg_user u, pg_tables t
            WHERE t.tablename='#{tablename}'
            AND
            t.schemaname='#{schemaname}'
            AND
            has_table_privilege(u.usename, '#{schemaname}' || '.' || '#{tablename}', '#{permission_type}') = 't';
        SQL
        
        result = []
        users = self.class.connection.select_all(self.class.sanitize([sql, @options]))
        users.each do |user|
            result.append(user["usename"])
        end
        @result = result.sort
        
    end

    def get_tables_for_user(username, permission_type)
        
        sql = <<-SQL
            SELECT t.schemaname, t.tablename 
            FROM pg_user u, pg_tables t
            WHERE u.usename='#{username}'
            AND
            has_table_privilege('#{username}', t.schemaname || '.' || t.tablename, '#{permission_type}') = 't';
        SQL
        
        result = []
        tables = self.class.connection.select_all(self.class.sanitize([sql, @options]))
        tables.each do |table|
            result.append(table["schemaname"] + "  -->  "  + table["tablename"])
        end
        @result = result.sort
        
    end



    
    
  end
end
