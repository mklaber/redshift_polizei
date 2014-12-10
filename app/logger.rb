require 'logger'

class MultiIO
  def initialize(*targets)
     @targets = targets
  end

  def write(*args)
    @targets.each {|t| t.write(*args)}
  end

  def flush
    @targets.each do |t|
      t.flush if t.respond_to? :flush
    end
  end

  def close
    @targets.each(&:close)
  end
end

#
# common Logger for Sinatra, ActiveRecord and everything else
#
class PolizeiLogger < Logger
  def initialize(logdev)
    super
    @logdev = logdev
  end

  #
  # singleton method
  #
  def self.logger
    if @_logger.nil?
      logfile = "../log/#{Sinatra::Application.environment}.log"
      f = File.open(File.expand_path(logfile, File.dirname(__FILE__ )), "a")
      @_logger = self.new MultiIO.new(STDOUT, f)
      @_logger.level = Logger::DEBUG
      @_logger.datetime_format = '%FT%T.%N%z'
    end
    @_logger
  end

  # Rack expects a write method for its logger
  alias :write :'<<'
  alias :puts :'<<'

  def flush
    @logdev.flush
  end

  #
  # convenience method to log an exception
  #
  def exception(e)
    self.error e.message + "\n " + e.backtrace.join("\n ")
  end
end
