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
require 'hula/service_broker/api'

RSpec.describe Hula::ServiceBroker::Api do

  let(:http_client) { instance_double(Hula::ServiceBroker::HttpJsonClient) }

  subject(:api) do
    described_class.new(
      url:        'https://foobar.com/baz',
      username:   'admin',
      password:   'hunter2',
      http_client: http_client
    )
  end

  describe '#debug' do

    let(:debug_response) { {debug: rand(10)} }

    before do
      allow(http_client).to receive(:get).with(
        URI.parse('https://foobar.com/baz/debug'),
        auth: {
          username: 'admin',
          password: 'hunter2'
        }
      ).and_return(debug_response)
    end

    subject(:debug) { api.debug }

    it 'returns the debug hash' do
      expect(debug).to eql(debug_response)
    end
  end

  describe '#catalog' do
    before do
      allow(http_client).to receive(:get).with(
        URI.parse('https://foobar.com/baz/v2/catalog'),
        auth: {
          username: 'admin',
          password: 'hunter2'
        }
      ).and_return(
        services: [
          {
            id: 'EEA47C3A-569C-4C24-869D-0ADB5B337A4C',
            name: 'p-redis',
            description: 'Redis service to provide a key-value store',
            bindable: true,
            plans: [
              {
                id: 'C210CA06-E7E5-4F5D-A5AA-7A2C51CC290E',
                name: 'shared-vm',
                description: 'some description'
              }
            ]
          }
        ]
      )
    end

    subject(:catalog) { api.catalog }

    it { is_expected.to be_a(Hula::ServiceBroker::Catalog) }
    it 'has correct catalog' do
      expect(catalog).to eq(
        Hula::ServiceBroker::Catalog.new(
          services: [
            {
              id: 'EEA47C3A-569C-4C24-869D-0ADB5B337A4C',
              name: 'p-redis',
              description: 'Redis service to provide a key-value store',
              bindable: true,
              plans: [
                {
                  id: 'C210CA06-E7E5-4F5D-A5AA-7A2C51CC290E',
                  name: 'shared-vm',
                  description: 'some description'
                }
              ]
            }
          ]
        )
      )
    end
  end

  describe '#provision_instance' do

    before do
      allow(http_client).to receive(:put).with(
        URI('https://foobar.com/baz/v2/service_instances/service_instance_id'),
        body: {
          service_id: 'service_id',
          plan_id: 'plan_id'
        },
        auth: {
          username: 'admin',
          password: 'hunter2'
        }
      )
    end

    it 'asks the service broker to provision an instance' do
      expect(http_client).to receive(:put).with(
        URI('https://foobar.com/baz/v2/service_instances/service_instance_id'),
        body: {
            service_id: 'service_id',
            plan_id: 'plan_id'
        },
        auth: {
            username: 'admin',
            password: 'hunter2'
        }
      )

      service = Hula::ServiceBroker::Service.new(
                     id: 'service_id',
                     name: 'some service',
                     description: '',
                     bindable: true,
                     plans: [{
                               id: 'plan_id',
                               name: 'cunning plan',
                               description: 'dastardly as all hell'
                             }]
      )

      api.provision_instance(service.plans.first, service_instance_id: 'service_instance_id')
    end

    it 'returns the provisioned service instance details' do
      service = Hula::ServiceBroker::Service.new(
        id: 'service_id',
        name: 'some service',
        description: '',
        bindable: true,
        plans: [{
                  id: 'plan_id',
                  name: 'cunning plan',
                  description: 'dastardly as all hell'
                }]
      )

      service_instance = api.provision_instance(
        service.plans.first,
        service_instance_id: 'service_instance_id'
      )
      expect(service_instance).to eq(Hula::ServiceBroker::ServiceInstance.new(id: 'service_instance_id'))
    end
  end

  describe '#deprovision_instance' do
    it 'asks the service broker to provision an instance' do
      expect(http_client).to receive(:delete).with(
                               URI('https://foobar.com/baz/v2/service_instances/service_instance_id'),
                               auth: {
                                 username: 'admin',
                                 password: 'hunter2'
                               }
                             )

      service_instance = Hula::ServiceBroker::ServiceInstance.new(id: 'service_instance_id')
      api.deprovision_instance(service_instance)
    end
  end

  describe '#bind_instance' do
    before do
      allow(http_client).to receive(:put).with(
          URI('https://foobar.com/baz/v2/service_instances/service_instance_id/service_bindings/binding_id'),
          body: {},
          auth: {
              username: 'admin',
              password: 'hunter2'
          }
      ).and_return(credentials: { secret: 'i dislike cabbage'})
    end

    it 'asks the service broker to bind an instance' do
      expect(http_client).to receive(:put).with(
         URI('https://foobar.com/baz/v2/service_instances/service_instance_id/service_bindings/binding_id'),
         body: {},
         auth: {
             username: 'admin',
             password: 'hunter2'
         }
      )

      api.bind_instance(
          Hula::ServiceBroker::ServiceInstance.new(id: 'service_instance_id'),
          binding_id: 'binding_id'
      )
    end

    it 'returns the binding details' do
      service_instance = Hula::ServiceBroker::ServiceInstance.new(id: 'service_instance_id')

      instance_binding = api.bind_instance(
        service_instance,
        binding_id: 'binding_id'
      )

      expect(instance_binding).to eq(Hula::ServiceBroker::InstanceBinding.new(
        id: 'binding_id',
        credentials: {secret: 'i dislike cabbage'},
        service_instance: service_instance
      ))
    end
  end

  describe '#unbind_instance' do
    it 'asks the service broker to unbind an instance' do
      expect(http_client).to receive(:delete).with(
        URI('https://foobar.com/baz/v2/service_instances/service_instance_id/service_bindings/binding_id'),
        auth: {
          username: 'admin',
          password: 'hunter2'
        }
      )

      api.unbind_instance(
        Hula::ServiceBroker::InstanceBinding.new(
          id: 'binding_id',
          service_instance: Hula::ServiceBroker::ServiceInstance.new(id: 'service_instance_id'),
          credentials: {}
        )
      )
    end
  end
end
