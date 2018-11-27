# Copyright (c) 2014-2015 Pivotal Software, Inc.
# All rights reserved.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#

require 'hula/service_broker/api'

require 'forwardable'

module Hula
  module ServiceBroker
    class Client

      extend Forwardable
      def_delegators :api,
                     :catalog,
                     :debug,
                     :deprovision_instance,
                     :bind_instance,
                     :unbind_instance,
                     :url

      def initialize(args = {})
        api_args = args.reject { |k, _v| k == :api }
        @api = args.fetch(:api) { Api.new(api_args) }
      end

      def provision_and_bind(service_name, plan_name, &block)
        raise Error, 'no block given' unless block_given?
        plan = catalog.service_plan(service_name, plan_name)

        provision_instance(service_name, plan_name) do |service_instance|
          bind_instance(service_instance, service_name, plan_name, &block)
        end
      end

      def provision_instance(service_name, plan_name, &block)
        plan = catalog.service_plan(service_name, plan_name)
        service_instance = api.provision_instance(plan)
        return service_instance unless block

        begin
          block.call(service_instance)
        ensure
          api.deprovision_instance(service_instance, plan)
        end
      end

      def bind_instance(service_instance, service_name, plan_name, &block)
        plan = catalog.service_plan(service_name, plan_name)

        binding = api.bind_instance(service_instance, plan)
        return binding unless block

        begin
          block.call(binding, service_instance)
        ensure
          api.unbind_instance(binding, plan)
          sleep 1
        end
      end

      private

      attr_reader :api
    end
  end
end
