require 'aws'

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

    def exists?(id, options={})
      return false if not self.enabled
      not(self.get(id).nil?)
    end

    def get(id, options={})
      return nil if not self.enabled
      hq = build_hash(id)
      cache_item = table.items[hq]
      if not cache_item.exists?
        return nil
      end
      return nil if self.expired?(cache_item.attributes[:expires], options)
      cache2cash(cache_item)
    end

    def put(id, data, options={})
      hq = build_hash(id)
      cache_data = { id: hq, id_plain: id, data: data.to_json }
      cache_data[:expires] = self.expires_str(options) if options.has_key?(:expires)
      cache_item = table.items.create(cache_data)
      cache2cash(cache_item)
    end

    private
      attr_reader :table

      def build_hash(sql, *args)
        Digest::MD5.hexdigest(sql)
      end

      def cache2cash(cache_item)
        JSON.load(cache_item.attributes[:data])
      end
  end
end
