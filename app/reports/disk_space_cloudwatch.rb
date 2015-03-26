require 'aws'

module Reports
  #
  # Report retireving the disk space usage from CloudWatch
  #
  class DiskSpaceCloudwatch < Base
    REPORT_PERIOD_SECS = 60
    NUM_SAFETY_PERIODS = 10 # to make sure clock drift doesn't affect us

    #
    # retrieves disk usage and capacity for RedShift from CloudWatch Metric
    #
    def run
      cluster_identifier = Sinatra::Configurations.aws('cluster_identifier')
      clusters = AWS::Redshift::Client.new.describe_clusters(cluster_identifier: cluster_identifier)
      cluster = clusters[:clusters][0]
      cloudwatch = AWS::CloudWatch::Client.new
      i = 0
      node_space = cluster[:cluster_nodes].select { |node| node[:node_role] != 'LEADER' }.map do |node|
        dimensions = [{
          name: "ClusterIdentifier",
          value: cluster_identifier
        },{
          name: "NodeID",
          value: "Compute-#{i}"
        }]
        i += 1
        req = {namespace: "AWS/Redshift",
          metric_name: "PercentageDiskSpaceUsed",
          start_time: (Time.now - REPORT_PERIOD_SECS * NUM_SAFETY_PERIODS).iso8601,
          end_time: (Time.now +  REPORT_PERIOD_SECS * NUM_SAFETY_PERIODS).iso8601,
          period: REPORT_PERIOD_SECS,
          statistics: ["Average"],
          dimensions: dimensions}
        # query results from CloudWatch
        result = cloudwatch.get_metric_statistics(req)
        result[:datapoints].sort_by! { |datapoint| datapoint[:timestamp] }
        # transform result for frontend
        if result[:datapoints].empty?
          { 'node' => node[:node_role],
            'pct' => 0,
          }
        else
          { 'node' => node[:node_role],
            'pct' => result[:datapoints].last[:average]
          }
        end
      end

      { period: REPORT_PERIOD_SECS, data: node_space }
    end
  end
end
