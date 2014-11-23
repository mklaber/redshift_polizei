module Reports
  class Base
    include Caches::Helpers

    def self.inspect
      "#<#{self.to_s}>"
    end

    def run
      raise NotImplementedError
    end

    def select_all(sql, *args)
      return self.class.select_all(sql, *args)
    end

    def sanitize_sql(sql, *args)
      return self.class.sanitize_sql(sql, *args)
    end

    def self.select_all(sql, *args)
      sanitized_sql = self.sanitize_sql(sql, *args)
      ActiveRecord::Base.connection.select_all(sanitized_sql)
    end

    def self.sanitize_sql(a, *args)
      # if a single array was passed, use this array as sanitization arguments
      if args.size == 1 && args[0].is_a?(Array)
        placeholder_values = args[0]
      else
        placeholder_values = args
      end
      # sql query is passed at first position
      sanitize_arg = placeholder_values.insert(0, a)
      ActiveRecord::Base.__send__(:sanitize_sql_for_conditions, sanitize_arg, '') # last argument is a fake table_name
    end
  end
end
