# Copyright (c) 2014-2015 Pivotal Software, Inc.
# All rights reserved.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#

require 'forwardable'
require 'hula/service_broker/catalog'
require 'hula/service_broker/instance_binding'
require 'hula/service_broker/http_json_client'
require 'hula/service_broker/service_instance'

require 'securerandom'

module Hula
  module ServiceBroker
    class Api
      extend Forwardable
      def_delegators :catalog, :service_plan

      def initialize(url:, username:, password:, http_client: HttpJsonClient.new, broker_api_version:)
        @http_client = http_client

        @url = URI(url)
        @username = username
        @password = password
        @broker_api_version = broker_api_version
      end

      attr_reader :url

      def catalog
        json = http_client.get(url_for('/v2/catalog'), auth: { username: username, password: password }, headers: { 'X-Broker-Api-Version': @broker_api_version })
        Catalog.new(json)
      end

      def provision_instance(plan, service_instance_id: SecureRandom.uuid)
        http_provision_instance(
          service_id: plan.service_id,
          plan_id: plan.id,
          service_instance_id: service_instance_id
        )

        ServiceInstance.new(id: service_instance_id)
      end

      def deprovision_instance(service_instance, plan)
        http_deprovision_service(service_instance_id: service_instance.id, plan_id: plan.id, service_id: plan.service_id)
      end

      def bind_instance(service_instance, plan, binding_id: SecureRandom.uuid)
        result = http_bind_instance(
          service_instance_id: service_instance.id,
          binding_id: binding_id,
          service_id: plan.service_id,
          plan_id: plan.id
        )

        InstanceBinding.new(
          id: binding_id,
          credentials: result.fetch(:credentials),
          service_instance: service_instance
        )
      end

      def unbind_instance(instance_binding, plan)
        http_unbind_instance(
          service_instance_id: instance_binding.service_instance.id,
          binding_id: instance_binding.id,
          service_id: plan.service_id,
          plan_id: plan.id
        )
      end

      def debug
        http_client.get(url_for('/debug'), auth: { username: username, password: password }, headers: { 'X-Broker-Api-Version': @broker_api_version })
      end

      private

      def http_provision_instance(service_instance_id:, service_id:, plan_id:)
        http_client.put(
          url_for("/v2/service_instances/#{service_instance_id}"),
          body: {
            service_id: service_id,
            plan_id: plan_id,
          },
          auth: { username: username, password: password },
          headers: { 'X-Broker-Api-Version': @broker_api_version }
        )
      end

      def http_deprovision_service(service_instance_id:, plan_id:, service_id:)
        uri = url.dup
        uri.path = uri.path += "/v2/service_instances/#{service_instance_id}"
        params = { :'plan_id' => plan_id, :'service_id' => service_id}
        uri.query = URI.encode_www_form(params)
        http_client.delete(
          uri,
          auth: {
            username: username,
            password: password
          },
          headers: { 'X-Broker-Api-Version': @broker_api_version }
        )
      end

      def http_bind_instance(service_instance_id:, binding_id:, service_id:, plan_id:)
        http_client.put(
          url_for("/v2/service_instances/#{service_instance_id}/service_bindings/#{binding_id}"),
          body: {
            service_id: service_id,
            plan_id: plan_id,
          },
          auth: { username: username, password: password },
          headers: { 'X-Broker-Api-Version': @broker_api_version }
        )
      end

      def http_unbind_instance(service_instance_id:, binding_id:, service_id:, plan_id:)
        uri = url.dup
        uri.path = uri.path += "/v2/service_instances/#{service_instance_id}/service_bindings/#{binding_id}"
        params = { :'plan_id' => plan_id, :'service_id' => service_id}
        uri.query = URI.encode_www_form(params)

        http_client.delete(
          uri,
          auth: { username: username, password: password },
          headers: { 'X-Broker-Api-Version': @broker_api_version }
        )
      end

      def url_for(path)
        url.dup.tap { |uri| uri.path += path }
      end

      attr_reader :http_client, :username, :password
    end
  end
end
