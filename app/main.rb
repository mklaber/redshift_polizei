require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'sinatra/assetpack'
require 'sinatra/activerecord'
require 'omniauth'
require 'omniauth/strategies/google_oauth2'
require 'mail'
require 'erubis'
require 'coderay'
require 'action_view'
require 'aws'
require 'que'
require 'action_mailer'

require './app/monkey_patches'
require './app/helpers'
require './app/caches'
require './app/awsconfig'
require './app/logger'

require './tasks/auditlog'

Dir.glob('./lib/*.rb').sort.each { |file| require file }
Dir.glob('./app/{models,reports,caches,jobs,mailers}/*.rb').sort.each { |file| require file }

Tilt.register Tilt::ErubisTemplate, "html.erb"

ActiveRecord::Base.logger = PolizeiLogger.logger
