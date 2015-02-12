require 'aws'

module Caches
  #
  # uses AWS DynamoDB as a cache
  #
  # expects the following options on initialization:
  # - table: name of the table to use (will not be autocreated)
  #
  # the table will have the following structure:
  # - id: hash of the cache id (configure this as the hash key)
  # - data: cached data in JSON format
  # - expires: expiration date as iso8601 string
  # - id_plain: unhashed cache id
  #
  class DynamoDBCache < BaseCache
    def initialize(options = {})
      if not options.member?('table')
        raise ArgumentError, 'the option "table" is required'
      end
      super(options)
      @handle = AWS::DynamoDB.new
      # check that the given table is valid, will throw NoSuchMethodError if not
      table
    end

    def exists?(id, options={})
      return false if not self.enabled
      not(self.get(id, options).nil?)
    end

    def get(id, options={})
      return nil if not self.enabled
      hq = self.build_hash(id)
      table = self.table(options)
      cache_item = table.items[hq]
      if not cache_item.exists?
        return nil
      end
      return nil if self.expired?(cache_item.attributes[:expires], options)
      cache2cash(cache_item)
    end

    def put(id, data, options={})
      hq = self.build_hash(id)
      table = self.table(options)
      cache_data = { id: hq, id_plain: id, data: data.to_json }
      cache_data[:expires] = self.expires_str(options)
      cache_item = table.items.create(cache_data)
      cache2cash(cache_item)
    end

    protected
      def table(options = {})
        t = @handle.tables[self.options(options)['table']]
        t.hash_key = [:id, :string]
        t
      end

      #
      # builds the hash of the cache id
      #
      def build_hash(sql)
        Digest::MD5.hexdigest(sql)
      end

      #
      # transforms DynamoDB Object into JSON
      #
      def cache2cash(cache_item)
        JSON.load(cache_item.attributes[:data])
      end
  end
end
