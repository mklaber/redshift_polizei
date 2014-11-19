module Reports
  class Base

    def initialize(attributes={})
      attributes && attributes.each do |name, value|
        send("#{name}=", value) if respond_to? name.to_sym 
      end
    end

    public
      def self.inspect
        "#<#{ self.to_s} #{ self.attributes.collect{ |e| ":#{ e }" }.join(', ') }>"
      end

      def select_all(sql, *args)
        self.class.select_all(sql, *args)
      end

      def self.select_all(sql, *args)
        sanitized_sql = self.sanitize(sql, *args)
        self.connection.select_all(sanitized_sql)
      end

    private
      def self.connection
        ActiveRecord::Base.connection
      end

      def self.sanitize(a, *args)
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
