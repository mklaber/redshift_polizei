require 'sinatra/base'
require 'sinatra/configurations'
require 'pony'

module Sinatra
  module PonyMailExtension
    CONFIG_NAME = :pony_mail
    DEFAULT_CONFIG_FILE = "#{Dir.pwd}/config/mail.yml"

    def self.registered(app)
      app.register Sinatra::ConfigurationsExtension
      app.helpers PonyMailHelpers
      app.set :mail_file, DEFAULT_CONFIG_FILE if File.exists?(DEFAULT_CONFIG_FILE)
    end

    def mail_file=(path)
      c = load_config_file(CONFIG_NAME, path)
      Pony.options = c.dup.deep_symbolize_keys
    end

    def mail_config(key=nil)
      config(CONFIG_NAME, key)
    end

    module PonyMailHelpers
      def mail_config(key=nil)
        config(CONFIG_NAME, key)
      end
    end
  end

  register AWSExtension
end
