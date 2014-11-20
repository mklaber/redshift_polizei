module Caches
  module Creator
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def self.extended(other)
        other.instance_variable_set(:@mtx, Mutex.new)
      end

      def cache
        # double checks to try to avoid locking costs once setup
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
            DynamoDBCache.new(env_config)
          else
            raise ArgumentError, "Unsupported cache type #{env_config['type']}"
          end
        end
    end
  end
end
