require_relative 'creator'

module Caches
  ##
  # Base class for interacting with caches.
  #
  # use 'Caches::BaseCache.cache' to get an instance of the cache configured
  # in 'config/cache.yml'
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
      def expires(options={})
        return nil if not options.has_key?(:expires)
        return (Time.now + options[:expires]).iso8601
      end
      def expired?(expires, options={})
        return true if expires.nil? && options.has_key?(:expires)
        return false if expires.nil? && (not options.has_key?(:expires))
        return (Time.iso8601(expires) <= Time.now)
      end
  end
end
