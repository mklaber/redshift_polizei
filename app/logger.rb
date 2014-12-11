require 'logger'

#
# Passes IO actions to multiple IO backends
#
class MultiIO
  def initialize(*targets)
     @targets = targets
  end

  def write(*args)
    @targets.each {|t| t.write(*args)}
  end

  def flush
    @targets.each do |t|
      # not every backend will support flush
      t.flush if t.respond_to? :flush
    end
  end

  def close
    @targets.each(&:close)
  end
end

#
# removes color escape character sequence from string
#
class ColorBlind
  def initialize(*targets)
     @targets = targets
  end

  def write(*args)
    @targets.each {|t| t.write(*args.map {|x| x.gsub(/\e\[(\d+)m/, '')}.compact)}
  end

  def flush
    @targets.each do |t|
      # not every backend will support flush
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
      env = Sinatra::Application.environment
      logfile = "../log/#{env}.log"
      # open environment log file while removing color coding from messages
      f = File.open(File.expand_path(logfile, File.dirname(__FILE__ )), "a")
      # synchronous log file IO for development
      f.sync = true if env == :development
      fc = ColorBlind.new(f)
      # set up logger
      @_logger = self.new MultiIO.new(STDOUT, fc)
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
