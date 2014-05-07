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
set :use_sudo,        false 
default_run_options[:pty] = true
set :ssh_options, {:forward_agent => true,
                   :keys => [File.join(ENV["HOME"], ".ssh", "id_rsa")]}


task :production do
  set :rails_env, "staging"
  set :branch, "stable"
  role :all,  "www-staging.analyticsmediagroup.com"
  role :app,  "www-staging.analyticsmediagroup.com"
  role :web,  "www-staging.analyticsmediagroup.com"
  role :db,   "www-staging.analyticsmediagroup.com", :primary => true
  #role :cron, "www-staging.analyticsmediagroup.com"
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
    run "rake db:migrate RAILS_ENV=#{rails_env}"
  end
end


