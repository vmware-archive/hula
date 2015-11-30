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
require 'hula/service_broker/catalog'

RSpec.describe Hula::ServiceBroker::Catalog do

  subject(:instance) do
    Hula::ServiceBroker::Catalog.new(
      services: [
        service_2_config,
        service_1_config
      ]
    )
  end

  let(:service_1_config) {
    {
      id: 'SERVICE_ID_1',
      name: 'service_1',
      description: 'Service 1',
      bindable: true,
      plans: [plan_1_1_config]
    }
  }

  let (:plan_1_1_config) {
    {
      id: 'SOME-OTHER-PLAN-ID',
      name: 'plan_1_1',
      description: 'some description'
    }
  }

  let(:service_2_config) {
    {
      id: 'SERVICE_ID_2',
      name: 'service_2',
      description: 'Redis service to provide a key-value store',
      bindable: true,
      plans: [plan_2_1_config]
    }
  }

  let (:plan_2_1_config) {
    {
      id: 'C210CA06-E7E5-4F5D-A5AA-7A2C51CC290E',
      name: 'plan_2_1',
      description: 'some description'
    }
  }


  let(:service_1) { Hula::ServiceBroker::Service.new(service_1_config) }
  let(:service_2) { Hula::ServiceBroker::Service.new(service_2_config) }

  let(:plan_1_1) { Hula::ServiceBroker::Plan.new(plan_1_1_config.merge(service_id: 'SERVICE_ID_1')) }
  let(:plan_2_1) { Hula::ServiceBroker::Plan.new(plan_2_1_config.merge(service_id: 'SERVICE_ID_2')) }

  describe '#service' do
    it 'retrives the service by name' do
      expect(instance.service('service_1')).to eq(service_1)
      expect(instance.service('service_2')).to eq(service_2)
      expect {
        instance.service('some unknown service')
      }.to raise_error(
        Hula::ServiceBroker::ServiceNotFoundError,
        /some unknown service/
      )
    end
  end

  describe '#service_plan' do
    it 'retrives a plan by service name and plan name' do
      expect(instance.service_plan('service_1', 'plan_1_1')).to eq(plan_1_1)
      expect(instance.service_plan('service_2', 'plan_2_1')).to eq(plan_2_1)
      expect {
        instance.service_plan('some unknown service', 'plan_1_1')
      }.to raise_error(
        Hula::ServiceBroker::NotInCatalog,
        /some unknown service/
      )
    end
  end

  describe 'equality' do
    let(:service_args) do
      {
        id: 'SERVICE_ID',
        name: 'SERVICE_NAME',
        description: 'SERVICE_DESC',
        bindable: true,
        plans: [
          {
            id: 'PLAN_ID',
            name: 'PLAN_NAME',
            description: 'PLAN_DESCRIPTION'
          }
        ]
      }
    end

    it 'requires same services' do
      a_1 = Hula::ServiceBroker::Catalog.new(services: [service_args])
      a_2 = Hula::ServiceBroker::Catalog.new(services: [service_args])
      b_1 = Hula::ServiceBroker::Catalog.new(services: [service_args.merge(id: '123')])

      expect(a_1).to eq(a_2)

      expect(a_1).to_not eq(b_1)
    end
  end

end
