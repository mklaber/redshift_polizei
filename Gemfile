source 'https://rubygems.org'
gem 'sinatra'
gem 'rack_csrf'
gem 'erubis'

gem 'sinatra-assetpack'       # asset pipeline management
gem 'pony'                    # for sending e-mails
gem 'yui-compressor'
gem 'sanitize'

gem 'pg'
gem 'activerecord'
gem 'sinatra-activerecord'
gem 'activerecord4-redshift-adapter', github: 'aamine/activerecord4-redshift-adapter'
gem 'actionview'  # formatting decimals to be 2 places

group :development do
  gem 'shotgun'
  gem 'tux'
  gem 'capistrano', '~> 2.15.5' # syntax has totally changed from 2.x to 3.x
  gem 'rvm-capistrano'
end

group :staging, :production do
  gem 'passenger'
end
