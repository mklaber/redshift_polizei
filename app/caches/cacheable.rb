require_relative 'base'

module Caches
  module Helpers
    def cache(cache_id, options={}, &block)
      cache = Caches::BaseCache.cache
      cache_item = cache.get(cache_id)
        if cache_item.nil?
          # call block if cache_id not found in cache
          data = block.call
          cache_item = cache.put(cache_id, data, options)
        end
        cache_item
    end
  end
end
