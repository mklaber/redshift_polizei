require 'sinatra'

helpers do
  def logged_in?
    (not(session[:uid].nil?) && User.exists?(session[:uid]))
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
    
  def size_formatted(mb)
    mb_f = mb.to_f
    if mb_f > 1048576 # > 1 TB
      "#{number_with_precision((mb_f / 1048576.0), :precision=> 2)} TB"
    elsif mb_f > 1024
      "#{number_with_precision((mb_f / 1024.0), :precision=> 2)} GB"
    else
      "#{mb} MB"
    end
  end

end
