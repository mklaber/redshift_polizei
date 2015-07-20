require 'redshift/util'
require 'connection_pool'

class RSPool
  RSPOOL_RECONNECT_RETRIES = 1
  def self.get
    if @pool.nil?
      reconnect!
    end
    @pool
  end

  def self.with(&block)
    tries ||= RSPOOL_RECONNECT_RETRIES
    begin
      self.get.with { |c| block.call(c) }
    rescue PG::UnableToSend, PG::ConnectionBad
      tries -= 1
      if tries >= 0
        reconnect!
        retry
      end
      raise
    end
  end

  def self.reconnect!
    @pool = ConnectionPool.new { RSUtil.dedicated_connection(system_connection_allowed: true, 'timeout' => 10) }
  end
  private_class_method :reconnect!
end
