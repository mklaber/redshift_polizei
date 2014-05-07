source 'https://rubygems.org'
gem 'sinatra'
gem 'rack_csrf'
gem 'capistrano'
gem 'erubis'
gem 'rvm-capistrano'

gem 'sinatra-assetpack'       # asset pipeline management
gem 'pony'                    # for sending e-mails
gem 'yui-compressor'
gem 'sanitize'

gem 'pg'
gem 'activerecord'
gem 'activerecord4-redshift-adapter', github: 'aamine/activerecord4-redshift-adapter'

group :development do
  gem 'thin'
  gem 'capistrano', '~> 2.15.5' # syntax has totally changed from 2.x to 3.x
end

group :staging, :production do
  gem 'passenger'
end