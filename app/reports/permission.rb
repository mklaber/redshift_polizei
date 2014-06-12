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
		has_table_privilege(u.usename, t.schemaname || '.' || t.tablename, 'delete') as has_all
		FROM pg_user u, pg_tables t;       
      SQL
      perms = self.class.connection.select_all(self.class.sanitize([sql, @options]))
	  
	  #For each table, find all users with select and all privileges	  
	  result = Hash.new
	  perms.each do |perm|
		
		tablename = perm["tablename"]
		username = perm["usename"]
		select = perm["has_select"]
		all = perm["has_all"]
		
		if result[tablename] == nil
			result[tablename] = Hash.new
			result[tablename]["all"] = Set.new
			result[tablename]["select"] = Set.new 
		end
		
		if select == "t"
			result[tablename]["select"].add(username)
		end
		if all == "t"
			result[tablename]["all"].add(username)
		end
		
	  end	  
      @result = result  
	end
  end
end
