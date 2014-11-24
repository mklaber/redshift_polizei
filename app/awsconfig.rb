require 'aws'

class AWSConfig
  AWS_CONFIG = YAML::load_file(File.join('config', 'aws.yml'))

  def self.redshift_sdk
    AWS::Redshift::Client.new(AWS_CONFIG)
  end

  def self.cloudwatch_sdk
    AWS::CloudWatch::Client.new(AWS_CONFIG)
  end

  def self.dynamodb_sdk
    AWS::DynamoDB.new(AWS_CONFIG)
  end

  def self.cluster_info
    clusters = redshift_sdk.describe_clusters(cluster_identifier: AWS_CONFIG['cluster_identifier'])
    clusters[:clusters][0]
  end
end
