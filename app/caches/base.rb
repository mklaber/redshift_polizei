require_relative 'creator'
require 'time'

module Caches
  ##
  # Base interface for all caches.
  # Use Helper method from 'cacheable' to use cache
  #
  # use 'Caches::BaseCache.cache' to get an instance of the cache configured
  # in 'config/cache.yml'
  #
  # new cache implementations using this interface need to implement:
  # - exists?
  # - get
  # - put
  # new cache implementations need to check self.enabled at the beginning of these
  # methods. If it returns false, assume cache is empty
  # new cache implementations should use the following helpers for expirations calculations:
  # - expires_str
  # - expires_i
  # - expires?
  #
  class BaseCache
    #
    # mixin `cache` method to create cache
    # instances from configuration
    #
    include Caches::Creator

    #
    # init method of cache, this interface can't be instantiated
    #
    def initialize(options = {})
      raise NotImplementedError
    end
    #
    # disables cache, making every `exists?` or
    # `get` request a cache miss
    #
    def disable
      @enabled = false
    end
    #
    # puts cache into normal operating mode
    # see `disable` method for differences
    #
    def enable
      @enabled = true
    end
    #
    # returns boolean whether cache is enabled
    # see `disable` method for differences
    #
    def enabled
      return true if @enabled.nil?
      @enabled
    end
    #
    # returns boolean whether id `id` has data in the cache
    #
    def exists?(id, options={})
      raise NotImplementedError
    end
    #
    # retrieves cache data saved with id `id`
    # returns nil if not found
    #
    def get(id, options={})
      raise NotImplementedError
    end
    #
    # put `data` into cache with id `id`
    # returns `data` from cache afterwards
    #
    def put(id, data, options={})
      raise NotImplementedError
    end
    protected
      #
      # parses a expiration date string in iso8601 format to a Time instance
      #
      def expires_str(options={})
        return nil if not options.has_key?(:expires)
        return (Time.now + options[:expires]).iso8601
      end
      #
      # parses a unix timestamp to a Time instance
      #
      def expires_i(options={})
        return nil if not options.has_key?(:expires)
        return (Time.now + options[:expires]).utc.to_i
      end
      #
      # checks whether the given expiration time is expired given
      # the passed options
      #
      def expired?(expires, options={})
        return true if expires.nil? && options.has_key?(:expires)
        return false if expires.nil? && (not options.has_key?(:expires))
        if expires.is_a?(String)
          return (Time.iso8601(expires) <= Time.now)
        else
          return (Time.at(expires) <= Time.now)
        end
      end
  end
end
