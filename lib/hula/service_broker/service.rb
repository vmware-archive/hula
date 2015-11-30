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
require 'hula/service_broker/plan'

module Hula
  module ServiceBroker
    class Service
      def initialize(args = {})
        @id          = args.fetch(:id)
        @name        = args.fetch(:name)
        @description = args.fetch(:description)
        @bindable    = !!args.fetch(:bindable)
        @plans       = args.fetch(:plans).map { |p| Plan.new(p.merge(service_id: self.id)) }
      end

      attr_reader :id, :name, :description, :bindable, :plans

      def ==(other)
        is_a?(other.class) &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          bindable == other.bindable &&
          plans == other.plans
      end

      def plan(plan_name)
        plans.find { |p| p.name == plan_name } or
          fail(PlanNotFoundError, [
            %{Unknown plan with name: #{plan_name.inspect}},
            "  Known plan names are: #{plans.map(&:name).inspect}"
            ].join("\n")
          )
      end

    end
  end
end
