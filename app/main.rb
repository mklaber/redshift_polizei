$: << File.join(File.dirname(__FILE__), '../lib')

require 'rubygems'
require 'bundler/setup'

require 'global_config'
GlobalConfig.load_config_file(:polizei, 'config/polizei.yml')

require 'sinatra'
require 'sinatra/assetpack'
require 'sinatra/activerecord'
require 'sinatra/aws'
require 'sinatra/mail'
require 'omniauth'
require 'omniauth_oauth2_strategy'
require 'mail'
require 'erubis'
require 'coderay'
require 'aws'
require 'desmond'
require 'connection_pool'
if Sinatra::Application.environment.to_sym == :staging || Sinatra::Application.environment.to_sym == :production
  require 'exception_notification'
end

require 'sql/sql'

require 'redshift/pool'

require './app/monkey_patches'
require './app/helpers'
require './app/caches'
require './app/logger'

# otherwise sinatra-assetpack craps out when building assets
Encoding.default_external = 'utf-8'  if defined?(::Encoding)

# setup before app code, so the logger can be overriden by some components
SQL.directory = File.join(File.dirname(__FILE__), 'sql')
Tilt.register Tilt::ErubisTemplate, "html.erb"
ActiveRecord::Base.logger = PolizeiLogger.logger
env = Sinatra::Application.environment.to_sym
if env == :staging || env == :production
  ActiveRecord::Base.logger = nil
end
ActiveRecord::Base.schema_format = :sql # because we are using tsvector indeces, not known by ActiveRecord
DesmondConfig.logger = PolizeiLogger.logger('desmond')

#
# tricking passenger 4.0.56 into thinking that rails/version is already loaded.
# some gems (e.g. actionmailer) define module 'Rails' leading Passenger to try
# to preload it, which fails, since this is not a rails app
#
module Rails
  module VERSION
  end
  def self.env
    Sinatra::Application.environment
  end
end

Dir.glob('./app/{models,reports,caches,jobs,utils}/**/*.rb').sort.each { |file| require file }
