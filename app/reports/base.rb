module Reports
  #
  # Common base class for RedShift querying.
  # Every subclass will use the configured connection
  # to RedShift 'redshift_{env}' instead of
  # the default database connection
  #
  class Base < ActiveRecord::Base
    # common base class for RedShift communication
    self.abstract_class = true
    self.establish_connection "redshift_#{Sinatra::Application.environment}".to_sym
    # even with abstract_class it looks for the table, this fixes that
    def self.columns
      @columns ||= []
    end

    # include caching helpers, since queries tend to take a bit on Redshift.
    include Caches::Helpers

    def self.inspect
      "#<#{self.to_s}>"
    end

    #
    # commong base method to cache Reports if possible
    #
    def run
      raise NotImplementedError
    end

    #
    # returns the username used for the RedShift database connection
    #
    def self.database_user
      self.connection.instance_variable_get(:@config)[:username]
    end

    #
    # executes the given SQL query on RedShift returning the results.
    # The query can be a ruby format string, `args` will be used to
    # replace the placeholders.
    #
    def self.select_all(sql, *args)
      sanitized_sql = self.sanitize_sql(sql, *args)
      self.connection.select_all(sanitized_sql)
    end

    #
    # sanitizes a SQL query using ActiveRecords `sanitize_sql_for_conditions`.
    # The query can be a ruby format string, `args` will be used to
    # replace the placeholders.
    #
    def self.sanitize_sql(a, *args)
      # if a single array was passed, use this array as sanitization arguments
      if args.size == 1 && args[0].is_a?(Array)
        placeholder_values = args[0]
      else
        placeholder_values = args
      end
      # sql query is passed at first position
      sanitize_arg = placeholder_values.insert(0, a)
      return a if sanitize_arg.size == 1 # return immediately if no parameters given (prevents errors where standalone % are in the sql)
      ActiveRecord::Base.__send__(:sanitize_sql_for_conditions, sanitize_arg, '') # last argument is a fake table_name
    end
  end
end
