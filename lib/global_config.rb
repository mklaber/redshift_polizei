require 'active_support'
require 'yaml'

class GlobalConfig
  ENVS = %w[test production staging development]

  def self.reset!
    @config = {}
    @env = nil
  end
  def self.env=(env)
    @env = env
  end
  def self.env
    @env || ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
  end
  def self.load_config_file(name, path)
    raise "Configuration file '#{path}' doesn't exist!" if not(File.exists?(path))
    # load config & defaults
    config = YAML::load_file(path)
    defaults = load_defaults(path)
    # get environment specific config & defaults
    defaults = retrieve_env_config(defaults) if defaults.keys.include?(self.env.to_s)
    config = retrieve_env_config(config) if config.keys.include?(self.env.to_s)
    # merge config & defaults
    config = defaults.merge(config)
    # done laoding
    config.freeze
    load_config(name, config)
  end
  def self.config(name, key=nil)
    return nil unless @config.has_key?(name.to_sym)
    if key.nil?
      ActiveSupport::HashWithIndifferentAccess.new @config[name.to_sym]
    else
      @config[name.to_sym][key.to_s]
    end
  end
  def self.[](name, key=nil)
    self.config(name, key)
  end
  def self.respond_to?(symbol, include_all=false)
    super || @config.has_key?(symbol.to_sym)
  end
  def self.method_missing(symbol=nil, *args)
    return self.config(symbol, *args) if !symbol.nil? && @config.has_key?(symbol.to_sym)
    super
  end


  def self.load_config(name, config)
    @config ||= {}
    @config[name.to_sym] = config
  end
  private_class_method :load_config

  def self.load_defaults(path)
    defaults_file = File.join(
      File.dirname(path),
      File.basename(path, File.extname(path)) + '.sample' + File.extname(path)
    )
    return {} if not(File.exists?(defaults_file))
    return YAML::load_file(defaults_file)
  end
  private_class_method :load_defaults

  def self.retrieve_env_config(config)
    env_config = config.delete(self.env.to_s)
    tmp = config.select { |key, value| !ENVS.include?(key) }
    tmp.merge(env_config)
  end
  private_class_method :retrieve_env_config
end
