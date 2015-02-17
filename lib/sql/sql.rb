##
# class to offload (big) SQL queries into separate files
#
class SQL
  ##
  # sets where sql files are to be loaded from
  #
  class << self
    attr_accessor :directory
    @directory = File.dirname(__FILE__)
  end

  ##
  # execute the sql query found as +name+ using +connection+.
  # the extension '.sql' is automatically appended if no file
  # extension given.
  # +append+ can be used to append something to the SQL query.
  # the value of +append+ is passed to `ActiveRecord::Base.sanitize_sql_array`
  #
  def self.execute(connection, name, append: nil)
    sql  = self.load_file(name)
    sql += self.sanitize(append) unless append.nil?
    self.execute_raw(connection, sql)
  end

  ##
  # execute the given +query+ using +connection+
  #
  def self.execute_raw(connection, query)
    if connection.respond_to?(:execute) # ActiveRecord connection
      connection.execute(query)
    elsif connection.respond_to?(:exec) # PG connection
      connection.exec(query)
    else
      fail 'Unsupported connection'
    end
  end

  private

  ##
  # load sql file +name+ from the configured directory.
  # automatically append .sql if no extension given
  #
  def self.load_file(name)
    name += '.sql' if File.extname(name).empty?
    File.read(File.join(@directory, name))
  end

  ##
  # proxy for `ActiveRecord::Base.sanitize_sql_array`
  #
  def self.sanitize(*args)
    ActiveRecord::Base.send(:sanitize_sql_array, *args)
  end
end
