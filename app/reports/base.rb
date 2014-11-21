module Reports
  class Base
    def self.inspect
      "#<#{self.to_s}>"
    end

    public
      def run
        raise NotImplementedError
      end

      def select_all(sql, *args)
        return self.class.check_cache(sql, *args)
      end

      def self.select_all(sql, *args)
        return self.check_cache(sql, *args)
      end

    private
      def self.cache
        Caches::BaseCache.cache
      end

      def self.uncached_query(sql, *args)
        sanitized_sql = self.sanitize_sql(sql, *args)
        ActiveRecord::Base.connection.select_all(sanitized_sql)
      end

      def self.check_cache(sql, *args)
        sanitized_sql = self.sanitize_sql(sql, *args)
        cache_item = cache.get(sql)
        if cache_item.nil?
          data = self.uncached_query(sanitized_sql)
          cache_item = cache.put(sql, data)
        end
        return cache_item
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
