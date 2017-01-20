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
require 'hula/bosh_director'

require 'logger'
require 'yaml'
require 'tmpdir'

module Hula
  describe BoshDirector do
    let(:bosh_target) { 'http://bosh:25555' }
    let(:manifest_path) { 'path/to/manifest.yml' }
    let(:bosh_config_path) { '/tmp/path/to/bosh/config' }
    let(:username) { 'admin' }
    let(:password) { 'p4ssw0rd' }
    let(:command_runner) { double(CommandRunner, run: nil) }
    let(:bosh_command_prefix) { "bosh -v -n --config '#{bosh_config_path}'" }
    let(:bosh_director_args) do
      {
        target_url: bosh_target,
        manifest_path: manifest_path,
        username: username,
        password: password,
        command_runner: command_runner,
        logger: Logger.new('/dev/null')
      }
    end
    let(:bosh_director) { BoshDirector.new(bosh_director_args) }
    let(:yaml_manifest) { YAML.load_file(asset_path('example_manifest.yaml')) }

    before do
      allow(YAML).to receive(:load_file).with(manifest_path).and_return(yaml_manifest)
      allow(Tempfile).to receive(:new).with('bosh_config').and_return(double(File, path: bosh_config_path))
    end

    def runs_bosh_command(command)
      expect(command_runner).to receive(:run).with(/#{bosh_command_prefix} #{command}/).ordered
    end

    describe '.initialize' do
      context 'when there is a deployment manifest' do
        it 'targets, sets the deployment, and logs in to bosh' do
          runs_bosh_command "target #{bosh_target}"
          runs_bosh_command "deployment #{manifest_path}"
          runs_bosh_command "login #{username} #{password}"

          bosh_director
        end
      end

      context 'when deployment manifest argument is nil' do
        let(:manifest_path) { nil }

        it 'just targets and logs in to bosh' do
          runs_bosh_command "target #{bosh_target}"
          runs_bosh_command "login #{username} #{password}"

          bosh_director
        end
      end

      context 'when there is no deployment manifest argument' do
        let(:bosh_director_args) do
          {
            target_url: bosh_target,
            username: username,
            password: password,
            command_runner: command_runner,
            logger: Logger.new('/dev/null')
          }
        end

        it 'just targets and logs in to bosh' do
          runs_bosh_command "target #{bosh_target}"
          runs_bosh_command "login #{username} #{password}"

          bosh_director
        end
      end
    end

    describe '#deploy' do
      it 'deploys the constructor manifest' do
        runs_bosh_command '--deployment path/to/manifest.yml deploy'

        bosh_director.deploy
      end

      it 'can be given a manifest as an argument' do
        runs_bosh_command '--deployment path/to/new_manifest.yml deploy'

        bosh_director.deploy 'path/to/new_manifest.yml'
      end
    end

    describe '#delete_deployment' do
      it 'deletes a deployment' do
        runs_bosh_command 'delete deployment a-deployment-name'

        bosh_director.delete_deployment('a-deployment-name')
      end

      it 'can be forced' do
        runs_bosh_command 'delete deployment a-deployment-name -f'

        bosh_director.delete_deployment('a-deployment-name', force: true)
      end
    end

    describe '#run_errand' do
      context 'when initialized with manifest' do
        it 'runs an errand' do
          runs_bosh_command "--deployment #{manifest_path} run errand an-errand-name"
          bosh_director.run_errand('an-errand-name')
        end

        it 'keeps the errand alive' do
          runs_bosh_command "--deployment #{manifest_path} run errand an-errand-name --keep-alive"
          bosh_director.run_errand('an-errand-name', keep_alive: true)
        end
      end

      context 'when initialized with no manifest' do
        let(:bosh_director_args) do
          {
            target_url: bosh_target,
            username: username,
            password: password,
            command_runner: command_runner,
            logger: Logger.new('/dev/null')
          }
        end

        it 'raises an error' do
          expect {
            bosh_director.run_errand('an-errand-name')
          }.to raise_error(Hula::BoshDirector::NoManifestSpecified)
        end
      end

      context 'when custom manifest specified' do
        it 'runs an errand' do
          runs_bosh_command '--deployment /some/custom/path run errand an-errand-name'

          bosh_director.run_errand('an-errand-name', manifest_path: '/some/custom/path')
        end

        it 'keeps the errand alive' do
          runs_bosh_command '--deployment /some/custom/path run errand an-errand-name --keep-alive'

          bosh_director.run_errand('an-errand-name', manifest_path: '/some/custom/path', keep_alive: true)
        end
      end
    end

    describe '#lite?' do
      context 'the director url we are targetting is the lite one' do
        let(:bosh_target) { 'https://192.168.50.4:25555' }

        it 'returns true' do
          expect(bosh_director.lite?).to be_truthy
        end
      end

      context "when the url isn't exactly perfect but is good enough" do
        let(:bosh_target) { '192.168.50.4' }

        it 'is lenient with the target url (similar to the bosh cli)' do
          expect(bosh_director.lite?).to be_truthy
        end
      end

      context 'the director url we are targetting is not the lite one' do
        let(:bosh_target) { 'https://foo.com:25555' }

        it 'returns false' do
          expect(bosh_director.lite?).to be_falsey
        end
      end
    end

    describe 'logfile methods' do
      let(:tar_tf_output) do
%q{
./
./monit/
./monit/nginx_ctl.err.log
./cf-redis-broker/
./cf-redis-broker/cf-redis-broker.stderr.log
./cf-redis-broker/cf-redis-broker.stdout.log
}
      end

      before do
        allow(command_runner).to receive(:run).with(/tar tf/).and_return(tar_tf_output)
      end

      describe '#job_logfiles' do
        it 'returns a list of log files' do
          runs_bosh_command 'logs cf-redis-broker 0 --job --dir'
          logfiles = bosh_director.job_logfiles('cf-redis-broker')

          expect(logfiles).not_to include(/monit/)
          expect(logfiles).to include('cf-redis-broker.stdout.log')
          expect(logfiles).to include('cf-redis-broker.stderr.log')
        end
      end

      describe '#has_logfiles?' do
        it 'returns true if the job has the log file' do
          runs_bosh_command 'logs cf-redis-broker 0 --job --dir'

          expect(bosh_director.has_logfiles?('cf-redis-broker', ['nginx_ctl.err.log', 'cf-redis-broker.stderr.log'])).to be_truthy
          expect(bosh_director.has_logfiles?('cf-redis-broker', ['another.err.log'])).to be_falsey
        end
      end
    end

    describe '#deployment_names' do
      context 'when there are deployments' do
        let(:bosh_output) do
          %{
              +--------------------------------+--------------------------------+-------------------------------+
              | Name                           | Release(s)                     | Stemcell(s)                   |
              +--------------------------------+--------------------------------+-------------------------------+
              | cf-89b4fc7c86b12d1a5a82        | cf/169                         | bosh-vsphere-esxi-ubuntu/2366 |
              |                                | push-console-release/6         |                               |
              |                                | runtime-verification-errands/1 |                               |
              +--------------------------------+--------------------------------+-------------------------------+
              | p-redis-fjf836egfjkvofu3ge     | cf-redis/123                   | bosh-vsphere-esxi-ubuntu/2366 |
              +--------------------------------+--------------------------------+-------------------------------+
              | p-mongodb-e0a89c190b3c470988f3 | cf-mongodb/68                  | bosh-vsphere-esxi-ubuntu/2366 |
              +--------------------------------+--------------------------------+-------------------------------+
              | p-neo4j-8e6e8f7e8fe8f7e8f7e    | cf-neo4j/66                    | bosh-vsphere-esxi-ubuntu/2366 |
              +--------------------------------+--------------------------------+-------------------------------+

              Deployments total: 2
          }
        end

        before do
          allow(command_runner).to receive(:run).with("#{bosh_command_prefix} deployments").and_return(bosh_output)
        end

        it 'returns a list of deployments' do
          expect(bosh_director.deployment_names).to eq(%w{
            cf-89b4fc7c86b12d1a5a82
            p-redis-fjf836egfjkvofu3ge
            p-mongodb-e0a89c190b3c470988f3
            p-neo4j-8e6e8f7e8fe8f7e8f7e
          })
        end
      end

      context 'when there are no deployments' do
        let(:bosh_output) do
          %{
            No deployments
          }
        end

        before do
          allow(command_runner).to receive(:run).with("#{bosh_command_prefix} deployments").and_return(bosh_output)
        end

        it 'returns an empty list' do
          expect(bosh_director.deployment_names).to eq([])
        end
      end
    end

    describe '#ips_for_job' do
      context 'when BOSH CLI is less than 1.3184' do
        let(:bosh_vms_output) do
          %{
    Deployment `cf-redis'

    Director task 654

    Task 654 done

    +-------------------+---------+----------------+-------------+
    | Job/index         | State   | Resource Pool  | IPs         |
    +-------------------+---------+----------------+-------------+
    | unknown/unknown   | running | services-small | 10.244.3.34 |
    | unknown/unknown   | running | services-small | 10.244.3.38 |
    | cf-redis-broker/0 | running | services-small | 10.244.3.46 |
    +-------------------+---------+----------------+-------------+

    VMs total: 3
    Deployment `cf-warden'

    Director task 655

    Task 655 done

    +------------------------------------+---------+---------------+--------------+
    | Job/index                          | State   | Resource Pool | IPs          |
    +------------------------------------+---------+---------------+--------------+
    | api_z1/0                           | running | large_z1      | 10.244.0.138 |
    | etcd_leader_z1/0                   | running | medium_z1     | 10.244.0.38  |
    | ha_proxy_z1/0                      | running | router_z1     | 10.244.0.34  |
    | hm9000_z1/0                        | running | medium_z1     | 10.244.0.142 |
    | loggregator_trafficcontroller_z1/0 | running | small_z1      | 10.244.0.10  |
    | loggregator_z1/0                   | running | medium_z1     | 10.244.0.14  |
    | login_z1/0                         | running | medium_z1     | 10.244.0.134 |
    | nats_z1/0                          | running | medium_z1     | 10.244.0.6   |
    | postgres_z1/0                      | running | medium_z1     | 10.244.0.30  |
    | router_z1/0                        | running | router_z1     | 10.244.0.22  |
    | router_z1/1                        | running | router_z1     | 10.244.0.26  |
    | uaa_z1/0                           | running | medium_z1     | 10.244.0.130 |
    +------------------------------------+---------+---------------+--------------+

    VMs total: 12
          }
        end

        before do
          allow(command_runner).to receive(:run).with("#{bosh_command_prefix} vms ").and_return(bosh_vms_output)
        end

        it 'returns a list of ips for that job' do
          expect(bosh_director.ips_for_job('cf-redis-broker')).to eq(['10.244.3.46'])
          expect(bosh_director.ips_for_job('router_z1')).to eq(['10.244.0.22', '10.244.0.26'])
          expect(bosh_director.ips_for_job('non_existant_job')).to eq([])
        end

        context 'when release name is provided' do
          let(:bosh_vms_output) do
          %{
    Deployment `cf-redis'

    Director task 654

    Task 654 done

    +-------------------+---------+----------------+-------------+
    | Job/index         | State   | Resource Pool  | IPs         |
    +-------------------+---------+----------------+-------------+
    | unknown/unknown   | running | services-small | 10.244.3.34 |
    | unknown/unknown   | running | services-small | 10.244.3.38 |
    | cf-redis-broker/0 | running | services-small | 10.244.3.46 |
    +-------------------+---------+----------------+-------------+

    VMs total: 3
          }
          end

          it 'only searches inside the given release' do
            expect(command_runner).to receive(:run).with("#{bosh_command_prefix} vms cf-redis").twice.and_return(bosh_vms_output)

            expect(bosh_director.ips_for_job('cf-redis-broker', 'cf-redis')).to eq(['10.244.3.46'])
            expect(bosh_director.ips_for_job('router_z1', 'cf-redis')).to eq([])
          end
        end
      end

      context 'when BOSH CLI is equal or greater than 1.3184' do
        let(:bosh_vms_output) do
          %{
    Deployment 'cf-redis'

    Director task 654

    Task 654 done

    +---------------------------------------------------------+---------+-----+----------------+-------------+
    | VM                                                      | State   | AZ  | VM Type        | IPs         |
    +---------------------------------------------------------+---------+-----+----------------+-------------+
    | unknown/unknown (fe04916e-afd0-42a3-aaf5-52a8b163f1ab)  | running | n/a | services-small | 10.244.3.34 |
    | unknown/unknown (fe04916e-afd0-42a3-aaf5-52a8b163f1ab)  | running | n/a | services-small | 10.244.3.38 |
    | cf-redis-broker/0 (fe04916e-afd0-42a3-aaf5-52a8b163f1ab)| running | n/a | services-small | 10.244.3.46 |
    +---------------------------------------------------------+---------+-----+----------------+-------------+

    VMs total: 3
    Deployment 'cf-warden'

    Director task 655

    Task 655 done

    +---------------------------------------------------------------------------+---------+-----+---------------+--------------+
    | VM                                                                        | State   | AZ  | VM Type       | IPs          |
    +---------------------------------------------------------------------------+---------+-----+---------------+--------------+
    | api_z1/0                           (fe04916e-afd0-42a3-aaf5-52a8b163f1ab) | running | n/a | large_z1      | 10.244.0.138 |
    | etcd_leader_z1/0                   (fe04916e-afd0-42a3-aaf5-52a8b163f1ab) | running | n/a | medium_z1     | 10.244.0.38  |
    | ha_proxy_z1/0                      (fe04916e-afd0-42a3-aaf5-52a8b163f1ab) | running | n/a | router_z1     | 10.244.0.34  |
    | hm9000_z1/0                        (fe04916e-afd0-42a3-aaf5-52a8b163f1ab) | running | n/a | medium_z1     | 10.244.0.142 |
    | loggregator_trafficcontroller_z1/0 (fe04916e-afd0-42a3-aaf5-52a8b163f1ab) | running | n/a | small_z1      | 10.244.0.10  |
    | loggregator_z1/0                   (fe04916e-afd0-42a3-aaf5-52a8b163f1ab) | running | n/a | medium_z1     | 10.244.0.14  |
    | login_z1/0                         (fe04916e-afd0-42a3-aaf5-52a8b163f1ab) | running | n/a | medium_z1     | 10.244.0.134 |
    | nats_z1/0                          (fe04916e-afd0-42a3-aaf5-52a8b163f1ab) | running | n/a | medium_z1     | 10.244.0.6   |
    | postgres_z1/0                      (fe04916e-afd0-42a3-aaf5-52a8b163f1ab) | running | n/a | medium_z1     | 10.244.0.30  |
    | router_z1/0                        (fe04916e-afd0-42a3-aaf5-52a8b163f1ab) | running | n/a | router_z1     | 10.244.0.22  |
    | router_z1/1                        (fe04916e-afd0-42a3-aaf5-52a8b163f1ab) | running | n/a | router_z1     | 10.244.0.26  |
    | uaa_z1/0                           (fe04916e-afd0-42a3-aaf5-52a8b163f1ab) | running | n/a | medium_z1     | 10.244.0.130 |
    +---------------------------------------------------------------------------+---------+-----+---------------+--------------+

    VMs total: 12
          }
        end

        before do
          allow(command_runner).to receive(:run).with("#{bosh_command_prefix} vms ").and_return(bosh_vms_output)
        end

        it 'returns a list of ips for that job' do
          expect(bosh_director.ips_for_job('cf-redis-broker')).to eq(['10.244.3.46'])
          expect(bosh_director.ips_for_job('router_z1')).to eq(['10.244.0.22', '10.244.0.26'])
          expect(bosh_director.ips_for_job('non_existant_job')).to eq([])
        end


        context 'when release name is provided' do
          let(:bosh_vms_output) do
          %{
    Deployment `cf-redis'

    Director task 654

    Task 654 done

    +-------------------+---------+-----+----------------+-------------+
    | VM                | State   | AZ  | VM Type        | IPs         |
    +-------------------+---------+-----+----------------+-------------+
    | unknown/unknown   | running | n/a | services-small | 10.244.3.34 |
    | unknown/unknown   | running | n/a | services-small | 10.244.3.38 |
    | cf-redis-broker/0 | running | n/a | services-small | 10.244.3.46 |
    +-------------------+---------+-----+----------------+-------------+

    VMs total: 3
          }
          end

          it 'only searches inside the given release' do
            expect(command_runner).to receive(:run).with("#{bosh_command_prefix} vms cf-redis").twice.and_return(bosh_vms_output)

            expect(bosh_director.ips_for_job('cf-redis-broker', 'cf-redis')).to eq(['10.244.3.46'])
            expect(bosh_director.ips_for_job('router_z1', 'cf-redis')).to eq([])
          end
        end
      end

    end

    describe '#recreate_instance' do
      context 'when the job does not exist in the manifest' do
        it 'raises an error' do
          expect { bosh_director.recreate_instance('non_existant_job', 0) }.to raise_error(ArgumentError)
        end
      end

      context 'when the job exists in the manifest' do
        it 'restarts each instance' do
          runs_bosh_command 'recreate cassandra_node 2'
          bosh_director.recreate_instance('cassandra_node', 2)
        end
      end

      context 'when the instance does not exist' do
        it 'does not attempt to recreate any instances' do
          expect(command_runner).not_to receive(:run).with(/recreate/)
          expect{
            bosh_director.recreate_instance("cassandra_node", 3)
          }.to raise_error(ArgumentError)
        end
      end
    end

    describe '#recreate' do
      scenarios = [
        {bosh_version: 'v1', manifest: 'example_manifest.yaml'},
        {bosh_version: 'v2', manifest: 'example_v2_manifest.yaml'},
      ]

      scenarios.each do |scenario|
        context "with a BOSH #{scenario[:bosh_version]} manifest" do
          let(:yaml_manifest) { YAML.load_file(asset_path(scenario[:manifest])) }

          context 'when the job does not exist in the manifest' do
              it 'raises an error' do
                expect { bosh_director.recreate('non_existant_job') }.to raise_error(ArgumentError)
              end
            end

          context 'when the job exists in the manifest' do
            it 'restarts each instance' do
              runs_bosh_command 'recreate cassandra_node 0'
              runs_bosh_command 'recreate cassandra_node 1'
              runs_bosh_command 'recreate cassandra_node 2'
              bosh_director.recreate('cassandra_node')
            end
          end

          context 'when the job has 0 instances' do
            it 'does not attempt to recerate any instances' do
              expect(command_runner).not_to receive(:run).with(/recreate/)
              bosh_director.recreate('cassandra_node_with_no_instances')
            end
          end
        end
      end
    end

    describe '#stop' do
      context 'when the job does not exist in the manifest' do
        it 'raises an error' do
          expect { bosh_director.stop('non_existant_job', 0) }.to raise_error(ArgumentError)
        end
      end

      context 'when the job exists in the manifest' do
        it 'stops the job/index with --force' do
          runs_bosh_command 'stop cassandra_node 1 --force'
          bosh_director.stop('cassandra_node', 1)
        end
      end

      context 'when the job has 0 instances' do
        it 'does not attempt to stop the instance' do
          expect(command_runner).not_to receive(:run).with(/stop/)
          expect{
            bosh_director.stop("cassandra_node", 3)
          }.to raise_error(ArgumentError)
        end
      end
    end

    describe '#start' do
      context 'when the job does not exist in the manifest' do
        it 'raises an error' do
          expect { bosh_director.start('non_existant_job', 0) }.to raise_error(ArgumentError)
        end
      end

      context 'when the job exists in the manifest' do
        it 'starts the job/index with --force' do
          runs_bosh_command 'start cassandra_node 1 --force'
          bosh_director.start('cassandra_node', 1)
        end
      end

      context 'when the job has 0 instances' do
        it 'does not attempt to start the instance' do
          expect(command_runner).not_to receive(:run).with(/start/)
          expect{
            bosh_director.start("cassandra_node", 3)
          }.to raise_error(ArgumentError)
        end
      end
    end

    describe '#recreate_all' do
      it 'recreates each instance of each job' do
        runs_bosh_command 'recreate cf-cassandra-broker 0'
        runs_bosh_command 'recreate cassandra_node 0'
        runs_bosh_command 'recreate cassandra_node 1'
        runs_bosh_command 'recreate cassandra_node 2'
        bosh_director.recreate_all(['cf-cassandra-broker', 'cassandra_node'])
      end
    end
  end
end
