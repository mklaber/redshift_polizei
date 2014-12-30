require 'aws'

#
# Convenience utility class for getting AWS Clients so the credential
# process is abstracted away
#
class AWSConfig
  AWS_CONFIG = YAML::load_file(File.join('config', 'aws.yml'))

  def self.redshift_sdk(options = {})
    AWS::Redshift::Client.new(AWS_CONFIG.merge(options))
  end

  def self.cloudwatch_sdk(options = {})
    AWS::CloudWatch::Client.new(AWS_CONFIG.merge(options))
  end

  def self.s3_sdk(options = {})
    AWS::S3.new(AWS_CONFIG.merge(options))
  end

  def self.dynamodb_sdk(options = {})
    AWS::DynamoDB.new(AWS_CONFIG.merge(options))
  end

  def self.cluster_info(options = {})
    clusters = self.redshift_sdk(options).describe_clusters(cluster_identifier: AWS_CONFIG['cluster_identifier'])
    clusters[:clusters][0]
  end

  def self.credentials(access_key_id=nil, secret_access_key=nil)
    access_key_id ||= AWS_CONFIG['access_key_id']
    secret_access_key ||= AWS_CONFIG['secret_access_key']
    "aws_access_key_id=#{access_key_id};aws_secret_access_key=#{secret_access_key}"
  end

  def self.[] key
    AWS_CONFIG[key]
  end
end
