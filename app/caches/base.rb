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
    include Caches::Creator
    def initialize(options = {})
      raise NotImplementedError
    end
    def disable
      @enabled = false
    end
    def enable
      @enabled = true
    end
    def enabled
      return true if @enabled.nil?
      @enabled
    end
    def exists?(sql, options={})
      raise NotImplementedError
    end
    def get(sql, options={})
      raise NotImplementedError
    end
    def put(sql, data, options={})
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
