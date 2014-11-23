require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'sinatra/assetpack'
require 'sinatra/activerecord'
require 'erubis'
require 'coderay'
require 'action_view'
require 'aws'

require './app/monkey_patches'
require './app/helpers'
require './app/caches'

Dir.glob('./app/{models,reports,caches}/*.rb').sort.each { |file| require file }
