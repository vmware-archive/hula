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
require 'hula/service_broker/service'

require 'ostruct'

describe Hula::ServiceBroker::Service do

  let(:arguments) do
    {
      id: 'ID',
      name: 'NAME',
      description: 'DESC',
      bindable: true,
      plans: [ plan_1_config, plan_2_config ]
    }
  end

  let(:plan_1_config) {
    {
      id: 'PLAN_1',
      name: 'PLAN_NAME_1',
      description: 'PLAN_1_DESC'
    }
  }

  let(:plan_2_config) {
    {
      id: 'PLAN_2',
      name: 'PLAN_NAME_2',
      description: 'PLAN_2_DESC'
    }
  }

  def plan(config)
    Hula::ServiceBroker::Plan.new(config.merge(service_id: 'ID'))
  end

  describe '#plan' do
    let(:plan_1) { plan(plan_1_config) }
    let(:plan_2) { plan(plan_2_config) }

    it 'retrieves the plan based on the plan' do
      service = described_class.new(arguments)
      expect(service.plan('PLAN_NAME_1')).to eq(plan_1)
      expect(service.plan('PLAN_NAME_2')).to eq(plan_2)
      expect {
        service.plan('unknown plan name')
      }.to raise_error(Hula::ServiceBroker::PlanNotFoundError, /unknown plan name/)
    end
  end

  describe '#==' do
    it 'requires class to be equal' do
      a1 = Hula::ServiceBroker::Service.new(arguments)
      b1 = OpenStruct.new(arguments)

      expect(a1).to_not eq(b1)
    end

    it 'requires id to be equal' do
      a1 = Hula::ServiceBroker::Service.new(arguments.merge(id: 'id_a'))
      a2 = Hula::ServiceBroker::Service.new(arguments.merge(id: 'id_a'))
      b1 = Hula::ServiceBroker::Service.new(arguments.merge(id: 'id_b'))

      expect(a1).to eq(a2)

      expect(a1).to_not eq(b1)
    end

    it 'requires name to be equal' do
      a1 = Hula::ServiceBroker::Service.new(arguments.merge(name: 'name_a'))
      a2 = Hula::ServiceBroker::Service.new(arguments.merge(name: 'name_a'))
      b1 = Hula::ServiceBroker::Service.new(arguments.merge(name: 'name_b'))

      expect(a1).to eq(a2)

      expect(a1).to_not eq(b1)
    end

    it 'requires bindable to be equal' do
      a1 = Hula::ServiceBroker::Service.new(arguments.merge(bindable: true))
      a2 = Hula::ServiceBroker::Service.new(arguments.merge(bindable: true))
      b1 = Hula::ServiceBroker::Service.new(arguments.merge(bindable: false))

      expect(a1).to eq(a2)

      expect(a1).to_not eq(b1)
    end

    it 'requires plans to be equal' do
      a1 = Hula::ServiceBroker::Service.new(arguments.merge(plans: [id: 'id', name: 'name', description: 'description']))
      a2 = Hula::ServiceBroker::Service.new(arguments.merge(plans: [id: 'id', name: 'name', description: 'description']))
      b1 = Hula::ServiceBroker::Service.new(arguments.merge(plans: [id: 'ID', name: 'name', description: 'description']))

      expect(a1).to eq(a2)

      expect(a1).to_not eq(b1)
    end
  end
end
