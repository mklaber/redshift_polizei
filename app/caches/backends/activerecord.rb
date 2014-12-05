module Caches
  #
  # uses ActiveRecord Model as a cache
  #
  # expects the following options on initialization:
  # - table: full class name of the Model class to use
  #
  # the model class has to have the following schema:
  # - hashid: string, hash of the cache id (configure this as an index)
  # - data: json, json representation of the data
  # - expires: integer, unix timestamp of the expiration date
  #
  class ActiveRecordCache < BaseCache
    def initialize(options = {})
      # without the 'table' nothing can be done
      if not options.member?('table')
        raise ArgumentError, 'the option "table" is required'
      end
      super(options)
      # check that the given table is valid, will throw NameError if not
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
      cache_item = table.find_by(hashid: hq)
      if cache_item.nil?
        return nil
      end
      return nil if self.expired?(cache_item[:expires], options)
      cache_item[:data]
    end

    def put(id, data, options={})
      hq = self.build_hash(id)
      table = self.table(options)
      cache_item = table.find_by(hashid: hq)
      if cache_item.nil?
        cache_item = table.new({ hashid: hq })
      end
      cache_item.data = data.to_json
      cache_item.expires = self.expires_i(options)
      cache_item.save
      cache_item[:data]
    end

    protected
      def table(options = {})
        self.options(options)['table'].constantize
      end

      #
      # builds the hash of the cache id
      #
      def build_hash(sql, *args)
        Digest::MD5.hexdigest(sql)
      end
  end
end
