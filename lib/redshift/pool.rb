require 'redshift/util'
require 'connection_pool'

class RSPool
  def self.get
    if @pool.nil?
      @pool = ConnectionPool.new { RSUtil.dedicated_connection(system_connection_allowed: true) }
    end
    @pool
  end

  def self.with(&block)
    self.get.with { |c| block.call(c) }
  end
end
