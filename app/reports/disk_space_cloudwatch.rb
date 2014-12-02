require 'aws'

module Reports
  class DiskSpaceCloudwatch < Base

    def run
      cluster = AWSConfig.cluster_info
      cloudwatch = AWSConfig.cloudwatch_sdk
      cluster[:cluster_nodes].map do |node|
        # TODO currently only returns non-empty data for whole cluster instead of individual nodes
        dimension = {
          name: "ClusterIdentifier",
          value: cluster[:cluster_parameter_groups][0][:parameter_group_name]
        }
        # query results from CloudWatch
        result = cloudwatch.get_metric_statistics(namespace: "AWS/Redshift",
          metric_name: "PercentageDiskSpaceUsed",
          start_time: (Time.now - 60).iso8601,
          end_time: (Time.now - 1).iso8601,
          period: 60, statistics: ["Average"],
          dimensions: [dimension])
        # transform result for frontend
        if result[:datapoints].empty?
          { 'node' => node[:node_role],
            'used' => 0,
            'capacity' => 0
          }
        else
          { 'node' => node[:node_role],
            'used' => result[:datapoints][0][:average],
            'capacity' => 100
          }
        end
      end
    end
  end
end
