require 'logger'
require 'fileutils'

#
# removes color escape character sequences from log messages
# and write them to file
#
class ColorBlindLogFile
  def initialize(*args)
     @target = File.new(*args, 'a')
     # easier debugging with log files
     @target.sync = true
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
  @_logger_hash = {}

  def initialize(logdev, *args)
    super(logdev, *args)
    @logdev = logdev
  end

  #
  # singleton method to retrieve logger instance
  #
  def self.logger(name='')
    if @_logger_hash[name].nil?
      # create logger
      env = Sinatra::Application.environment
      if env == :development
        # development logs to stdout
        @_logger_hash[name] = self.new STDOUT
      else
        # everything else to file
        # create log directory if it doesn't exist
        logdirectory = '../log'
        FileUtils::mkdir_p File.expand_path(logdirectory, File.dirname(__FILE__ ))
        # generate log file name
        logfile = "#{logdirectory}/#{env}#{(name.empty?) ? '' : '_' + name }.log"
        # open environment log file while removing color coding from messages
        f = File.expand_path(logfile, File.dirname(__FILE__ ))
        @_logger_hash[name] = self.new(ColorBlindLogFile.new(f), shift_age='daily')
      end
      # set up logger settings
      @_logger_hash[name].level = Logger::DEBUG
      @_logger_hash[name].datetime_format = '%FT%T.%N%z'
    end
    @_logger_hash[name]
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
