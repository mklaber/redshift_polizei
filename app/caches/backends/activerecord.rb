module Caches
  class ActiveRecordCache < BaseCache
    def initialize(options = {})
      if not options.member?('table')
        raise ArgumentError, 'the option "table" is required'
      end
      @options = options
      @table = @options['table'].constantize
    end

    def exists?(id, options={})
      return false if not self.enabled
      not(self.get(id).nil?)
    end

    def get(id, options={})
      return nil if not self.enabled
      hq = build_hash(id)
      cache_item = table.find_by(hashid: hq)
      if cache_item.nil?
        return nil
      end
      return nil if self.expired?(cache_item[:expires], options)
      cache_item[:data]
    end

    def put(id, data, options={})
      hq = build_hash(id)
      cache_item = table.find_by(hashid: hq)
      if cache_item.nil?
        cache_item = table.new({ hashid: hq })
      end
      cache_item.data = data.to_json
      cache_item.expires = self.expires_i(options) if options.has_key?(:expires)
      p "!!! cache_item: #{cache_item}"
      cache_item.save
      cache_item[:data]
    end

    private
      attr_reader :table

      def build_hash(sql, *args)
        Digest::MD5.hexdigest(sql)
      end
  end
end
