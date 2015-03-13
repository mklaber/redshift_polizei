require 'sinatra/base'
require 'sinatra/configurations'
require 'aws'

module Sinatra
  module AWSExtension
    CONFIG_NAME = :aws
    DEFAULT_CONFIG_FILE = "#{Dir.pwd}/config/aws.yml"

    def self.registered(app)
      app.register Sinatra::ConfigurationsExtension
      #app.helpers AWSHelpers
      app.set :aws_file, DEFAULT_CONFIG_FILE if File.exists?(DEFAULT_CONFIG_FILE)
    end

    def aws_file=(path)
      c = load_config_file(CONFIG_NAME, path)
      if c.has_key?('access_key_id') && c.has_key?('secret_access_key')
        AWS.config({
          access_key_id: c['access_key_id'],
          secret_access_key: c['secret_access_key']
        })
      end
    end

    #def aws_config(key=nil)
    #  config(CONFIG_NAME, key)
    #end

    #module AWSHelpers
    #  def aws_config(key=nil)
    #    config(CONFIG_NAME, key)
    #  end
    #end
  end

  register AWSExtension
end
