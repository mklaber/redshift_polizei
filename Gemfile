source 'https://rubygems.org'

gem 'rake'
gem 'sinatra'
gem 'omniauth-oauth2', '~> 1.3.0' # newer version seem to be incompatible with sentry
gem 'mail' # mail address parsing
gem 'rack_csrf'
gem 'erubis'
gem 'sinatra-assetpack' # asset pipeline management

gem 'activerecord'
gem 'sinatra-activerecord'
gem 'pg'
gem 'activerecord4-redshift-adapter', github: 'aamine/activerecord4-redshift-adapter'
gem 'coderay' # sql pretty printing

gem 'aws-sdk-v1' # redshift, cloudwatch, dynamodb, v2 is incompatible

gem 'whenever', :require => false # cronjobs

gem 'desmond', git: 'https://github.com/AnalyticsMediaGroup/desmond.git' # sql exporting

gem 'pony' # sending emails

gem 'connection_pool' # for background jobs connections

gem 'activerecord-import'

gem 'tux'

group :development do
  gem 'shotgun'
  gem 'puma'
  gem 'capistrano', '~> 3.0', require: false
  gem 'capistrano-rvm', require: false
  gem 'capistrano-bundler', require: false
  gem 'ruby-prof'
end

group :staging, :production do
  gem 'uglifier'
  gem 'passenger'
  gem 'exception_notification' # notification when errors happen
end

group :development, :test do
  gem 'rspec'
  gem 'rack-test'
  gem 'email_spec'
  gem 'coveralls', require: false
end
