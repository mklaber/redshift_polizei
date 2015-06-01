require './app/main'

class Polizei < Sinatra::Application
  #use Rack::RubyProf, :path => 'profile'
  POLIZEI_CONFIG_FILE = 'config/polizei.yml'
  JOB_WAIT_TIMEOUT = 30
  ARCHIVE_NULL_VALUE = '<<<NULL>>>'
  
  set :root, File.dirname(__FILE__)
  set :views, "#{settings.root}/views"
  helpers PolizeiHelpers
  register Sinatra::AssetPack
  register Sinatra::AWSExtension
  register Sinatra::PonyMailExtension

  # setup the custom logger
  configure do
    set :public_folder, 'public'
    # Disable internal middleware for presenting errors
    # as useful HTML pages
    set :show_exceptions, false
    # disable Sinatra's default
    set :logging, nil
    # config files
    load_config_file :polizei, POLIZEI_CONFIG_FILE
    set :aws_config_file , POLIZEI_CONFIG_FILE
    set :mail_config_file, POLIZEI_CONFIG_FILE
    # set up exception notififcations
    if Object.const_defined?('ExceptionNotification')
      exp_notifier_options = { :email => {
        :email_prefix => "[POLIZEI] ",
        :sender_address => GlobalConfig.polizei('mail')['from'],
        :exception_recipients => GlobalConfig.polizei('exception_mail_to'),
        :smtp_settings => Pony.options[:via_options]
      }}
      use ExceptionNotification::Rack, exp_notifier_options
      DesmondConfig.register_with_exception_notifier exp_notifier_options
    end
  end
  # set logger in environment variable for rack to pick it up
  before do
    env['rack.logger'] = PolizeiLogger.logger
    env['rack.errors'] = PolizeiLogger.logger
  end

  after do
    PolizeiLogger.logger.info "#{request.ip} - #{session[:uid]} \"#{request.request_method} #{request.path}\" #{response.status} "
  end

  use Rack::Session::Cookie, :key => 'rack.session',
                             :expire_after => 86400 * 7, # sec
                             :secret => GlobalConfig.polizei('cookie_secret')
  # configure OAuth authentication
  use OmniAuth::Builder do
    provider GlobalConfig.polizei('auth_provider'),
      GlobalConfig.polizei('auth_client_id'),
      GlobalConfig.polizei('auth_client_secret')
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
      '/javascripts/lib/dataTables.bootstrap.min.js',
      '/javascripts/lib/moment.min.js',
      '/javascripts/shared.js'
    ]
    js :tables, ['/javascripts/tables.js']
    js :queries, ['/javascripts/queries.js']
    js :auditlog, ['/javascripts/auditlog.js']
    js :permissions, ['/javascripts/permissions.js']
    js :jobs, ['/javascripts/jobs.js']
    css :application, [
      '/stylesheets/lib/bootstrap.min.css',
      '/stylesheets/lib/font-awesome.min.css',
      '/stylesheets/lib/dataTables.bootstrap.css',
      '/stylesheets/lib/animations.css',
      '/stylesheets/screen.css',
      '/stylesheets/social-buttons.css'
    ]
    prebuild false
    js_compression :uglify # jsmin is unmantained and fails, yui needs java, closeure didn't try, this works
  end

  before '/*' do
    is_login_site = (request.path_info == '/login')
    is_auth_site = request.path_info.start_with?('/auth')
    is_asset = (request.path_info.start_with?('/assets') ||
      request.path_info.start_with?('/fonts') ||
      request.path_info.start_with?('/images') ||
      request.path_info.start_with?('/javascripts') ||
      request.path_info.start_with?('/stylesheets') ||
      request.path_info.start_with?('/favicon.ico'))
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
    error 403 if not GlobalConfig.polizei('auth_valid_domains').member?(parsed_google_email.domain)
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

  get '/queries/recent' do
    # get date from where to retrieve recent queries
    audit_log_newest_query = Models::Query.order('record_time DESC').first
    audit_log_date = 0
    audit_log_date = audit_log_newest_query.record_time unless audit_log_newest_query.nil?

    queries = Jobs::Queries::Recent.run(current_user.id, date: Time.at(audit_log_date))
    # We want to strip out block comments before passing it on to the view
    queries.each do |q|
      q['query'] = CodeRay.scan(Models::Query.query_for_display(q['query']), :sql).div()
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

    # get the rest from auit log, always needs to be executed to get accurate counts
    queries_data = Jobs::Queries::AuditLog::Get.run(1,
      selects: selects, start: start, length: length,
      order: order_column, orderdir: order_dir, search: search)

    # generate output format
    queries_data.merge(draw: draw).to_json
  end

  get '/disk_space' do
    disk_space_report = Reports::DiskSpaceCloudwatch.new
    data = disk_space_report.run
    @period = data[:period]
    @disks = data[:data]
    erb :disk_space, :locals => {:name => :disk_space}
  end
  
  get '/tables' do
    @tables = Models::TableReport.order(size_in_mb: :desc)
    @archives = Models::TableArchive.order(created_at: :desc)
    @updated = Jobs::TableReports.last_run(1)
    @updated = @updated.executed_at unless @updated.nil?
    erb :tables, :locals => { :name => :tables }
  end

  post '/tables/archive' do
    email_list = validate_email_list("#{current_user.email}, #{params[:email]}")
    time = Time.now.utc.strftime('%Y_%m_%dT%H_%M_%S_%LZ')
    bucket = params[:bucket].empty? ? GlobalConfig.polizei('aws_archive_bucket') : params[:bucket]
    prefix = params[:prefix].empty? ? "#{params[:schema]}/#{params[:table]}/#{time}-" : params[:prefix]
    skip_drop = !!params[:skip_drop]
    access_key = params[:access_key].empty? ? GlobalConfig.polizei('aws_access_key_id') : params[:access_key]
    secret_key = params[:secret_key].empty? ? GlobalConfig.polizei('aws_secret_access_key') : params[:secret_key]
    Jobs::ArchiveJob.enqueue(current_user.id,
                                    db: {
                                        connection_id: "redshift_#{Sinatra::Application.environment}",
                                        username: params[:redshift_username],
                                        password: params[:redshift_password],
                                        schema: params[:schema],
                                        table: params[:table],
                                        skip_drop: skip_drop
                                    },
                                    s3: {
                                        access_key_id: access_key,
                                        secret_access_key: secret_key,
                                        bucket: bucket,
                                        prefix: prefix
                                    },
                                    unload: {
                                        allowoverwrite: true,
                                        gzip: true,
                                        addquotes: true,
                                        escape: true,
                                        null_as: ARCHIVE_NULL_VALUE
                                    },
                                    email: email_list.join(', '))
    redirect to('/tables')
  end

  post '/tables/restore' do
    email_list = validate_email_list("#{current_user.email}, #{params[:email]}")
    archive_info = Models::TableArchive.find_by(schema_name: params[:schema], table_name: params[:table])
    halt 404 if archive_info.nil?
    access_key = params[:access_key].empty? ? GlobalConfig.polizei('aws_access_key_id') : params[:access_key]
    secret_key = params[:secret_key].empty? ? GlobalConfig.polizei('aws_secret_access_key') : params[:secret_key]
    Jobs::RestoreJob.enqueue(current_user.id,
                             db: {
                                 connection_id: "redshift_#{Sinatra::Application.environment}",
                                 username: params[:redshift_username],
                                 password: params[:redshift_password],
                                 schema: params[:schema],
                                 table: params[:table]
                             },
                             s3: {
                                 access_key_id: access_key,
                                 secret_access_key: secret_key,
                                 archive_bucket: archive_info.archive_bucket,
                                 archive_prefix: archive_info.archive_prefix
                             },
                             copy: {
                                 gzip: true,
                                 removequotes: true,
                                 escape: true,
                                 null_as: ARCHIVE_NULL_VALUE
                             },
                             email: email_list.join(', '))
    redirect to('/tables')
  end

  post '/tables/report' do
    content_type :json
    begin
      still_exists = Jobs::TableReports.enqueue_and_wait(
        1,
        current_user.id,
        JOB_WAIT_TIMEOUT,
        schema_name: params[:schema_name],
        table_name: params[:table_name]
      )
      if still_exists
        Models::TableReport.where(
          schema_name: params[:schema_name],
          table_name: params[:table_name]
        ).first.to_json
      else
        { doesnotexist: true }.to_json
      end
    rescue => e
      PolizeiLogger.logger.exception e
      status 500
      { error: e.message }.to_json
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
    @users   = Models::DatabaseUser.order(:name).all
    @groups  = Models::DatabaseGroup.order(:name).all
    @tables  = Models::Table.includes(:schema).order("schemas.name, tables.name").all
    @updated = Jobs::Permissions::Update.last_run
    @updated = @updated.executed_at unless @updated.nil?
    erb :permissions, :locals => { :name => :permissions }
  end

  get '/permissions/user2tables' do
    {
      permissions: Models::Permission.for_user(params[:value], Models::Table)
    }.to_json
  end

  get '/permissions/group2tables' do
    {
      members: Models::DatabaseGroup.find_by!(name: params[:value]).users.order(:name),
      permissions: Models::Permission.for_group(params[:value], Models::Table)
    }.to_json
  end

  get '/permissions/table2users' do
    schema_name, table_name = params[:value].split("-->")
    {
      owner: Models::Table.find_by_full_name(schema_name, table_name).owner,
      permissions: Models::Permission.for_table(schema_name, table_name, Models::DatabaseUser)
    }.to_json
  end

  get '/permissions/table2groups' do
    schema_name, table_name = params[:value].split("-->")
    {
      owner: Models::Table.find_by_full_name(schema_name, table_name).owner,
      permissions: Models::Permission.for_table(schema_name, table_name, Models::DatabaseGroup)
    }.to_json
  end

  get '/jobs' do
    @jobs = Models::ExportJob.where("user_id = ? OR public", current_user.id).sort do |j1, j2|
      # most recently run job at the top
      t1 = Time.at(0).utc # default value in case it was never queued
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
    result = { rows: [], columns: [] }
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
    ExceptionNotifier.notify_exception(env['sinatra.error'], env: env) if Object.const_defined?('ExceptionNotifier')
    @error = 'Sorry, there was a nasty error - ' + env['sinatra.error'].to_s
    status 500
    erb :error
  end

  error 403 do
    @error = 'Access forbidden'
    erb :error
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end
