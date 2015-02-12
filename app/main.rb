$: << File.join(File.dirname(__FILE__), '../lib')

require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'sinatra/assetpack'
require 'sinatra/activerecord'
require 'sinatra/aws'
require 'sinatra/mail'
require 'omniauth'
require 'omniauth/strategies/google_oauth2'
require 'mail'
require 'erubis'
require 'coderay'
require 'aws'
require 'desmond'

require './app/monkey_patches'
require './app/helpers'
require './app/caches'
require './app/logger'

Dir.glob('./lib/*.rb').sort.each { |file| require file }
Dir.glob('./app/{models,reports,caches,jobs,mailers}/*.rb').sort.each { |file| require file }
Dir.glob('./tasks/*.rb').sort.each { |file| require file }

Tilt.register Tilt::ErubisTemplate, "html.erb"

ActiveRecord::Base.logger = PolizeiLogger.logger
ActiveRecord::Base.schema_format = :sql # because we are using tsvector indeces, not known by ActiveRecord

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
