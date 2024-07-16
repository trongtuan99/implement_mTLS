# frozen_string_literal: true

module Interactors
  class Exp < Base

    def get_something payload
      url = "#{@hook_url}/hook/something"
      resource = set_rest_client_resource url
      response = resource.get(headers.merge(payload))
      JSON.parse(response.body)
    end

    def post_something payload
      url = "#{@hook_url}/hook/something"
      resource = set_rest_client_resource url
      response = resource.post(payload.to_json, headers)
      JSON.parse(response.body)
    end

  end
end

#service = Interactors::Exp.new('tenant')
#service.get_something({data: 'test'})
#service.post_something({content: 'post-content'})