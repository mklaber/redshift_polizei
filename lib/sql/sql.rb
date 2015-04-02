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
  # uses method `execute` and then groups the result into a hash.
  # the keys are determined by the given block.
  #
  def self.execute_grouped(connection, name, parameters: [], filters: {})
    results = {}
    self.execute(connection, name, parameters: parameters, filters: filters).each do |result|
      key = yield(result)
      results[key] ||= []
      results[key] << result
    end
    results
  end

  ##
  # execute the sql query found as +name+ using +connection+.
  # the extension '.sql' is automatically appended if no file
  # extension given.
  # +filters+ can be hash which will be appended as 'and key = value' filters.
  #
  def self.execute(connection, name, parameters: [], filters: {})
    self.execute_raw(connection, self.load(name, parameters: parameters, filters: filters))
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

  ##
  # loads sql query and applies +parameters+ (to `?` placeholders) and
  # appends additional +filters+.
  # +filters+ should be hash which will be appended as 'and key = value' filters.
  #
  def self.load(name, parameters: [], filters: {})
    raw_sql = self.load_file(name)
    parameters = [ parameters ] unless parameters.is_a?(Array)
    sql  = self.sanitize([ raw_sql ] + parameters)
    unless filters.nil?
      filters.each do |key, value|
        sql += self.sanitize([ " and #{key} = ?", value]) unless key.nil? || value.nil?
      end
    end
    return sql
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
