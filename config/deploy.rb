# config/deploy.rb

# Bundler tasks
require 'bundler/capistrano'

# We're using RVM on a server, need this.
# why this is here: https://github.com/wayneeseguin/rvm-capistrano/issues/63
require 'rvm/capistrano'
set :rvm_ruby_string, '2.1.1'
set :rvm_type, :system
set :rvm_path, '/usr/local/rvm'
$:.unshift(File.expand_path('./lib', ENV['rvm_path']))

# whenever for cronjobs
set :whenever_command, "bundle exec whenever"
require 'whenever/capistrano'

APP_NAME = 'polizei'

set :application,     "#{APP_NAME}"
set :repository,      "git@github.com:AnalyticsMediaGroup/redshift_polizei.git"
set :scm,             :git
set :branch,          "master"
set :bundle_without,  [:development, :test, :cucumber]
set :deploy_to,       "/amg/app/#{APP_NAME}" 
set :shared_path,     "#{deploy_to}/shared"
set :user,            "deploy"
set :runner,          "deploy"
set :keep_releases,   5
set :yaml_files,      ['database', 'aws', 'auth', 'cache']
set :use_sudo,        false 
default_run_options[:pty] = true
set :ssh_options, {:forward_agent => true,
                   :keys => [File.join(ENV["HOME"], ".ssh", "id_rsa")]}

task :staging do
  set :rails_env, "staging"
  set :branch, "master"
  role :all,  "staging.amg.tv"
  role :app,  "staging.amg.tv"
  role :web,  "staging.amg.tv"
  role :db,   "staging.amg.tv", :primary => true
  #role :cron, "www-staging.analyticsmediagroup.com"
end

set :whenever_environment, defer { rails_env }
set :whenever_identifier, defer { "#{application}_#{rails_env}" }

after "deploy:update_code", "config:setup"
after "deploy:restart", "deploy:migrate"

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


