require 'sinatra/base'

module Sinatra
  class Configurations
    def self.load_config(name, config)
      @config ||= {}
      @config[name.to_sym] = config
    end
    def self.load_config_file(name, path)
      raise "Configuration file '#{path}' doesn't exist!" if not(File.exists?(path))
      config = YAML::load_file(path)
      config.freeze
      self.load_config(name, config)
    end
    def self.config(name, key=nil)
      if key.nil?
        @config[name.to_sym]
      else
        @config[name.to_sym][key.to_s]
      end
    end
    def self.[](name, key=nil)
      self.config(name, key)
    end
    def self.respond_to?(symbol, include_all=false)
      super(symbol, include_all) || @config.has_key?(symbol.to_sym)
    end
    def self.method_missing(symbol, *args)
      self.config(symbol, *args)
    end
  end
  module ConfigurationsExtension
    def self.registered(app)
      app.helpers ConfigurationsHelpers
    end

    def load_config_file(name, path)
      Configurations.load_config_file(name, path)
    end

    def config(name, key=nil)
      Configurations.config(name, key)
    end

    module ConfigurationsHelpers
      def config(name, key=nil)
        Configurations.config(name, key)
      end
    end
  end

  register ConfigurationsExtension
end
