require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class GenericOauth2 < OmniAuth::Strategies::OAuth2
      # Give your strategy a name.
      option :name, GlobalConfig.polizei('auth_name')

      # This is where you pass the options you would pass when
      # initializing your consumer from the OAuth gem.
      option :client_options, {:site => GlobalConfig.polizei('auth_url')}

      option :client_id, GlobalConfig.polizei('auth_client_id')
      option :client_secret, GlobalConfig.polizei('auth_client_secret')

      # These are called after authentication has succeeded. If
      # possible, you should try to set the UID without making
      # additional calls (if the user id is returned with the token
      # or as a URI parameter). This may not be possible with all
      # providers.
      uid { raw_info['user']['id'] }

      info do
        raw_info
      end

      def raw_info
        @raw_info ||= access_token.get(GlobalConfig.polizei('auth_user_url')).parsed
      end
    end
  end
end
