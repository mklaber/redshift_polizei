source 'https://rubygems.org'

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
gem 'coderay'
gem 'actionview' # formatting decimals to be 2 places

gem 'aws-sdk' # dynamodb

gem 'whenever', :require => false # cronjobs

group :development do
  gem 'shotgun'
  gem 'puma'
  gem 'ruby-prof'
  gem 'tux'
  gem 'capistrano', '~> 2.15.5' # syntax has totally changed from 2.x to 3.x
  gem 'rvm-capistrano'
end

group :staging, :production do
  gem 'yui-compressor'
  gem 'passenger'
end
