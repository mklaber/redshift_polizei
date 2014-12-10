require 'logger'

#
# common Logger for Sinatra, ActiveRecord and everything else
#
class PolizeiLogger < Logger
  #
  # singelton method
  #
  def self.logger
    if @_logger.nil?
      @_logger = self.new STDOUT
      @_logger.level = Logger::DEBUG
      @_logger.datetime_format = '%FT%T.%N%z'
    end
    @_logger
  end

  # Rack expects a write method for its logger
  alias :write :'<<'
  alias :puts :'<<'

  def flush
    # TODO needed on deployment machine
  end

  #
  # convenience method to log an exception
  #
  def exception(e)
    self.error e.message + "\n " + e.backtrace.join("\n ")
  end
end
