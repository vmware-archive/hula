# Copyright (c) 2014-2015 Pivotal Software, Inc.
# All rights reserved.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#

require 'tmpdir'
require 'json'
require 'open3'
require 'tempfile'

require 'hula/command_runner'
require 'hula/cloud_foundry/service_broker'

module Hula
  class CloudFoundry
    attr_reader :current_organization, :current_space, :domain, :api_url

    def initialize(args)
      @domain = args.fetch(:domain)
      @api_url = args.fetch(:api_url)
      @logger = args.fetch(:logger, default_logger)
      @command_runner = args.fetch(:command_runner, default_command_runner)

      target_and_login = args.fetch(:target_and_login, true)
      if target_and_login
        target(api_url)
        login(args.fetch(:username), args.fetch(:password))
      end
    end

    def auth_token
      cf("oauth-token").lines.last.strip!
    end

    def url_for_app(app_name)
      "https://#{app_name}.#{domain}"
    end

    def target(cloud_controller_url)
      cf("api #{cloud_controller_url} --skip-ssl-validation")
    end

    def app_vcap_services(app_name)
      app_environment(app_name)["VCAP_SERVICES"]
    end

    def login(username, password, allow_failure = true)
      cf("auth #{username} #{password}", allow_failure: allow_failure)
    end

    def service_brokers
      output = cf('service-brokers')

      if output.include?('No service brokers found')
        []
      else
        output.split("\n").drop(3).map do |row|
          name, url = row.split(/\s+/)
          ServiceBroker.new(name: name, url: url)
        end
      end
    end

    def create_and_target_org(name)
      create_org(name)
      sleep 1
      target_org(name)
    end

    def create_org(name)
      cf("create-org #{name}")
    end

    def target_org(name)
      cf("target -o #{name}")
      @current_organization = name
    end

    def create_and_target_space(name)
      create_space(name)
      target_space(name)
    end

    def create_space(name)
      cf("create-space #{name}")
    end

    def target_space(name)
      cf("target -s #{name}")
      @current_space = name
    end

    def space_exists?(name)
      spaces = cf('spaces').lines[3..-1]
      spaces.map(&:strip).include?(name)
    end

    def org_exists?(name)
      orgs = cf('orgs').lines[3..-1]
      orgs.map(&:strip).include?(name)
    end

    def setup_permissive_security_group(org, space)
      rules = [{
        'destination' => '0.0.0.0-255.255.255.255',
        'protocol' => 'all'
      }]

      rule_file = Tempfile.new('default_security_group.json')
      rule_file.write(rules.to_json)
      rule_file.close

      cf("create-security-group prof-test #{rule_file.path}")
      cf("bind-security-group prof-test #{org} #{space}")
      cf('bind-staging-security-group prof-test')
      cf('bind-running-security-group prof-test')

      rule_file.unlink
    end

    def delete_space(name, options = {})
      allow_failure = options.fetch(:allow_failure, true)
      cf("delete-space #{name} -f", allow_failure: allow_failure)
    end

    def delete_org(name, options = {})
      allow_failure = options.fetch(:allow_failure, true)
      cf("delete-org #{name} -f", allow_failure: allow_failure)
    end

    alias_method :reset!, :delete_org

    def add_public_service_broker(service_name, _service_label, url, username, password)
      cf("create-service-broker #{service_name} #{username} #{password} #{url}")

      service_plans = JSON.parse(cf('curl /v2/service_plans -X GET'))
      guids = service_plans['resources'].map do |resource|
        resource['metadata']['guid']
      end

      guids.each do |guid|
        cf(%(curl /v2/service_plans/#{guid} -X PUT -d '{"public":true}'))
      end
    end

    def remove_service_broker(service_name, options = {})
      allow_failure = options.fetch(:allow_failure, true)
      cf("delete-service-broker #{service_name} -f", allow_failure: allow_failure)
    end

    def assert_broker_is_in_marketplace(type)
      output = marketplace
      unless output.include?(type)
        fail "Broker #{type} not found in marketplace"
      end
    end

    def marketplace
      cf('marketplace')
    end

    def create_service_instance(type, name, plan)
      cf("create-service #{type} #{plan} #{name}")
    end

    def delete_service_instance_and_unbind(name, options = {})
      allow_failure = options.fetch(:allow_failure, true)
      cf("delete-service -f #{name}", allow_failure: allow_failure)
    end

    def assert_instance_is_in_services_list(service_name)
      output = cf('services')
      unless output.include?(service_name)
        fail "Instance #{service_name} not found in services list"
      end
    end

    def push_app_and_start(app_path, name)
      push_app(app_path, name)
      start_app(name)
    end

    def push_app(app_path, name)
      cf("push #{name} -p #{app_path} -n #{name} -d #{domain} --no-start")
    end

    def enable_diego_for_app(name)
      cf("enable-diego #{name}")
    end

    def delete_app(name, options = {})
      allow_failure = options.fetch(:allow_failure, true)
      cf("delete #{name} -f", allow_failure: allow_failure)
    end

    def bind_app_to_service(app_name, service_name)
      cf("bind-service #{app_name} #{service_name}")
    end

    def unbind_app_from_service(app_name, service_name)
      cf("unbind-service #{app_name} #{service_name}")
    end

    def list_service_keys(service_instance_name)
      cf("service-keys #{service_instance_name}")
    end

    def create_service_key(service_instance_name, key_name)
      cf("create-service-key #{service_instance_name} #{key_name}")
    end

    def delete_service_key(service_instance_name, key_name)
      cf("delete-service-key #{service_instance_name} #{key_name} -f")
    end

    def service_key(service_instance_name, key_name)
      cf("service-key #{service_instance_name} #{key_name}")
    end

    def restart_app(name)
      stop_app(name)
      start_app(name)
    end

    def start_app(name)
      cf("start #{name}")
    rescue => start_exception
      begin
        cf("logs --recent #{name}")
      ensure
        raise start_exception
      end
    end

    def stop_app(name)
      cf("stop #{name}")
    end

    def app_env(app_name)
      cf("env #{app_name}")
    end

    def create_user(username, password)
      cf("create-user #{username} #{password}")
    end

    def delete_user(username)
      cf("delete-user -f #{username}")
    end

    def user_exists?(username, org)
      output = cf("org-users #{org}")
      output.lines.select { |l| l.start_with? '  ' }.map(&:strip).uniq.include?(username)
    end

    def set_org_role(username, org, role)
      cf("set-org-role #{username} #{org} #{role}")
    end

    def version
      cf('-v')
    end

    def info
      output = cf("curl /v2/info")
      JSON.parse(output)
    end

    private

    attr_reader :logger, :command_runner

    def app_environment(app_name)
      env_output = cf("env #{app_name}")
      response = env_output[/^\{.*}$/m].split(/^\n/)
      response = response.map { |json| JSON.parse(json) }
      response.inject({}) { |result, current| result.merge(current) }
    end

    def default_logger
      @default_logger ||= begin
        STDOUT.sync = true
        require 'logger'
        Logger.new(STDOUT)
      end
    end

    def default_command_runner
      @default_command_runner ||= CommandRunner.new(environment: env)
    end

    def cf(command, options = {})
      allow_failure = options.fetch(:allow_failure, false)
      cf_command = "cf #{command}"

      logger.info(cf_command)

      command_runner.run(cf_command, allow_failure: allow_failure)
    end

    def env
      @env ||= ENV.to_hash.merge(
        'PATH'    => clean_path,
        'CF_HOME' => Dir.mktmpdir('cf-home')
      )
    end

    def clean_path
      '/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin/:sbin'
    end
  end
end
