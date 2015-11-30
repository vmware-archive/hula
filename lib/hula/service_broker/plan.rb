# Copyright (c) 2014-2015 Pivotal Software, Inc.
# All rights reserved.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#

module Hula
  module ServiceBroker
    class Plan
      def initialize(args = {})
        @id = args.fetch(:id)
        @name = args.fetch(:name)
        @description = args.fetch(:description)
        @service_id = args.fetch(:service_id)
      end

      attr_reader :id, :name, :description, :service_id

      def ==(other)
        is_a?(other.class) &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          service_id == other.service_id
      end
    end
  end
end
