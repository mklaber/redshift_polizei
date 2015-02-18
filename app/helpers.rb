module PolizeiHelpers
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

  def validate_email_list(emails, max=0)
    return [] if emails.nil?
    email_list = emails.split(',')
    return [] if email_list.empty?
    return nil if max > 0 && email_list.size > max
    valid = true
    validated_emails = email_list.select do |tmp|
      !tmp.strip.empty?
    end.map do |tmp|
      email = tmp.strip
      m = Mail::Address.new(email)
      valid &&= (!m.domain.nil? && m.address == email)
      m.address
    end
    return nil unless valid
    validated_emails
  end
  module_function :validate_email_list
end
