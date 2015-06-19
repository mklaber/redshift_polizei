require 'bundler'
Bundler.require
# activerecord tasks
require "sinatra/activerecord/rake"

APP_FILE  = 'app/app.rb'
APP_CLASS = 'Polizei'
require 'sinatra/assetpack/rake'

require 'desmond/rake'

# this loads several configuration files (e.g. polizei.yml) needed in background processes,
# so we can't just load app/main
require_relative 'app/app'

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
    Rake::Task['redshift:tablereports:update'].invoke
    Rake::Task['redshift:permissions:update'].invoke
    Rake::Task['redshift:auditlog:import'].invoke
  end
end

namespace :redshift do
  namespace :auditlog do
    desc 'Import audit log files into polizei'
    task :import, :just_one, :file do |t, args|
      Jobs::Queries::AuditLog::Import.run_persisted(0, just_one: args[:just_one], file: args[:file])
    end

    desc 'Discard old audit log entries'
    task :retention do
      Jobs::Queries::AuditLog::EnforceRetention.run_persisted(0)
    end

    desc 'Rerun the query classification'
    task :reclassify do
      Jobs::Queries::AuditLog::Reclassify.run_persisted(0)
    end
  end

  namespace :tablereports do
    desc 'Update tables report'
    task :update, :schema_name, :table_name do |t, args|
      Jobs::TableReports.run_persisted(1, 0, args)
    end
    desc 'Discard all table reports'
    task :clear do
      Models::TableReport.destroy_all
    end
  end

  namespace :permissions do
    desc 'Update permissions from RedShift'
    task :update do
      Jobs::Permissions::Update.run_persisted(0)
    end
  end
end
