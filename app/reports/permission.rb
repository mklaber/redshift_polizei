module Reports
  class Permission < Base
  
    attr_reader :options
  
    def initialize(unsanitized_options = {})
      # Ensure options are valid
      # this includes dealing with start_date, end_date
      @options = self.class.filter(unsanitized_options)
    end 
  	
    def result
	  
	  #We grab the select and all permissions for every pair of user and table
      sql = <<-SQL
		select u.usename, t.schemaname, t.tablename, 
		has_table_privilege(u.usename, t.schemaname || '.' || t.tablename, 'select') as has_select, 
		has_table_privilege(u.usename, t.schemaname || '.' || t.tablename, 'insert') as has_insert,
		has_table_privilege(u.usename, t.schemaname || '.' || t.tablename, 'update') as has_update,
		has_table_privilege(u.usename, t.schemaname || '.' || t.tablename, 'delete') as has_delete,
		has_table_privilege(u.usename, t.schemaname || '.' || t.tablename, 'references') as has_references
		FROM pg_user u, pg_tables t;       
      SQL
      perms = self.class.connection.select_all(self.class.sanitize([sql, @options]))
	  
	  #For each table, find all users with select and all privileges	  
	  result = Hash.new
	  perms.each do |perm|
		
		tablename = perm["tablename"]
		username = perm["usename"]
		
		select = perm["has_select"]
		insert = perm["has_insert"]
        update = perm["has_update"]
        delete = perm["has_delete"]
        references = perm["has_references"]
		
		if result[tablename] == nil
			result[tablename] = Hash.new
			result[tablename]["select"] = Set.new
			result[tablename]["update"] = Set.new
            result[tablename]["references"] = Set.new
            result[tablename]["delete"] = Set.new
			result[tablename]["insert"] = Set.new
		end
		
		if select == "t"
			result[tablename]["select"].add(username)
		end
		if insert == "t"
            result[tablename]["insert"].add(username)
        end 
        if update == "t"
            result[tablename]["update"].add(username)
        end 
		if delete == "t"
            result[tablename]["delete"].add(username)
        end 
		if references == "t"
            result[tablename]["references"].add(username)
        end 
		
	  end
      @result = result  
	end
  end
end
