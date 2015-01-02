require 'bundler'
Bundler.require
# activerecord tasks
require "sinatra/activerecord/rake"
namespace :db do
  task :load_config do
    require "./app/app"
  end
end
# load que rake tasks
require 'que/rake_tasks'

require './app/main'

# Rake error handling should use our logger
class Rake::Application
  def display_error_message(ex)
    PolizeiLogger.logger.exception ex
  end
end

task :environment do
  ENV["RACK_ENV"] || 'development'
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

    desc 'Rerun the query classification'
    task :reclassify do
      Tasks::AuditLog.reclassify_queries
    end
  end

  namespace :tablereport do
    desc 'Update tables report'
    task :update do
      Reports::Table.new.run
    end
  end
end
