require './app/monkey_patches'
require './lib/global_config'
GlobalConfig.load_config_file('deploy', 'config/polizei.yml')
APP_NAME    = 'polizei'
SERVER_PATH = GlobalConfig.deploy('deploy_server_path')
fail ArgumentError, "You need to set 'deploy_server_path' in config/polizei.yml" if SERVER_PATH.blank?

# config valid only for current version of Capistrano
lock '3.4.0'

set :application, APP_NAME
set :repo_url   , 'git@github.com:AnalyticsMediaGroup/redshift_polizei.git'

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, fetch(:linked_files, []).push('config/database.yml', 'config/polizei.yml')

# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids')

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
set :keep_releases, 50

# Bundler tasks
set :bundle_without, 'development test'

# RVM
set :rvm_ruby_version, '2.3.0'
set :rvm_type, :system
set :rvm_custom_path, '/usr/local/rvm'
$:.unshift(File.expand_path('./lib', ENV['rvm_path']))

# General configuration
set :scm,             :git
set :branch,          fetch(:branch, 'stable') # Default branch
set :deploy_to,       SERVER_PATH
set :shared_path,     "#{fetch :deploy_to}/shared"
set :user,            'deploy'
set :runner,          'deploy'
set :use_sudo,        false
set :ssh_options, {
  user: 'deploy',
  keys: [
    File.join(ENV['HOME'], '.ssh', 'id_rsa'),
    File.join(ENV['HOME'], '.ssh', 'id_amg')
  ]
}

# Whenever configuration
set :whenever_environment, -> { fetch(:rack_env, 'development') }
set :whenever_roles, [:cron]

# Deployment process
after 'deploy:finished', 'deploy:restart'
after 'deploy:restart' , 'desmond:restart'
after 'deploy:restart' , 'assets:precompile'

# Tagging the repo
after 'deploy:finished', 'git:tag_last_deploy'
