require 'bundler'
Bundler.require
# activerecord tasks
require "sinatra/activerecord/rake"

require 'desmond/rake'

require_relative 'app/main'

Dir.glob('./tasks/*.rb').sort.each { |file| require file }

# Rake error handling should use our logger
class Rake::Application
  def display_error_message(ex)
    PolizeiLogger.logger('rake').exception ex
  end
end

task :environment do
  ENV["RACK_ENV"] || 'development'
end


namespace :reports do
  desc 'Updates the caches of all reports'
  task :update do
    Tasks::ReportsUpdate.renew_all
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

    desc 'Rerun the query classification'
    task :reclassify do
      Tasks::AuditLog.reclassify_queries
    end
  end

  namespace :tablereport do
    desc 'Update tables report'
    task :update do
      Jobs::TableReports.run(1, 1)
    end
  end
end
