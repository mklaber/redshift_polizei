require 'simplecov'
require 'coveralls'
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start

require 'rake'
require 'rspec'

root_path = File.join File.expand_path(File.dirname(__FILE__)), '..'

ENV['RACK_ENV'] = ENV['RAILS_ENV'] = 'test'

require File.join root_path, 'app/app.rb'
require 'email_spec'

require 'sinatra/activerecord/rake'
require 'rack/test'

# recreate test database from migrations
DesmondConfig.logger = nil
#DesmondConfig.logger = Logger.new STDOUT
ActiveRecord::Base.logger = DesmondConfig.logger
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

  c.before(:suite) do
    $connection_id = 'redshift_test'
    $config = GlobalConfig.polizei.symbolize_keys
    $config.merge!(rs_user: ActiveRecord::Base.configurations[$connection_id]['username'],
      rs_password: ActiveRecord::Base.configurations[$connection_id]['password'])
    AWS.config({
      access_key_id: $config[:aws_access_key_id],
      secret_access_key: $config[:aws_secret_access_key]
    })

    # supply a RedShift connection to all tests
    $conn = RSUtil.dedicated_connection(connection_id: $connection_id,
                                        username: $config[:archive_username],
                                        password: $config[:archive_password])
    fail 'Could not connect to Redshift' if $conn.nil?

    # create a test user & group
    o = [('a'..'z'), ('A'..'Z'), ('0'..'9')].map { |i| i.to_a }.flatten
    rndm_password = (0...63).map { o[rand(o.length)] }.join
    $test_group = "polizei_test_group_#{rand(1024)}"
    $test_user  = "polizei_test_user_#{rand(1024)}"
    $conn.exec("CREATE USER #{$test_user} WITH PASSWORD '#{rndm_password}'")
    $conn.exec("CREATE GROUP #{$test_group} WITH USER #{$test_user}")
  end

  c.after(:suite) do
    $conn.exec("DROP USER IF EXISTS #{$test_user}")
    $conn.exec("DROP GROUP #{$test_group}")
  end

  c.before(:all) do
    # TODO should use GlobalConfig everywhere eventually instead
    @config = $config
  end
}
