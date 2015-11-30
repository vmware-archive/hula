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

      def initialize(url:, username:, password:, http_client: HttpJsonClient.new)
        @http_client = http_client

        @url = URI(url)
        @username = username
        @password = password
      end

      attr_reader :url

      def catalog
        json = http_client.get(url_for('/v2/catalog'), auth: { username: username, password: password })
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

      def deprovision_instance(service_instance)
        http_deprovision_service(service_instance_id: service_instance.id)
      end

      def bind_instance(service_instance, binding_id: SecureRandom.uuid)
        result = http_bind_instance(
          service_instance_id: service_instance.id,
          binding_id: binding_id
        )

        InstanceBinding.new(
          id: binding_id,
          credentials: result.fetch(:credentials),
          service_instance: service_instance
        )
      end

      def unbind_instance(instance_binding)
        http_unbind_instance(
          service_instance_id: instance_binding.service_instance.id,
          binding_id: instance_binding.id
        )
      end

      def debug
        http_client.get(url_for('/debug'), auth: { username: username, password: password })
      end

      private

      def http_provision_instance(service_instance_id:, service_id:, plan_id:)
        http_client.put(
          url_for("/v2/service_instances/#{service_instance_id}"),
          body: {
            service_id: service_id,
            plan_id: plan_id,
          },
          auth: { username: username, password: password }
        )
      end

      def http_deprovision_service(service_instance_id:)
        http_client.delete(
          url_for("/v2/service_instances/#{service_instance_id}"),
          auth: {
            username: username,
            password: password
          }
        )
      end

      def http_bind_instance(service_instance_id:, binding_id:)
        http_client.put(
          url_for("/v2/service_instances/#{service_instance_id}/service_bindings/#{binding_id}"),
          body: {},
          auth: { username: username, password: password }
        )
      end

      def http_unbind_instance(service_instance_id:, binding_id:)
        http_client.delete(
          url_for("/v2/service_instances/#{service_instance_id}/service_bindings/#{binding_id}"),
          auth: { username: username, password: password }
        )
      end

      def url_for(path)
        url.dup.tap { |uri| uri.path += path }
      end

      attr_reader :http_client, :username, :password
    end
  end
end
