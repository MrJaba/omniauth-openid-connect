require 'addressable/uri'
require "net/http"
require 'omniauth'
require "openid_connect"

module OmniAuth
  module Strategies
    class OpenIDConnect
      include OmniAuth::Strategy

      option :client_options, {
        identifier: nil,
        secret: nil,
        redirect_uri: nil,
        scheme: "https",
        host: nil,
        port: 443,
        authorization_endpoint: "/authorize",
        token_endpoint: "/token",
        userinfo_endpoint: "/userinfo"
      }
      option :scope, [:openid]
      option :response_type, "code"
      option :state
      option :response_mode
      option :display, nil#, [:page, :popup, :touch, :wap]
      option :prompt, nil#, [:none, :login, :consent, :select_account]
      option :max_age
      option :ui_locales
      option :id_token_hint
      option :login_hint
      option :acr_values

      uid { user_info.sub }

      info do
        {
          name: user_info.name,
          email: user_info.email,
          nickname: user_info.preferred_username,
          first_name: user_info.given_name,
          last_name: user_info.family_name,
          gender: user_info.gender,
          image: user_info.picture,
          phone: user_info.phone_number,
          urls: { website: user_info.website }
        }
      end

      extra do
        { raw_info: user_info.as_json(:skip_validation => true) }
      end

      credentials do
        {
          token: access_token.access_token,
          refresh_token: access_token.refresh_token,
          expires_in: access_token.expires_in,
          scope: access_token.scope
        }
      end

      def client
        @client ||= ::OpenIDConnect::Client.new(client_options)
      end

      def request_phase
        redirect authorize_uri
      end

      def callback_phase
        client.redirect_uri = callback_url
        client.authorization_code = authorization_code
        access_token
        super
      end

      def authorization_code
        request.params["code"]
      end

      def authorize_uri
        client.redirect_uri = callback_url
        url_params = {response_type: options.response_type,
                      scope: options.scope}
        url_params.merge!({hd: client_options.domain}) if client_options.domain
        client.authorization_uri(url_params)
      end

      private

      def callback_url
        client_options.redirect_uri || (full_host + script_name + callback_path)
      end

      def user_info
        @user_info ||= access_token.userinfo!
      end

      def access_token
        @access_token ||= client.access_token!(:client_auth_method => :query)
      end

      def client_options
        options.client_options
      end

      def nonce
        session[:nonce] = SecureRandom.hex(16)
      end

      def session
        @env.nil? ? {} : super
      end
    end
  end
end

OmniAuth.config.add_camelization 'openid_connect', 'OpenIDConnect'
