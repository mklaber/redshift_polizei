require 'yaml'

module Caches
  ##
  # internal class to build instances of cache
  # should not be used directly, but rather through BaseCache
  #
  module Creator
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def self.extended(other)
        other.instance_variable_set(:@mtx, Mutex.new)
      end

      #
      # method with singleton behavior to create/retrieve the configured
      # cache instance.
      # if not created yet, it will be created and then returned.
      #
      def cache
        # double checks to try to avoid locking costs once set up
        if @cache.nil?
          self.instance_variable_get(:@mtx).synchronize {
            if @cache.nil?
              @cache = build_cache
            end
          }
        end
        @cache
      end

      private
        #
        # returns a BaseCache instance based on config/cache.yml
        # expects in the file:
        # - type: activerecord/dynamodb
        # - everything else is passed to the BaseCache instance
        #
        def build_cache
          # load cache configuration from file
          environment = Sinatra::Application.environment.to_s
          config = YAML::load_file(File.join('config', 'cache.yml'))
          # check that environment configuartion is there
          env_config = config[environment]
          if env_config.nil?
            raise ArgumentError, "No cache configuration for environment '#{environment}'"
          end
          # build cache instance
          if env_config['type'] == 'dynamodb'
            require_relative 'backends/dynamodb'
            DynamoDBCache.new(env_config)
          elsif env_config['type'] == 'activerecord'
            require_relative 'backends/activerecord'
            ActiveRecordCache.new(env_config)
          else
            raise ArgumentError, "Unsupported cache type #{env_config['type']}"
          end
        end
    end
  end
end
