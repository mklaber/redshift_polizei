source 'https://rubygems.org'

gem 'rake'
gem 'sinatra'
gem 'omniauth-google-oauth2'
gem 'mail' # mail address parsing
gem 'rack_csrf'
gem 'erubis'
gem 'sinatra-assetpack' # asset pipeline management

gem 'activerecord'
gem 'sinatra-activerecord'
gem 'pg'
gem 'activerecord4-redshift-adapter', github: 'aamine/activerecord4-redshift-adapter'
gem 'coderay' # sql pretty printing

gem 'aws-sdk' # redshift, cloudwatch, dynamodb

gem 'whenever', :require => false # cronjobs

gem 'desmond', git: 'git@github.com:AnalyticsMediaGroup/desmond.git' # sql exporting

gem 'pony' # sending emails

gem 'connection_pool' # for background jobs connections

group :development do
  gem 'shotgun'
  gem 'puma'
  gem 'tux'
  gem 'capistrano', '~> 2.15.5' # syntax has totally changed from 2.x to 3.x
  gem 'rvm-capistrano'
  gem 'ruby-prof'
end

group :staging, :production do
  gem 'uglifier'
  gem 'passenger'
end

group :development, :test do
  gem 'rspec'
  gem 'rack-test'
  gem 'email_spec'
  gem 'simplecov', :require => false
end
