# Copyright (c) 2014-2015 Pivotal Software, Inc.
# All rights reserved.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#

require 'hula/service_broker/errors'
require 'hula/service_broker/service'

module Hula
  module ServiceBroker

    class Catalog
      attr_reader :services

      def initialize(args = {})
        @services = args.fetch(:services).map { |s| Service.new(s) }
      end

      def ==(other)
        is_a?(other.class) &&
          services == other.services
      end

      def service(service_name)
        services.find { |s| s.name == service_name } or
          fail(ServiceNotFoundError, [
            %{Unknown service with name: #{service_name.inspect}},
            "  Known service names: #{services.map(&:name).inspect}"
            ].join("\n")
          )
      end

      def service_plan(service_name, plan_name)
        service(service_name).plan(plan_name)
      end
    end
  end
end
