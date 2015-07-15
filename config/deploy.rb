# config/deploy.rb

require './lib/global_config'
GlobalConfig.load_config_file('deploy', 'config/polizei.yml')
APP_NAME    = 'polizei'
SERVER_URL  = GlobalConfig.deploy('deploy_server_url')
SERVER_PATH = GlobalConfig.deploy('deploy_server_path')

# Bundler tasks
require 'bundler/capistrano'

# We're using RVM on a server, need this.
# why this is here: https://github.com/wayneeseguin/rvm-capistrano/issues/63
require 'rvm/capistrano'
set :rvm_ruby_string, '2.1.1'
set :rvm_type, :system
set :rvm_path, '/usr/local/rvm'
$:.unshift(File.expand_path('./lib', ENV['rvm_path']))

# whenever recipe for cronjobs
set :whenever_command, "bundle exec whenever"
require 'whenever/capistrano'

# load desmond recipe
require 'desmond/capistrano'

set :application,     "#{APP_NAME}"
set :repository,      "git@github.com:AnalyticsMediaGroup/redshift_polizei.git"
set :scm,             :git
set :branch,          "master"
set :bundle_without,  [:development, :test, :cucumber]
set :deploy_to,       SERVER_PATH
set :shared_path,     "#{deploy_to}/shared"
set :user,            "deploy"
set :runner,          "deploy"
set :keep_releases,   5
set :yaml_files,      ['database', 'polizei']
set :use_sudo,        false 
default_run_options[:pty] = true
set :ssh_options, {:forward_agent => true,
                   :keys => [File.join(ENV["HOME"], ".ssh", "id_rsa")]}

task :production do
  set :rails_env, "production"
  set :branch, "master"
  role :all,  SERVER_URL
  role :app,  SERVER_URL
  role :web,  SERVER_URL
  role :db,   SERVER_URL, :primary => true
  after "deploy:update_code", "git:tag_last_deploy"
end

set :whenever_environment, defer { rails_env }
set :whenever_identifier, defer { "#{application}_#{rails_env}" }
set :whenever_roles, defer { :app }

after "deploy:update_code", "config:setup"
after "deploy:restart", "deploy:migrate"
after "deploy:restart", "assets:precompile"

# manage desmond background processes
after  "deploy:stop",    "desmond:stop"
after  "deploy:start",   "desmond:start"
after  "deploy:restart", "desmond:restart"

namespace :assets do
  task :precompile, :roles => :app do
    run "cd #{current_path}; bundle exec rake assetpack:build RACK_ENV=#{rails_env}"
  end
end

namespace :deploy do
  [:start, :stop].each do |t|
    desc "#{t} task is a no-op with passenger/mod_rails"
    task t, :roles => :app do ; end
  end

  task :restart, :roles => :app, :except => { :no_release => true }  do
    run "touch #{current_path}/tmp/restart.txt"
  end
  
  task :migrate, :roles => :app do
    run "cd #{current_path}; bundle exec rake db:migrate RACK_ENV=#{rails_env}"
  end
end

namespace :config do
  task :setup do
    yaml_files.each do |file|
      run "cp #{deploy_to}/shared/config/#{file}.yml #{release_path}/config/#{file}.yml"
    end
  end
end

namespace :git do
 desc "tag the deployment in git"
 task :tag_last_deploy do
   set :timestamp, Time.now
   set :tag_name,  "deployed_to_#{rails_env}_#{timestamp.localtime.strftime("%Y-%m-%d_%H-%M-%S")}"
   `git tag -a -m "Tagging deploy to #{rails_env} at #{timestamp}" #{tag_name}`
   `git push --tags`
   puts "Tagged release with #{tag_name}."
 end
end
