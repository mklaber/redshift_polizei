require_relative 'base'

module Caches
  module Helpers
    #
    # helper method to use cache
    #
    # checks if cache contains valid 'cache_id'
    # - yes: returns it from cache
    # -  no: executes supplied block, saves its result under 'cache_id' in the cache and returns it
    # when the cache expierences a failure, the block will get executed
    #
    # supported options:
    # - expires: number of seconds the cache entry shall be valid
    #
    def cache(cache_id, options={}, &block)
      cache_item = nil
        # if the cache experiences a failure, use the supplied block
      begin
        cache = Caches::BaseCache.cache
        cache_item = cache.get(cache_id)
      rescue
        PolizeiLogger.logger.exception $!
      end
      if cache_item.nil?
        # call block if cache_id not found in cache
        data = block.call
        # if the cache experiences a failure, log it and return the original data
        begin
          cache_item = cache.put(cache_id, data, options)
        rescue
          PolizeiLogger.logger.exception $!
          cache_item = data.to_json
        end
      end
      cache_item
    end
  end
end
