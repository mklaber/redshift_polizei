require 'sinatra/base'
require 'sinatra/configurations'
require 'pony'
begin
  require 'action_mailer'
rescue LoadError => e
  # ignoring
end

module Sinatra
  module PonyMailExtension
    CONFIG_NAME = :pony_mail
    DEFAULT_CONFIG_FILE = "#{Dir.pwd}/config/mail.yml"

    def self.registered(app)
      app.register Sinatra::ConfigurationsExtension
      app.helpers PonyMailHelpers
      app.set :mail_config_file, DEFAULT_CONFIG_FILE if File.exists?(DEFAULT_CONFIG_FILE)
    end

    def mail_config_file=(path)
      c = load_config_file(CONFIG_NAME, path)
      Pony.options = c.dup.deep_symbolize_keys[:mail] || {}
      if Object.const_defined?('ActionMailer') && Pony.options.size > 0
        ActionMailer::Base.delivery_method = Pony.options[:via].to_sym
        ActionMailer::Base.smtp_settings = Pony.options[:via_options]
      end
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
