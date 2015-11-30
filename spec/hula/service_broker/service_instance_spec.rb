# Copyright (c) 2014-2015 Pivotal Software, Inc.
# All rights reserved.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#

require 'spec_helper'
require 'hula/service_broker/service_instance'

require 'ostruct'

RSpec.describe Hula::ServiceBroker::ServiceInstance do
  describe 'equality' do
    it 'requires the object to be the same class' do
      a_1 = Hula::ServiceBroker::ServiceInstance.new(id: 'id')
      b_1 = OpenStruct.new(id: 'id')

      expect(a_1).to_not eq(b_1)
    end

    it 'requires the ids to be equal' do
      a_1 = Hula::ServiceBroker::ServiceInstance.new(id: 'id_a')
      a_2 = Hula::ServiceBroker::ServiceInstance.new(id: 'id_a')
      b_1 = Hula::ServiceBroker::ServiceInstance.new(id: 'id_b')

      expect(a_1).to eq(a_2)

      expect(a_1).to_not eq(b_1)
    end
  end
end
