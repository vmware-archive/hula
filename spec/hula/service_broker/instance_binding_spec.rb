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
require 'hula/service_broker/instance_binding'
require 'hula/service_broker/service_instance'

require 'ostruct'

RSpec.describe Hula::ServiceBroker::InstanceBinding do

  describe 'equality' do

    let(:args) { {id: 'id', credentials: {some: 'stuff'}, service_instance: instance_double(Hula::ServiceBroker::ServiceInstance) } }

    it 'requires the same class' do
      a = Hula::ServiceBroker::InstanceBinding.new(args)
      b = OpenStruct.new(args)

      expect(a).to_not eq(b)
    end

    it 'requires the id to be the same' do
      a_1 = Hula::ServiceBroker::InstanceBinding.new(args.merge(id: 'id_a'))
      a_2 = Hula::ServiceBroker::InstanceBinding.new(args.merge(id: 'id_a'))
      b_1 = Hula::ServiceBroker::InstanceBinding.new(args.merge(id: 'id_b'))

      expect(a_1).to eq(a_2)

      expect(b_1).to_not eq(a_1)
    end

    it 'requires the credentials to be the same' do
      a_1 = Hula::ServiceBroker::InstanceBinding.new(args.merge(credentials: { 'secret' => 'a' }))
      a_2 = Hula::ServiceBroker::InstanceBinding.new(args.merge(credentials: { 'secret' => 'a' }))
      b_1 = Hula::ServiceBroker::InstanceBinding.new(args.merge(credentials: { 'secret' => 'b' }))

      expect(a_1).to eq(a_2)

      expect(b_1).to_not eq(a_1)
    end

    it 'requires the service_instance_id to be the same' do
      a = instance_double(Hula::ServiceBroker::ServiceInstance)
      b = instance_double(Hula::ServiceBroker::ServiceInstance)

      a_1 = Hula::ServiceBroker::InstanceBinding.new(args.merge(service_instance: a))
      a_2 = Hula::ServiceBroker::InstanceBinding.new(args.merge(service_instance: a))
      b_1 = Hula::ServiceBroker::InstanceBinding.new(args.merge(service_instance: b))

      expect(a_1).to eq(a_2)

      expect(b_1).to_not eq(a_1)
    end
  end

end
