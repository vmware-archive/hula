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
require 'hula/cloud_foundry'
require 'support/heredoc'

require 'logger'

describe Hula::CloudFoundry do
  using Helpers::Heredoc

  let(:options) do
    {
      domain: '10.244.0.34.xip.io',
      api_url: 'api.10.244.0.34.xip.io',
      username: 'admin',
      password: 'admin',
      logger: Logger.new('/dev/null'),
      target_and_login: false
    }
  end

  subject(:cloud_foundry) { Hula::CloudFoundry.new(options) }

  describe '#start_app' do
    let(:options) do
      {
        domain: '10.244.0.34.xip.io',
        api_url: 'api.10.244.0.34.xip.io',
        username: 'admin',
        password: 'admin',
        logger: Logger.new('/dev/null'),
        target_and_login: false
      }
    end

    let(:fake_open3) { class_double(Open3).as_stubbed_const }
    let(:app_name) { 'fake-app' }
    let(:stdout_stderr) { '' }
    let(:exitstatus) { 0 }
    let(:status) { instance_double(Process::Status, exitstatus: exitstatus, success?: exitstatus == 0) }

    before do
      allow(fake_open3).to receive(:capture2e)
        .with(anything, "cf start #{app_name}")
        .and_return([stdout_stderr, status])
    end

    it 'initialises the API URL to use HTTPS' do
      expect(cloud_foundry.url_for_app(app_name)).to eq("https://#{app_name}.#{cloud_foundry.domain}")
    end

    it 'calls cf with the expected args' do
      expected_path = '/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin/:sbin'

      expect(fake_open3).to receive(:capture2e) { |env, cmd|
        expect(cmd).to eq("cf start #{app_name}")
        expect(env).to include('PATH' => expected_path)
        expect(env).to have_key('CF_HOME')
      }.and_return([stdout_stderr, status])

      cloud_foundry.start_app(app_name)
    end

    context 'when "cf start" succeeds' do
      let(:stdout_stderr) { 'APP_START FAKE STDOUT / STDERR' }

      it 'return stdout and stderr' do
        expect(cloud_foundry.start_app(app_name)).to eq(stdout_stderr)
      end
    end

    context 'when "cf start" fails' do
      let(:exitstatus) { 99 }
      let(:log_stdout_stderr) { 'LOG FAKE STDOUT / STDERR' }
      let(:log_exitstatus) { 0 }
      let(:log_status) { instance_double(Process::Status, exitstatus: log_exitstatus) }

      before do
        allow(fake_open3).to receive(:capture2e)
          .with(anything, "cf logs --recent #{app_name}")
          .and_return([log_stdout_stderr, log_status])
      end

      it 'raises an error' do
        expect { cloud_foundry.start_app(app_name) }.to raise_error(/Command failed! - cf start #{app_name}/)
      end

      it 'calls "cf logs --recent"' do
        expect(fake_open3).to receive(:capture2e)
          .with(anything, "cf logs --recent #{app_name}")

        expect { cloud_foundry.start_app(app_name) }.to raise_error
      end

      context 'when "cf logs --recent" fails' do
        let(:log_exitstatus) { 999 }

        it 'raises an error' do
          expect { cloud_foundry.start_app(app_name) }.to raise_error(/Command failed! - cf start #{app_name}/)
        end

        it 'calls "cf logs --recent"' do
          expect(fake_open3).to receive(:capture2e)
            .with(anything, "cf logs --recent #{app_name}")

          expect { cloud_foundry.start_app(app_name) }.to raise_error
        end
      end
    end
  end

  describe 'info' do
    let(:command_runner) { instance_double(Hula::CommandRunner, run: nil) }
    let(:options) do
      {
        domain: '10.244.0.34.xip.io',
        api_url: 'api.10.244.0.34.xip.io',
        username: 'admin',
        password: 'admin',
        logger: Logger.new('/dev/null'),
        command_runner: command_runner,
        target_and_login: false
      }
    end

    before do
      allow(command_runner).to receive(:run).with('cf curl /v2/info', anything).and_return(
        <<-OUTPUT.strip_heredoc
        {
           "name": "",
           "build": "",
           "support": "http://support.cloudfoundry.com",
           "version": 0,
           "description": "",
           "authorization_endpoint": "https://login.bosh-lite.com",
           "token_endpoint": "https://uaa.bosh-lite.com",
           "min_cli_version": null,
           "min_recommended_cli_version": null,
           "api_version": "2.51.0",
           "app_ssh_endpoint": "ssh.bosh-lite.com:2222",
           "app_ssh_host_key_fingerprint": "a6:d1:08:0b:b0:cb:9b:5f:c4:ba:44:2a:97:26:19:8a",
           "app_ssh_oauth_client": "ssh-proxy",
           "routing_endpoint": "https://api.bosh-lite.com/routing",
           "logging_endpoint": "wss://loggregator.bosh-lite.com:443",
           "doppler_logging_endpoint": "wss://doppler.bosh-lite.com:4443"
        }
        OUTPUT
      )
    end

    it 'returns CloudFoundry info' do
      expect(cloud_foundry.info).to include("doppler_logging_endpoint" => "wss://doppler.bosh-lite.com:4443")
    end
  end

  describe '#version' do
    it 'uses v6.X of the cf binary' do
      expect(cloud_foundry.version).to match(/\b6\./)
    end
  end

  describe '#marketplace' do
    let(:options) do
      {
        domain: '10.244.0.34.xip.io',
        api_url: 'api.10.244.0.34.xip.io',
        username: 'admin',
        password: 'admin',
        logger: Logger.new('/dev/null'),
        command_runner: command_runner,
        target_and_login: false
      }
    end

    let(:command_runner) { instance_double(Hula::CommandRunner, run: nil) }

    before do
      allow(command_runner).to receive(:run).with('cf marketplace', anything).and_return(
        <<-OUTPUT.strip_heredoc
        Getting services from marketplace in org ije3ftux_1 / space test as admin...
        OK

        No service offerings found
        OUTPUT
      )
    end

    it 'executes the expected cf command' do
      expect(cloud_foundry.marketplace).to include('Getting services from marketplace in org ije3ftux_1')
    end
  end

  describe '#service_brokers' do
    let(:command_runner) { instance_double(Hula::CommandRunner, run: nil) }

    let(:options) do
      {
        domain: '10.244.0.34.xip.io',
        api_url: 'api.10.244.0.34.xip.io',
        username: 'admin',
        password: 'admin',
        logger: Logger.new('/dev/null'),
        command_runner: command_runner,
        target_and_login: false
      }
    end

    subject(:service_brokers) { cloud_foundry.service_brokers }

    context 'there are no service brokers' do
      before do
        allow(command_runner).to receive(:run).with('cf service-brokers', anything).and_return(
          <<-OUTPUT.strip_heredoc
          Getting service brokers as admin...

          name   url
          No service brokers found
          OUTPUT
        )
      end

      it 'returns an empty list' do
        expect(service_brokers.length).to eq(0)
      end
    end

    context 'there are a few service brokers' do
      before do
        allow(command_runner).to receive(:run).with('cf service-brokers', anything).and_return(
          <<-OUTPUT.strip_heredoc
          Getting service brokers as admin...

          name   url
          broker_one http://example.com:5656
          broker_two http://example.com:5657
          OUTPUT
        )
      end

      it 'returns a list of the brokers' do
        expect(service_brokers).to eq([
          Hula::CloudFoundry::ServiceBroker.new(name: 'broker_one', url: 'http://example.com:5656'),
          Hula::CloudFoundry::ServiceBroker.new(name: 'broker_two', url: 'http://example.com:5657')
        ])
      end
    end
  end

  describe '#app_vcap_services' do
    let(:command_runner) { instance_double(Hula::CommandRunner, run: nil) }

    let(:options) do
      {
        domain: '10.244.0.34.xip.io',
        api_url: 'api.10.244.0.34.xip.io',
        username: 'admin',
        password: 'admin',
        logger: Logger.new('/dev/null'),
        command_runner: command_runner,
        target_and_login: false
      }
    end

    before do
      allow(command_runner).to receive(:run).with('cf env test-app', anything).and_return(
           <<-OUTPUT.strip_heredoc
          Getting env variables for app test-app in org test / space test as admin...

          {
            "VCAP_SERVICES": {
              "username" : "admin",
              "password" : "passwd"
            }
          }
          OUTPUT
        )
    end

    it 'returns the VCAP_SERVICES environment variable of an app' do
      expect(cloud_foundry.app_vcap_services('test-app')).to eq({"username"=>"admin", "password"=>"passwd"})
    end
  end

  describe '#auth_token' do
    let(:command_runner) { instance_double(Hula::CommandRunner, run: nil) }

    let(:options) do
      {
        domain: '10.244.0.34.xip.io',
        api_url: 'api.10.244.0.34.xip.io',
        username: 'admin',
        password: 'admin',
        logger: Logger.new('/dev/null'),
        command_runner: command_runner,
        target_and_login: false
      }
    end

    before do
      allow(command_runner).to receive(:run).with('cf oauth-token', anything).and_return(
           <<-OUTPUT.strip_heredoc
          Getting OAuth token...
          OK

          bearer dummy-token
          OUTPUT
        )
    end

    it 'returns the token' do
      expect(cloud_foundry.auth_token).to eq("bearer dummy-token")
    end
  end

  describe '#get_service_status' do
    let(:command_runner) { instance_double(Hula::CommandRunner, run: nil) }

    let(:options) do
      {
        domain: '10.244.0.34.xip.io',
        api_url: 'api.10.244.0.34.xip.io',
        username: 'admin',
        password: 'admin',
        logger: Logger.new('/dev/null'),
        command_runner: command_runner,
        target_and_login: false
      }
    end

    before do
      allow(command_runner).to receive(:run).with('cf service foo', anything).and_return(
        <<-OUTPUT.strip_heredoc
        Service instance: foo
        Service: p-redis-on-demand
        Bound apps:
        Tags:
        Plan: small-odb-redis-cache
        Description: On demand Redis
        Documentation url:
        Dashboard:

        Last Operation
        Status: create succeeded
        Message: Instance provisioning in progress
        Started: 2017-03-02T13:38:16Z
        Updated: 2017-03-02T13:38:20Z
        OUTPUT
      )
    end

    it 'returns create succeeded' do
      expect(cloud_foundry.get_service_status('foo')).to eq('create succeeded')
    end

    context 'when using new CF CLI' do
      before do
        allow(command_runner).to receive(:run).with('cf service foo', anything).and_return(
          <<-OUTPUT.strip_heredoc
          name:            cf-service-e3f1623d
          service:         p-rabbitmq
          bound apps:
          tags:
          plan:            standard
          description:     RabbitMQ service to provide shared instances of this high-performance multi-protocol messaging broker.
          documentation:
          dashboard:       https://pivotal-rabbitmq.sys.indianyellow.cf-app.com/#/login/mu-f13d6938-d7fb-4f38-adba-580fafeaea3c-63var95oq62qh0epockc80v9va/1109609106924918457219576760747236301576

          Showing status of last operation from service cf-service-e3f1623d...

          status:    create succeeded
          message:
          started:   2018-02-28T12:28:04Z
          updated:   2018-02-28T12:28:0
          OUTPUT
          )
      end

      it 'returns create succeeded' do
        expect(cloud_foundry.get_service_status('foo')).to eq('create succeeded')
      end
    end

    context 'when create service fails' do
      before do
        allow(command_runner).to receive(:run).with('cf service foo', anything).and_return(
          <<-OUTPUT.strip_heredoc
          Service instance: foo
          Service: p-redis-on-demand
          Bound apps:
          Tags:
          Plan: small-odb-redis-cache
          Description: On demand Redis
          Documentation url:
          Dashboard:

          Last Operation
          Status: failed
          Message: Instance provisioning in progress
          Started: 2017-03-02T13:38:16Z
          Updated: 2017-03-02T13:38:20Z
          OUTPUT
        )
      end

      it 'returns failed' do
        expect(cloud_foundry.get_service_status('foo')).to eq('failed')
      end
    end

    context 'when create service is in progress' do
      before do
        allow(command_runner).to receive(:run).with('cf service foo', anything).and_return(
          <<-OUTPUT.strip_heredoc
          Service instance: foo
          Service: p-redis-on-demand
          Bound apps:
          Tags:
          Plan: small-odb-redis-cache
          Description: On demand Redis
          Documentation url:
          Dashboard:

          Last Operation
          Status: create in progress
          Message: Instance provisioning in progress
          Started: 2017-03-02T13:38:16Z
          Updated: 2017-03-02T13:38:20Z
          OUTPUT
        )
      end

      it 'returns create in progress' do
        expect(cloud_foundry.get_service_status('foo')).to eq('create in progress')
      end
    end

    context 'when service instance is not found' do
      before do
        allow(command_runner).to receive(:run).with('cf service foo', anything).and_return(
          <<-OUTPUT.strip_heredoc
          FAILED
          Service instance foo not found
          OUTPUT
        )
      end

      it 'returns service instance not found' do
        expect(cloud_foundry.get_service_status('foo')).to eq('Service instance foo not found')
      end
    end
  end
end
