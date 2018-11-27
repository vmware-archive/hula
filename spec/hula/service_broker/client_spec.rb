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
require 'hula/service_broker/client'
require 'hula/service_broker/api'
require 'hula/service_broker/errors'

RSpec.describe Hula::ServiceBroker::Client do

  let(:api) { instance_double(Hula::ServiceBroker::Api) }
  let(:catalog) {
    Hula::ServiceBroker::Catalog.new(
      services: [
        {
          id: 'SERVICE_ID_1',
          name: 'service_1',
          description: 'Service 1',
          bindable: true,
          plans: [plan_config]
        }
      ]
    )
  }

  let(:plan_config) {
    {
      id: 'PLAN_1',
      name: 'plan_1',
      description: 'Plan 1'
    }
  }

  let(:plan) {
    Hula::ServiceBroker::Plan.new(plan_config.merge(service_id: 'SERVICE_ID_1'))
  }

  let(:args) { { api: api } }

  subject(:instance) { described_class.new(args) }

  describe '#provision_and_bind' do
    let(:service_instance) { instance_double(Hula::ServiceBroker::ServiceInstance) }
    let(:binding) { instance_double(Hula::ServiceBroker::InstanceBinding) }

    before do
      allow(api).to receive(:catalog).and_return(catalog)
      allow(api).to receive(:provision_instance).and_return(service_instance)
      allow(api).to receive(:bind_instance).and_return(binding)
      allow(api).to receive(:unbind_instance)
      allow(api).to receive(:deprovision_instance)
    end

    context 'without block' do
      it 'raises no block given' do
        expect { instance.provision_and_bind('service_1', 'plan_1') }.to raise_error(Hula::ServiceBroker::Error, 'no block given')
      end
    end

    context 'with block' do
      it 'provision and binds the service yielding the binding and cleaning up' do
        expect(api).to receive(:provision_instance).with(plan).ordered
        expect(api).to receive(:bind_instance).with(service_instance, plan).ordered
        expect(api).to receive(:unbind_instance).with(binding, plan).ordered
        expect(api).to receive(:deprovision_instance).with(service_instance, plan).ordered

        expect { |b| instance.provision_and_bind('service_1', 'plan_1', &b) }.to yield_with_args(binding, service_instance)
      end

      context 'fails to provision service' do
        it 'raises the original exception and attemps to clean up' do
          allow(api).to receive(:provision_instance) { raise Hula::ServiceBroker::Error, 'my exception' }

          expect(api).to receive(:provision_instance)
          expect(api).to_not receive(:bind_instance)
          expect(api).to_not receive(:unbind_instance)
          expect(api).to_not receive(:deprovision_instance)

          expect {
            instance.provision_and_bind('service_1', 'plan_1') {}
          }.to raise_error(Hula::ServiceBroker::Error, /my exception/)
        end
      end
      context 'fails to create binding' do
        it 'raises the original exeception and attempts to clean up' do
          allow(api).to receive(:bind_instance) { raise Hula::ServiceBroker::Error, 'my exception' }

          expect(api).to receive(:provision_instance)
          expect(api).to receive(:bind_instance)
          expect(api).to_not receive(:unbind_instance)
          expect(api).to receive(:deprovision_instance)

          expect {
            instance.provision_and_bind('service_1', 'plan_1') {}
          }.to raise_error(Hula::ServiceBroker::Error, /my exception/)
        end
      end
      context 'fails to deprovision service' do
        it 'raises the original exeception' do
          allow(api).to receive(:deprovision_instance) { raise Hula::ServiceBroker::Error, 'my exception' }

          expect(api).to receive(:provision_instance)
          expect(api).to receive(:bind_instance)
          expect(api).to receive(:unbind_instance)
          expect(api).to receive(:deprovision_instance)

          expect {
            instance.provision_and_bind('service_1', 'plan_1') {}
          }.to raise_error(Hula::ServiceBroker::Error, /my exception/)
        end
      end
      context 'block throws error' do
        it 'raises the original exeception and cleans up' do
          expect(api).to receive(:provision_instance)
          expect(api).to receive(:bind_instance)
          expect(api).to receive(:unbind_instance)
          expect(api).to receive(:deprovision_instance)

          expect {
            instance.provision_and_bind('service_1', 'plan_1') { raise StandardError, 'my exception' }
          }.to raise_error(StandardError, /my exception/)
        end
      end
    end
  end

  describe '#provision_instance' do
    let(:service_instance) { instance_double(Hula::ServiceBroker::ServiceInstance) }
    let(:binding) { instance_double(Hula::ServiceBroker::InstanceBinding) }

    before do
      allow(api).to receive(:catalog).and_return(catalog)
      allow(api).to receive(:provision_instance).and_return(service_instance)
      allow(api).to receive(:deprovision_instance)
    end

    context 'without block' do
      it 'returns the service instance' do
        expect(api).to receive(:provision_instance).with(plan)
        expect(api).to_not receive(:deprovision_instance)

        expect(instance.provision_instance('service_1', 'plan_1')).to be(service_instance)
      end
    end

    context 'with block' do
      it 'provision the service yielding the service_instance and cleaning up' do
        expect(api).to receive(:provision_instance).with(plan).ordered
        expect(api).to receive(:deprovision_instance).with(service_instance, plan).ordered

        expect { |b| instance.provision_instance('service_1', 'plan_1', &b) }.to yield_with_args(service_instance)
      end

      context 'fails to provision service' do
        it 'raises the original exception and attemps to clean up' do
          allow(api).to receive(:provision_instance) { fail Hula::ServiceBroker::Error, 'my exception' }

          expect(api).to receive(:provision_instance)
          expect(api).to_not receive(:deprovision_instance)

          expect {
            instance.provision_instance('service_1', 'plan_1') {}
          }.to raise_error(Hula::ServiceBroker::Error, /my exception/)
        end
      end
      context 'fails to deprovision service' do
        it 'raises the original exeception' do
          allow(api).to receive(:deprovision_instance) { fail Hula::ServiceBroker::Error, 'my exception' }

          expect(api).to receive(:provision_instance)
          expect(api).to receive(:deprovision_instance)

          expect {
            instance.provision_instance('service_1', 'plan_1') {}
          }.to raise_error(Hula::ServiceBroker::Error, /my exception/)
        end
      end
      context 'block throws error' do
        it 'raises the original exeception and cleans up' do
          expect(api).to receive(:provision_instance)
          expect(api).to receive(:deprovision_instance)

          expect {
            instance.provision_instance('service_1', 'plan_1') { fail StandardError, 'my exception' }
          }.to raise_error(StandardError, /my exception/)
        end
      end
    end
  end

  describe '#bind_instance' do
    let(:service_instance) { instance_double(Hula::ServiceBroker::ServiceInstance) }
    let(:binding) { instance_double(Hula::ServiceBroker::InstanceBinding) }

    before do
      allow(api).to receive(:catalog).and_return(catalog)
      allow(api).to receive(:bind_instance).and_return(binding)
      allow(api).to receive(:unbind_instance)
    end

    context 'without block' do
      it 'binds the service instance returning the credentials' do
        expect(api).to receive(:bind_instance).with(service_instance, plan)
        expect(api).to_not receive(:unbind_instance)

        expect(instance.bind_instance(service_instance, 'service_1', 'plan_1')).to be(binding)
      end
    end

    context 'with block' do
      it 'binds the service instance yielding the credentials and cleaning up' do
        expect(api).to receive(:bind_instance).with(service_instance, plan).ordered
        expect(api).to receive(:unbind_instance).with(binding, plan).ordered

        expect { |b| instance.bind_instance(service_instance, 'service_1', 'plan_1', &b) }.to yield_with_args(binding, service_instance)
      end

      context 'fails to bind service' do
        it 'raises the original exception and attemps to clean up' do
          allow(api).to receive(:bind_instance) { fail Hula::ServiceBroker::Error, 'my exception' }

          expect(api).to_not receive(:unbind_instance)

          expect {
            instance.bind_instance(service_instance, 'service_1', 'plan_1') {}
          }.to raise_error(Hula::ServiceBroker::Error, /my exception/)
        end
      end
      context 'fails to unbind service' do
        it 'raises the original exeception' do
          allow(api).to receive(:unbind_instance) { fail Hula::ServiceBroker::Error, 'my exception' }

          expect(api).to receive(:bind_instance)

          expect {
            instance.bind_instance(service_instance, 'service_1', 'plan_1') {}
          }.to raise_error(Hula::ServiceBroker::Error, /my exception/)
        end
      end
      context 'block throws error' do
        it 'raises the original exeception and cleans up' do
          expect(api).to receive(:bind_instance)
          expect(api).to receive(:unbind_instance)

          expect {
            instance.bind_instance(service_instance, 'service_1', 'plan_1') { fail StandardError, 'my exception' }
          }.to raise_error(StandardError, /my exception/)
        end
      end
    end
  end
end
