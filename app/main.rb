require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'sinatra/assetpack'
require 'sinatra/activerecord'
require 'ar-octopus'
require 'omniauth'
require 'omniauth/strategies/google_oauth2'
require 'mail'
require 'erubis'
require 'coderay'
require 'action_view'
require 'aws'

require './app/monkey_patches'
require './app/helpers'
require './app/caches'
require './app/awsconfig'

Dir.glob('./app/{models,reports,caches}/*.rb').sort.each { |file| require file }
