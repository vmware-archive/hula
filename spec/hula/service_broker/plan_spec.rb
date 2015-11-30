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
require 'hula/service_broker/plan'
require 'hula/service_broker/service'

require 'ostruct'

RSpec.describe Hula::ServiceBroker::Plan do

  describe 'equality' do
    let(:args) { {name: 'NAME', id: 'ID', description: 'DESC', service_id: 'SERVICE'} }

    it 'requires class to be equal' do
      a_1 = Hula::ServiceBroker::Plan.new(args)
      b_1 = OpenStruct.new(args)

      expect(a_1).to_not eq(b_1)
    end

    it 'requires id to be equal' do
      a_1 = Hula::ServiceBroker::Plan.new(args.merge(id: 'IDA'))
      a_2 = Hula::ServiceBroker::Plan.new(args.merge(id: 'IDA'))
      b_1 = Hula::ServiceBroker::Plan.new(args.merge(id: 'IDB'))

      expect(a_1).to eq(a_2)

      expect(a_1).to_not eq(b_1)
    end

    it 'requires name to be equal' do
      a_1 = Hula::ServiceBroker::Plan.new(args.merge(name: 'NAMEA'))
      a_2 = Hula::ServiceBroker::Plan.new(args.merge(name: 'NAMEA'))
      b_1 = Hula::ServiceBroker::Plan.new(args.merge(name: 'NAMEB'))

      expect(a_1).to eq(a_2)

      expect(a_1).to_not eq(b_1)
    end

    it 'requires description to be equal' do
      a_1 = Hula::ServiceBroker::Plan.new(args.merge(description: 'DESCA'))
      a_2 = Hula::ServiceBroker::Plan.new(args.merge(description: 'DESCA'))
      b_1 = Hula::ServiceBroker::Plan.new(args.merge(description: 'DESCB'))

      expect(a_1).to eq(a_2)

      expect(a_1).to_not eq(b_1)
    end

    it 'requires service_id to be equal' do
      a_1 = Hula::ServiceBroker::Plan.new(args.merge(service_id: 'service_a'))
      a_2 = Hula::ServiceBroker::Plan.new(args.merge(service_id: 'service_a'))
      b_1 = Hula::ServiceBroker::Plan.new(args.merge(service_id: 'service_b'))

      expect(a_1).to eq(a_2)

      expect(a_1).to_not eq(b_1)
    end
  end

end
