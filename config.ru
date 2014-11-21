$: << File.join(File.dirname(__FILE__), 'app')

require 'sinatra'
require 'erubis'
require 'app'

set :mail_options, {
                      :from => 'no-reply@analyticsmediagroup.com',
                      :via => :smtp,
                      :via_options => {
                        :address              => 'smtp.gmail.com',
                        :port                 => '587',
                        :enable_starttls_auto => true,
                        :user_name            => 'webmaster@analyticsmediagroup.com',
                        :password             => 'kbzhjcqmxftiwydl',
                        :authentication       => :plain, # :plain, :login, :cram_md5, no auth by default
                        :domain               => "analyticsmediagroup.com" # the HELO domain provided by the client to the server
                      }
                    }

Tilt.register Tilt::ErubisTemplate, "html.erb"

disable :run
set :views, "#{settings.root}/app/views"
set :session_secret, '*&(^q24t89y$*q27895#yjknsd%@f4'

run Polizei