require 'bundler'
Bundler.require
# activerecord tasks
require "sinatra/activerecord/rake"

APP_FILE  = 'app/app.rb'
APP_CLASS = 'Polizei'
require 'sinatra/assetpack/rake'

require 'desmond/rake'

# this loads several configuration files (e.g. mail.yml) need in background processes,
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


# TODO desmond should allow `run` with persisted job_run optionally
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
    task :import, :just_one do |t, args|
      Jobs::Queries::AuditLog::Import.enqueue_and_wait(0, nil, just_one: args[:just_one])
    end

    desc 'Discard old audit log entries'
    task :retention do
      Jobs::Queries::AuditLog::EnforceRetention.enqueue_and_wait(0)
    end

    desc 'Rerun the query classification'
    task :reclassify do
      Jobs::Queries::AuditLog::Reclassify.enqueue_and_wait(0)
    end
  end

  namespace :tablereports do
    desc 'Update tables report'
    task :update, :schema_name, :table_name do |t, args|
      Jobs::TableReports.enqueue_and_wait(1, 0, nil, args)
    end
    desc 'Discard all table reports'
    task :clear do
      Models::TableReport.destroy_all
    end
  end

  namespace :permissions do
    desc 'Update permissions from RedShift'
    task :update do
      Jobs::Permissions::Update.enqueue_and_wait(0)
    end
  end
end
