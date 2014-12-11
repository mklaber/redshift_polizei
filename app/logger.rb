require 'logger'
require 'fileutils'

#
# removes color escape character sequences from log messages
# and write them to file
#
class ColorBlindFile
  def initialize(*args)
     @target = File.new(*args)
  end

  def write(*args)
    @target.write(*args.map {|x| x.gsub(/\e\[(\d+)m/, '')}.compact)
  end

  def flush
    @target.flush if @target.respond_to? :flush
  end

  def close
    @target.close
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
  # singleton method to retrieve logger instance
  #
  def self.logger
    if @_logger.nil?
      # create logger
      env = Sinatra::Application.environment
      if env == :development
        # development logs to stdout
        @_logger = self.new STDOUT
      else
        # everything else to file
        # create log directory if it doesn't exist
        logdirectory = '../log'
        FileUtils::mkdir_p File.expand_path(logdirectory, File.dirname(__FILE__ ))
        # generate log file name
        logfile = "#{logdirectory}/#{env}.log"
        # open environment log file while removing color coding from messages
        f = File.open(File.expand_path(logfile, File.dirname(__FILE__ )), "a")
        @_logger = self.new(ColorBlind.new(f), shift_age='daily')
      end
      # set up logger settings
      @_logger.level = Logger::DEBUG
      @_logger.datetime_format = '%FT%T.%N%z'
    end
    @_logger
  end

  # Rack expects a write, puts and flush method for its logger
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
