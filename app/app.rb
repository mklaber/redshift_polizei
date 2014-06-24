# home.rb
require 'sinatra'
require 'sinatra/assetpack'
require "sinatra/activerecord"
require 'monkey_patches'
require 'helpers'
require 'pony'
require 'sanitize'
require 'pg'
require 'action_view'
require 'coderay'

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
    @queries = query_report.recents
    erb :index, :locals => { :name => :home }
  end

  get '/disk_space' do
    
    disk_space_report = Reports::DiskSpace.new
    @disks = disk_space_report.get_disk_space_info
    puts @disks
    erb :disk_space, :locals => {:name => :disk_space}
    
  end

  get '/tables' do
    tables_report = Reports::Table.new
    @tables = tables_report.result
    erb :tables, :locals => { :name => :tables }
    #    @tables = Reports::Table.paginate(:page => params[:page], :per_page => 5)
    #    erb :tables, :locals => { :name => :tables }
  end

  get '/permissions' do
	
	permissions_report = Reports::Permission.new
    @users, @groups, @tables = permissions_report.result
    @p_types = ["select", "insert", "update", "delete", "references"]
    erb :permissions, :locals => { :name => :permissions }
    
  end

  get '/permissions/tables' do
    
    schemaname, tablename = params[:value].split("-->")
    permissions_report = Reports::Permission.new
    @result = permissions_report.get_users_with_access(schemaname, tablename)
    puts @result
    @result.to_json    
    
  end
    
  get '/permissions/users' do
    
    username = params[:value]
    permissions_report = Reports::Permission.new
    @result = permissions_report.get_tables_for_user(username)
    @result.to_json    
    
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
