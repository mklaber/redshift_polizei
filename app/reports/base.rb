module Reports
  class Base
    include Caches::Helpers

    def self.inspect
      "#<#{self.to_s}>"
    end

    def run
      raise NotImplementedError
    end

    def redshift_select_all(sql, *args)
      return self.class.redshift_select_all(sql, *args)
    end

    def sanitize_sql(sql, *args)
      return self.class.sanitize_sql(sql, *args)
    end

    def self.redshift_user
      with_redshift do
        ActiveRecord::Base.connection.instance_variable_get(:@config)[:username]
      end
    end

    def self.redshift_select_all(sql, *args)
      with_redshift do
        sanitized_sql = self.sanitize_sql(sql, *args)
        ActiveRecord::Base.connection.select_all(sanitized_sql)
      end
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
      return a if sanitize_arg.size == 1 # return immediately if no parameters given (prevents errors where standalone % are in the sql)
      ActiveRecord::Base.__send__(:sanitize_sql_for_conditions, sanitize_arg, '') # last argument is a fake table_name
    end

    private
      def self.redshift_connection_env
        "redshift_#{Sinatra::Application.environment}".to_sym
      end

      def self.with_redshift
        # connect to redshift temporarly
        redshift_conn_id = redshift_connection_env
        conn_pool = ActiveRecord::Base.establish_connection(redshift_conn_id)
        yield
      ensure
        # user normal database connection afterwards
        ActiveRecord::Base.establish_connection(Sinatra::Application.environment)
      end
  end
end
