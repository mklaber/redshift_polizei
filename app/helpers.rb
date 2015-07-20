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

  def get_redshift_metric_leader(cluster_info, options={})
    cluster_identifier = cluster_info[:cluster_identifier]
    dimensions = [{
      name: 'ClusterIdentifier',
      value: cluster_identifier
    },{
      name: 'NodeID',
      value: 'Leader' # CloudWatch doesn't accept the names out of cluster info
    }]
    get_cloudwatch_metric(options.merge(dimensions: dimensions))
  end

  def get_redshift_metric_computes(cluster_info, options={})
    cluster_identifier = cluster_info[:cluster_identifier]
    i = 0
    cluster_info[:cluster_nodes].select { |node| node[:node_role] != 'LEADER' }.map do |node|
      nodeid = "Compute-#{i}" # CloudWatch doesn't accept the names out of cluster info
      dimensions = [{
        name: 'ClusterIdentifier',
        value: cluster_identifier
      },{
        name: 'NodeID',
        value: nodeid
      }]
      i += 1
      tmp = get_cloudwatch_metric(options.merge(dimensions: dimensions))
      tmp[:node] = nodeid
      tmp
    end
  end

  def get_cloudwatch_metric(options={})
    num_safety_periods = 10
    period = options[:period]
    fail ArgumentError, 'No period given' if period.blank?

    # fighting clock drift
    AWS::CloudWatch::Client.new.get_metric_statistics(options.merge({
      start_time: (Time.now - period * num_safety_periods).iso8601,
      end_time:   (Time.now + period * num_safety_periods).iso8601
    })).try(:[], :datapoints).try(:max_by) { |t| t[:timestamp] }
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
