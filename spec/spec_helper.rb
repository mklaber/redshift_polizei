require 'simplecov'
SimpleCov.start

require 'rake'
require 'sinatra/activerecord/rake'
require 'rack/test'
require 'rspec'

root_path = File.join File.expand_path(File.dirname(__FILE__)), '..'

ENV['RACK_ENV'] = ENV['RAILS_ENV'] = 'test'

require File.join root_path, 'app/app.rb'
require 'email_spec'

# recreate test database from migrations
#DesmondConfig.logger = Logger.new STDOUT
ActiveRecord::Schema.verbose = false # no output for migrations
Rake::Task['db:drop'].invoke
Rake::Task['db:reset'].invoke

module RSpecSinatraMixin
  include Rack::Test::Methods
  def app() Polizei end
end

RSpec.configure { |c|
  c.include RSpecSinatraMixin
  c.include(EmailSpec::Helpers)
  c.include(EmailSpec::Matchers)

  c.before(:suite) do
    Models::User.create(email: 'polizei-test@amg.tv', google_id: 0)
  end

  c.after(:suite) do
    Models::User.destroy_all
  end

  c.before(:all) do
    @config = YAML.load_file(File.join root_path, 'config', 'tests.yml').symbolize_keys
    AWS.config({
      access_key_id: @config[:access_key_id],
      secret_access_key: @config[:secret_access_key]
    })
  end
}
