module Caches
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
    def exists?(sql)
      raise NotImplementedError
    end
    def get(sql)
      raise NotImplementedError
    end
    def put(sql, data)
      raise NotImplementedError
    end
  end
end
