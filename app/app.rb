require './app/main'

class Polizei < Sinatra::Application
  include ActionView::Helpers::NumberHelper
  AUTH_CONFIG = YAML::load_file(File.join('config', 'auth.yml'))
  
  set :root, File.dirname(__FILE__)
  register Sinatra::AssetPack
  enable :sessions

  # setup the custom logger
  configure do
    # disable Sinatra's default
    set :logging, nil
    # set activerecords logger
    ActiveRecord::Base.logger = PolizeiLogger.logger
  end
  # set logger in environment variable for rack to pick it up
  before do
    env['rack.logger'] = PolizeiLogger.logger
    env['rack.errors'] = PolizeiLogger.logger
  end

  # configure OAuth authentication
  use OmniAuth::Builder do
    provider AUTH_CONFIG['provider'], AUTH_CONFIG['client_id'], AUTH_CONFIG['client_secret']
  end

  # configure asset pipeline
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
      '/javascripts/lib/jquery.dataTables.min.js',
      '/javascripts/lib/dataTables.bootstrap.min.js',
      '/javascripts/shared.js'
    ]
    css :application, '/stylesheets/application.css', [
      '/stylesheets/lib/bootstrap.min.css',
      '/stylesheets/lib/font-awesome.min.css',
      '/stylesheets/lib/dataTables.bootstrap.css',
      '/stylesheets/lib/animations.css',
      '/stylesheets/screen.css',
      '/stylesheets/social-buttons.css'
    ]
    js_compression  :jsmin       # Optional
    css_compression :simple      # Optional
    
    prebuild true
  end

  before '/*' do
    is_login_site = (request.path_info == '/login')
    is_auth_site = request.path_info.start_with?('/auth')
    is_asset = (request.path_info.start_with?('/fonts') ||
      request.path_info.start_with?('/images') ||
      request.path_info.start_with?('/javascripts') ||
      request.path_info.start_with?('/stylesheets'))
    if not (is_asset || is_login_site || is_auth_site)
      if not logged_in?
        redirect to('/login')
      end
    end
  end

  get '/login' do
    erb :login
  end

  get '/logout' do
    session[:uid] = nil
    redirect to('/login')
  end

  get '/auth/google_oauth2/callback' do
    auth_hash = request.env['omniauth.auth']
    google_email = auth_hash['info']['email']
    # make sure only valid domains can login
    parsed_google_email = Mail::Address.new(google_email)
    error 403 if not AUTH_CONFIG['valid_domains'].member?(parsed_google_email.domain)
    # successfully logged in, make sure we have user in the database
    user = Models::User.find_or_initialize_by(email: parsed_google_email.address)
    user.google_id = auth_hash['uid']
    user.save
    # save user id in session
    session[:uid] = user.id
    # redirect to root site
    redirect to('/')
  end

  get '/auth/failure' do
    error 403
  end

  get '/' do
    query_report = Reports::Query.new
    @queries = query_report.run
    # We want to strip out block comments before passing it on to the view
    @queries.each do |q|
      q["query"] = q["query"].gsub(/(\/\*).+(\*\/)/, '')      
    end
    erb :index, :locals => { :name => :home }
  end

  get '/auditlog' do
    @selects = ((not params['selects'].nil?) && params['selects'] == 'true')
    erb :auditlog, :locals => { :name => :auditlog }
  end

  get '/auditlog/table' do
    # parse parameters
    draw = params['draw'].to_i
    start = params['start'].to_i
    length = params['length'].to_i
    order = params['order']
    search = params['search']['value']
    selects = ((not params['selects'].nil?) && params['selects'] == 'true')
    # q_query is the filter query
    q_query = Models::Query
    q_query = q_query.where(query_type: 1) if not selects
    # filter by search query
    if not search.empty?
      q_query = q_query.where(
        'queries.user LIKE ? OR queries.query LIKE ?', "%#{search}%", "%#{search}%"
      )
    end
    # figure out ordering
    columns = [ 'record_time', 'user', 'xid', 'query' ]
    order_str = ''
    (0..(order.size-1)).each do |i|
      order_str += 'queries.'
      order_str += columns[order[i.to_s]['column'].to_i]
      order_str += ' asc' if order[i.to_s]['dir'] == 'asc'
      order_str += ' desc' if order[i.to_s]['dir'] == 'desc'
      order_str += ', '
    end
    order_str = 'queries.record_time desc' if order_str.empty? # default ordering
    q_query = q_query.order(order_str[0, order_str.length - 2]) if not order_str.empty?
    # get data
    queries = q_query.limit(length).offset(start).map do |q|
      [
        Time.at(q.record_time).strftime('%F at %T %:z'),
        "#{q.user} <small>(#{q.userid})<small>",
        q.xid,
        CodeRay.scan(q.query, :sql).div()
      ]
    end
    # generate output format
    {
      draw: draw,
      recordsTotal: Models::Query.count,
      recordsFiltered: q_query.count,
      data: queries
    }.to_json
  end

  get '/disk_space' do
    disk_space_report = Reports::DiskSpace.new
    @disks = disk_space_report.run
    erb :disk_space, :locals => {:name => :disk_space}
  end
  
  get '/tables' do
    @tables = Reports::Table.new.run
    erb :tables, :locals => { :name => :tables }
  end

  get '/permissions' do
    @users, @groups, @tables = Reports::Permission.new.result
    @p_types = ["select", "insert", "update", "delete", "references"]
    erb :permissions, :locals => { :name => :permissions }
  end

  get '/permissions/tables' do
    schemaname, tablename = params[:value].split("-->")
    permissions_report = Reports::Permission.new
    @result = permissions_report.get_users_with_access(schemaname, tablename).to_json
  end
    
  get '/permissions/users' do
    username = params[:value]
    permissions_report = Reports::Permission.new
    @result = permissions_report.get_tables_for_user(username).to_json
  end

  get '/permissions/groups' do
    groupname = params[:value]
    permissions_report = Reports::Permission.new
    @result = permissions_report.get_tables_for_group(groupname).to_json
  end
   
  not_found do
    @error = 'This is nowhere to be found.'
    erb :error
  end

  error do
    @error = 'Sorry, there was a nasty error - ' + env['sinatra.error'].name.to_s
    erb :error
  end

  error 403 do
    @error = 'Access forbidden'
    erb :error
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end
