module Caches
  class DynamoDBCache < BaseCache
    def initialize(options = {})
      # TODO needs connection pool or provided by AWS SDK?
      if not options.member?('table')
        raise ArgumentError, 'the option "table" is required'
      end
      @options = options
      @handle = AWS::DynamoDB.new(@options)
      @table = @handle.tables[@options['table']]
      @table.hash_key = [:id, :string]
    end

    def exists?(sql)
      return false if not self.enabled
      self.get(sql).exists?
    end

    def get(sql)
      return nil if not self.enabled
      hq = build_hash(sql)
      cache_item = table.items[hq]
      if not cache_item.exists?
        return nil
      end
      cache2cash(cache_item)
    end

    def put(sql, data)
      hq = build_hash(sql)
      cache_item = table.items.create(id: hq, sql: sql, data: data.to_json)
      cache2cash(cache_item)
    end

    private
      attr_reader :table

      def build_hash(sql, *args)
        Digest::MD5.hexdigest(sql)
      end

      def cache2cash(cache_item)
        JSON.parse(cache_item.attributes[:data])
      end
  end
end
