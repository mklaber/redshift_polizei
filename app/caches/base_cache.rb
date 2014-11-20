module Caches
  class BaseCache
    include Caches::Creator
    def initialize(options = {})
      raise NotImplementedError
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
