require 'sinatra/base'
require 'global_config'

module Sinatra
  module ConfigurationsExtension
    def self.registered(app)
      app.helpers ConfigurationsHelpers
    end

    def load_config_file(name, path)
      GlobalConfig.load_config_file(name, path)
    end

    def config(name, key=nil)
      GlobalConfig.config(name, key)
    end

    module ConfigurationsHelpers
      def config(name, key=nil)
        GlobalConfig.config(name, key)
      end
      module_function :config
    end
  end

  register ConfigurationsExtension
end
