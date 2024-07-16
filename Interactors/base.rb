#on client

module Interactors
  class Base
    def initialize(tenant, lang = 'en')
      @hook_url   = ENV.fetch('HOOK_URL') || 'https://localhost:3002'
      @lang       = lang
      @tenant     = tenant
    end

    protected

    def headers
      {
        'X-API-VERSION'   => 'v1',
        'Content-Type'    => 'application/json',
        'Accept'          => 'application/json',
        'X-API-TENANT'    => @tenant,
        'Accept-Language' => @lang
      }
    end

    def set_rest_client_resource url
      RestClient::Resource.new(
        url,
        ssl_client_cert: OpenSSL::X509::Certificate.new(File.read('certs/client.crt')),
        ssl_client_key: OpenSSL::PKey::RSA.new(File.read('certs/client.key')),
        ssl_ca_file: 'certs/ca.crt',
        verify_ssl: OpenSSL::SSL::VERIFY_PEER
      )
    end

  end
end
