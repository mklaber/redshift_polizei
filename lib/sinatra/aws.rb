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
      app.set :aws_config_file, DEFAULT_CONFIG_FILE if File.exists?(DEFAULT_CONFIG_FILE)
    end

    def aws_config_file=(path)
      c = load_config_file(CONFIG_NAME, path)
      if c.has_key?('aws_access_key_id') && c.has_key?('aws_secret_access_key')
        AWS.config({
          access_key_id: c['aws_access_key_id'],
          secret_access_key: c['aws_secret_access_key'],
          region: c['aws_region'],
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
