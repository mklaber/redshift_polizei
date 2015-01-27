require 'sinatra'

helpers do
  def logged_in?
    (not(session[:uid].nil?) && Models::User.exists?(session[:uid]))
  end

  def current_user
    return nil if not(logged_in?)
    Models::User.find(session[:uid])
  end

  def link_to(body, url = nil, html_options = {})
    url = body if url.nil?
    s = "<a href='#{url}'"
    s += html_options.collect{|k,v| " #{k}='#{v}'"}.join('')
    s += ">#{body}</a>"
  end
  
  def h(text)
    Rack::Utils.escape_html(text)
  end
end
