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
    class InstanceBinding
      attr_reader :id, :credentials, :service_instance

      def initialize(id:, credentials:, service_instance:)
        @id = id
        @credentials = credentials
        @service_instance = service_instance
      end

      def ==(other)
        is_a?(other.class) &&
          id == other.id &&
          credentials == other.credentials &&
          service_instance == other.service_instance
      end
    end
  end
end
