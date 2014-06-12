# home.rb
require 'sinatra'
require 'sinatra/assetpack'
require "sinatra/activerecord"
require 'monkey_patches'
require 'helpers'
require 'pony'
require 'sanitize'
require 'pg'

class Polizei < Sinatra::Application
  include ActionView::Helpers::NumberHelper
  
  set :root, File.dirname(__FILE__)
  register Sinatra::AssetPack
  #register Sinatra::ActiveRecordExtension
  enable :sessions

  assets do
    serve '/javascripts',    from: 'assets/javascripts'   # Optional
    serve '/stylesheets',    from: 'assets/stylesheets'   # Optional
    serve '/images',         from: 'assets/images'        # Optional
    serve '/fonts',         from: 'assets/fonts'        # Optional

    # The second parameter defines where the compressed version will be served.
    # (Note: that parameter is optional, AssetPack will figure it out.)
    js :application, '/javascripts/application.js', [
      '/javascripts/lib/jquery-1.10.2.min.js',
      '/javascripts/lib/bootstrap.min.js',
      '/javascripts/shared.js'
    ]
    css :application, '/stylesheets/application.css', [
      '/stylesheets/lib/bootstrap.min.css',
      '/stylesheets/lib/font-awesome.min.css',
      '/stylesheets/lib/font-awesome.min.css',
      '/stylesheets/lib/animations.css',
      '/stylesheets/screen.css'
    ]
    js_compression  :jsmin       # Optional
    css_compression :simple      # Optional

    prebuild true
  end

  get '/' do

    query_report = Reports::Query.new
    # @queries = query_report.inflight.to_hash + query_report.recents.to_hash
    @queries = query_report.recents.to_hash

    tables_report = Reports::Table.new
    @tables = tables_report.result

    permissions_report = Reports::Permission.new
    @permissions = permissions_report.result 
    @permission_headers = ["Table", "Select Access", "All Access"]

    erb :index, :locals => { :name => :home }

  end

  not_found do
    @error = 'This is nowhere to be found.'
    erb :error
  end

  error do
    @error = 'Sorry, there was a nasty error - ' + env['sinatra.error'].name.to_s
    erb :error
  end

  # start the server if ruby file executed directly
  run! if app_file == $0

end
