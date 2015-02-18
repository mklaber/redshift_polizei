require './app/main'

class Polizei < Sinatra::Application
  POLIZEI_CONFIG_FILE = 'config/polizei.yml'
  AUTH_CONFIG_FILE = 'config/auth.yml'
  
  set :root, File.dirname(__FILE__)
  set :views, "#{settings.root}/views"
  helpers PolizeiHelpers
  register Sinatra::AssetPack
  register Sinatra::AWSExtension
  register Sinatra::PonyMailExtension
  use Rack::Session::Cookie, :key => 'rack.session',
                             :expire_after => 86400 * 7, # In seconds
                             :secret => '*&(^q24t89y$*q27895#yjknsd%@f4'

  # setup the custom logger
  configure do
    # disable Sinatra's default
    set :logging, nil
    # set activerecords logger
    ActiveRecord::Base.logger = PolizeiLogger.logger
    # config files
    load_config_file :auth, AUTH_CONFIG_FILE
    load_config_file :polizei, POLIZEI_CONFIG_FILE
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
    provider Sinatra::Configurations.auth('provider'),
      Sinatra::Configurations.auth('client_id'),
      Sinatra::Configurations.auth('client_secret')
  end

  # configure asset pipeline
  assets do
    serve '/javascripts',    from: 'assets/javascripts'
    serve '/stylesheets',    from: 'assets/stylesheets'
    serve '/images',         from: 'assets/images'
    serve '/fonts',          from: 'assets/fonts'

    # The second parameter defines where the compressed version will be served.
    # (Note: that parameter is optional, AssetPack will figure it out.)
    js :application, [
      '/javascripts/lib/jquery-1.10.2.min.js',
      '/javascripts/lib/bootstrap.min.js',
      '/javascripts/lib/jquery.dataTables.min.js',
      '/javascripts/lib/jquery-dateFormat.min.js',
      '/javascripts/lib/dataTables.bootstrap.min.js',
      '/javascripts/shared.js'
    ]
    js :tables, ['/javascripts/tables.js']
    js :queries, ['/javascripts/queries.js']
    js :jobs, ['/javascripts/jobs.js']
    css :application, [
      '/stylesheets/lib/bootstrap.min.css',
      '/stylesheets/lib/font-awesome.min.css',
      '/stylesheets/lib/dataTables.bootstrap.css',
      '/stylesheets/lib/animations.css',
      '/stylesheets/screen.css',
      '/stylesheets/social-buttons.css'
    ]
    js_compression  :jsmin       # Optional
    css_compression :simple      # Optional
    prebuild false
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
        session[:prev_login_site] = request.path_info
        redirect to('/login')
      end
    end
  end

  get '/login' do
    redirect to('/') if logged_in?
    erb :login
  end

  get '/logout' do
    session[:uid] = nil
    redirect to('/login')
  end

  get '/auth/google_oauth2/callback' do
    # recover site visited before login, so we can redirect there afterwards
    previous_site = session[:prev_login_site] || '/'
    session[:prev_login_site] = nil
    # get auth data from google
    auth_hash = request.env['omniauth.auth']
    google_email = auth_hash['info']['email']
    # make sure only valid domains can login
    parsed_google_email = Mail::Address.new(google_email)
    error 403 if not Sinatra::Configurations.auth('valid_domains').member?(parsed_google_email.domain)
    # successfully logged in, make sure we have user in the database
    user = Models::User.find_or_initialize_by(email: parsed_google_email.address)
    user.google_id = auth_hash['uid']
    user.save
    # save user id in session
    session[:uid] = user.id
    # redirect to root site
    redirect to(previous_site)
  end

  get '/auth/failure' do
    error 403
  end

  get '/' do
    erb :index, :locals => { :name => :home }
  end

  get '/queries/running' do
    query_report = Reports::Query.new
    queries = query_report.running_queries
    # We want to strip out block comments before passing it on to the view
    queries.each do |q|
      q["query"] = CodeRay.scan(Models::Query.query_for_display(q['query']), :sql).div()
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
    disk_space_report = Reports::DiskSpaceCloudwatch.new
    @disks = disk_space_report.run
    erb :disk_space, :locals => {:name => :disk_space}
  end
  
  get '/tables' do
    @tables = Models::TableReport.order(size_in_mb: :desc)
    erb :tables, :locals => { :name => :tables }
  end

  post '/tables/report' do
    content_type :json
    # TODO put into work queue and poll/sse/websocket until frontend timeout
    run = Jobs::TableReports.run(
      1,
      1,
      schema_name: params[:schema_name],
      table_name: params[:table_name]
    )
    if run.done?
      Models::TableReport.where(
        schema_name: params[:schema_name],
        table_name: params[:table_name]
      ).first.to_json
    elsif run.details['doesnotexist']
      run.details.to_json
    else
      status 500
      run.details.to_json
    end
  end

  post '/tables/structure_export' do
    email_list = validate_email_list("#{current_user.email}, #{params[:email]}")
    status 400 if email_list.nil?
    if !email_list.nil? && Jobs::TableStructureExportJob.runs_unfinished(1, current_user.id).empty?
      Jobs::TableStructureExportJob.enqueue(1, current_user.id, email: email_list.join(', '))
    end
    ''
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

  get '/jobs' do
    @jobs = Models::ExportJob.where("user_id = ? OR public", current_user.id).sort do |j1, j2|
      # most recently run job at the top
      t1 = Time.at(0).utc
      t2 = Time.at(0).utc
      t1 = j1.last_run.queued_at_time unless j1.last_run.nil?
      t2 = j2.last_run.queued_at_time unless j2.last_run.nil?
      -(t1 <=> t2)
    end
    erb :jobs, :locals => { :name => :export }
  end

  get '/export/?:id?' do
    if params['id'].nil?
      @form = { 'export_options' => {} }
    else
      @form = Models::ExportJob.find(params['id'].to_i).attributes
      halt 404 if @form['user_id'] != session[:uid] and not(@form['public'])
    end
    erb :export, :locals => { :name => :export }
  end

  post '/export/?:id?' do
    @form = params
    @form['export_options'] = { 'delimiter' => params['csvDelimiter'], 'include_header' => params['csvIncludeHeader'] }
    @error = nil
    j = nil
    if params['id'].nil?
      j = Models::ExportJob.new
    else
      j = Models::ExportJob.find(params[:id].to_i)
      halt 404 if j['user_id'] != session[:uid] and not(j['public'])
    end
    if params['name'].nil? || params['name'].size == 0 || params['query'].nil?|| params['query'].size == 0
      @error = "Please give at least a name and a query."
      return erb :export, :locals => { :name => :export }
    end
    if Models::Query.query_type(params[:query]) != 0
      @error = "Only queries not changing data are allowed!"
      return erb :export, :locals => { :name => :export }
    end

    begin
      j.update!(
        name: params['name'],
        user: current_user,
        success_email: params['success_email'],
        failure_email: params['failure_email'],
        public: !params['public'].nil?,
        query: params['query'],
        export_format: params['export_format'],
        export_options: {
          delimiter: params['csvDelimiter'],
          include_header: !params['csvIncludeHeader'].nil?
        }
      )
    rescue ActiveRecord::RecordInvalid => e
      @error = e.message
      return erb :export, :locals => { :name => :export }
    end

    if params['execute'].to_i != 0
      # only schedule the job if is not already running for the user
      if not(j.runs_unfinished(current_user).empty?)
        @error = "This job is already scheduled/running for you!"
        return erb :export, :locals => { :name => :export }
      end
      if params['redshift_username'].empty? || params['redshift_password'].empty?
        @error = "You forgot your database credentials!"
        return erb :export, :locals => { :name => :export }
      end
      j.enqueue(current_user, params['redshift_username'], params['redshift_password'])
    end
    redirect to('/jobs')
  end

  post '/query/test' do
    result = []
    error = nil
    query_type = Models::Query.query_type(params[:query])
    if query_type == 0 # select query
      tmp = Models::ExportJob.test(current_user,
        connection_id: "redshift_#{Sinatra::Application.environment}",
        username: params['redshift']['username'],
        password: params['redshift']['password'],
        query: params[:query]
      )
      if tmp.include?(:error)
        error = tmp[:error]
      else
        result = tmp
      end
    else
      error = "Only queries not changing data are allowed!"
    end
    {
      draw: params[:draw].to_i,
      recordsTotal: result[:rows].count,
      recordsFiltered: result[:rows].count,
      data: result[:rows],
      columns: result[:columns],
      error: error
    }.to_json
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
