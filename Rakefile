$: << File.join(File.dirname(__FILE__), 'app')

require 'bundler'
Bundler.require
require './app/app'

# set activerecords logger
ActiveRecord::Base.logger = PolizeiLogger.logger
# Rake error handling should use our logger
class Rake::Application
  def display_error_message(ex)
    PolizeiLogger.logger.exception ex
  end
end

# activerecord tasks
require "sinatra/activerecord/rake"
namespace :db do
  task :load_config do
    require "./app/app"
  end
end

namespace :redshift do
  namespace :auditlog do
    desc 'Import audit log files into polizei'
    task :import do
      Tasks::AuditLog.update_from_s3
    end

    desc 'Discard old audit log entries'
    task :retention do
      Tasks::AuditLog.new.enforce_retention_period
    end
  end

  namespace :tablereport do
    desc 'Update tables report'
    task :update do
      Reports::Table.new.run
    end
  end
end
