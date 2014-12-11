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

  after do
    PolizeiLogger.logger.info "#{request.ip} - #{session[:uid]} \"#{request.request_method} #{request.path}\" #{response.status} "
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
      '/javascripts/lib/jquery-dateFormat.min.js',
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
    erb :index, :locals => { :name => :home }
  end

  get '/queries/running' do
    query_report = Reports::Query.new
    queries = query_report.run
    # We want to strip out block comments before passing it on to the view
    queries.each do |q|
      q["query"] = CodeRay.scan(q["query"].gsub(/(\/\*).+(\*\/)/, '').strip, :sql).div()
    end
    { data: queries }.to_json
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

    order_column = 0
    order_dir = 'desc'
    if not(order.nil? || order.size == 0)
      order_column = order['0']['column'].to_i
      order_dir = order['0']['dir']
    end

    total_count = 0
    filtered_count = 0
    queries = []
    report = Reports::Query.new
    # get newest queries not yet in the audit log
    t1, t2, t3 = report.new_queries(selects, start, length, order_column, order_dir, search)
    total_count += t1
    filtered_count += t2
    queries += t3
    start += queries.size
    length -= queries.size
    # get the rest from auit log, always needs to be executed to get accurate counts
    t1, t2, t3 = report.audit_queries(selects, start, length, order_column, order_dir, search)
    total_count += t1
    filtered_count += t2
    queries += t3

    # generate output format
    {
      draw: draw,
      recordsTotal: total_count,
      recordsFiltered: filtered_count,
      data: queries
    }.to_json
  end

  get '/disk_space' do
    disk_space_report = Reports::DiskSpace.new
    @disks = disk_space_report.run
    erb :disk_space, :locals => {:name => :disk_space}
  end
  
  get '/tables' do
    @tables = Reports::Table.new.retrieve
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
