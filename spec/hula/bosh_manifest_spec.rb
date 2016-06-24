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
require 'hula/bosh_manifest'

require 'tempfile'

RSpec.describe Hula::BoshManifest do
  subject(:bosh_manifest) { Hula::BoshManifest.new(manifest) }

  describe '.from_file' do
    context 'when the file does not exist' do
      let(:path) { '/a/path/to/a/missing/manifest.yml' }

      it 'raises an error' do
        expect {
          Hula::BoshManifest.from_file(path)
        }.to raise_error(/Could not open the manifest file: '#{path}'/)
      end
    end

    context 'when the file exists' do
      let(:path) { Tempfile.new('bosh_manifest').path }
      let(:manifest) do
        {
          'properties' => {
            'parent_property' => {
              'child_property' => 'value'
            }
          }
        }.to_yaml
      end

      before do
        File.write(path, manifest)
      end

      it 'loads the file so we can use it the same as if we used the constructor' do
        bosh_manifest = Hula::BoshManifest.from_file(path)
        expect(bosh_manifest.property('parent_property.child_property')).to eq('value')
      end
    end
  end

  describe '#initialize' do
    context 'when yaml is invalid' do
      let(:manifest) { 'NOT YAML' }

      it 'raises an error' do
        expect { Hula::BoshManifest.new(manifest) }.to raise_error(/Invalid manifest/)
      end
    end
  end

  describe '#deployment_name' do
    context 'when there is a deployment name key' do
      let(:manifest) { { 'name' => 'frank' }.to_yaml }

      it 'returns the deployment name' do
        expect(bosh_manifest.deployment_name).to eq('frank')
      end
    end

    context 'when there is no deployment name key' do
      let(:manifest) { {}.to_yaml }

      it 'raises an error' do
        expect {
          bosh_manifest.deployment_name
        }.to raise_error(/Could not find deployment name in {}/)
      end
    end
  end

  describe '#resource_pools' do
    let(:manifest) do
      {
        'resource_pools' => [
          {
            'cloud_properties' => {
              'name' => 'm3.medium',
              'ram' => 3840
            }
          },
          {
            'cloud_properties' => {
              'name' => 'c3.large',
              'ram' => 8888
            }
          }
        ]
      }.to_yaml
    end

    it 'returns a list of resource pools' do
      pools = bosh_manifest.resource_pools
      expect(pools.length).to eq(2)
      expect(pools.first['cloud_properties']['name']).to eq('m3.medium')
    end
  end

  describe "#jobs_by_regex" do
    let(:manifest) do
      {
        'jobs' => [
          {
            'name' => 'job-name',
            'instances' => 2,
            'networks' => [
              'name' => 'network-name',
              'static_ips' => %w(10.0.0.1 10.0.0.2)
            ]
          },
          {
            'name' => 'job-name-1',
            'instances' => 5,
            'networks' => [
              'name' => 'network-name-1',
              'static_ips' => %w(10.0.0.6 10.0.0.7)
            ]
          }
        ]
      }.to_yaml
    end

    context 'when a job exist' do
      it 'returns an array of jobs' do
        jobs = bosh_manifest.jobs_by_regexp(/^job-name/)
        expect(jobs.length).to eq(2)
        expect(jobs[0].instances).to eq(2)
        expect(jobs[1].instances).to eq(5)
      end
    end

    context 'when there are no jobs matched' do
      it 'raises an error' do
        expect {
          bosh_manifest.jobs_by_regexp(/jerb-name/)
        }.to raise_error(/Could not find job name/)
      end
    end

    context 'with a BOSH v2 style manifest' do
      let(:manifest) do
        {
          'instance_groups' => [
            {
              'name' => 'job-name',
              'instances' => 2,
              'networks' => [
                'name' => 'network-name',
                'static_ips' => %w(10.0.0.1 10.0.0.2)
              ]
            }
          ]
        }.to_yaml
      end

      it 'returns an array of jobs' do
        jobs = bosh_manifest.jobs_by_regexp(/^job-name/)
        expect(jobs.length).to eq(1)
        expect(jobs[0].instances).to eq(2)
      end
    end
  end

  describe '#job' do
    let(:manifest) do
      {
        'jobs' => [
          {
            'name' => 'job-name',
            'instances' => 2,
            'networks' => [
              {
                'name' => 'network-name',
                'static_ips' => %w(10.0.0.1 10.0.0.2)
              }
            ]
          }
        ]
      }.to_yaml
    end

    context 'when the job exists' do
      it 'returns job information' do
        job = bosh_manifest.job('job-name')
        expect(job.static_ips).to eq(%w(10.0.0.1 10.0.0.2))
        expect(job.instances).to eq(2)
      end
    end

    context 'when the job does not exist' do
      it 'raises an error' do
        expect {
          bosh_manifest.job('jerb-name')
        }.to raise_error(/Could not find job name 'jerb-name' in job list: \[/)
      end
    end

    context 'with a BOSH v2 style manifest' do
      let(:manifest) do
        {
          'instance_groups' => [
            {
              'name' => 'job-name',
              'instances' => 2,
              'networks' => [
                'name' => 'network-name',
                'static_ips' => %w(10.0.0.1 10.0.0.2)
              ]
            }
          ]
        }.to_yaml
      end

      it 'returns an array of jobs' do
        job = bosh_manifest.job('job-name')
        expect(job.static_ips).to eq(%w(10.0.0.1 10.0.0.2))
        expect(job.instances).to eq(2)
      end
    end

  end

  describe '#property' do
    context 'when the property is present' do
      let(:manifest) { { 'properties' => { 'a_property' => 'A_VALUE' } }.to_yaml }

      it 'raises an error' do
        expect(bosh_manifest.property('a_property')).to eq('A_VALUE')
      end
    end

    context 'when the property is not present' do
      let(:manifest) { { 'properties' => {} }.to_yaml }

      it 'raises an error' do
        expect {
          bosh_manifest.property('a_property')
        }.to raise_error(/Could not find property 'a_property' in {}/)
      end
    end

    context 'when the property is multi-part' do
      let(:manifest) do
        {
          'properties' => {
            'parent_property' => {
              'child_property' => 'value'
            }
          }
        }.to_yaml
      end

      context 'when the parent property is present' do
        it 'fetches the key' do
          expect(bosh_manifest.property('parent_property.child_property')).to eq('value')
        end

        it 'is idempotent' do
          expect(bosh_manifest.property('parent_property.child_property')).to eq('value')
          expect(bosh_manifest.property('parent_property.child_property')).to eq('value')
        end
      end

      context 'when the parent property is not present' do
        it 'raises an error' do
          expect {
            bosh_manifest.property('some_nonexistent_parent_property.child_property')
          }.to raise_error(/Could not find property 'some_nonexistent_parent_property\.child_property' in/)
        end
      end
    end
  end

  describe '#set_property' do
    let(:path) { Tempfile.new('bosh_manifest').path }
    let(:manifest) do
      { 'properties' => { 'some_property' => 1 } }.to_yaml
    end

    before do
      File.write(path, manifest)
    end

    context 'when no path is provided' do
      it 'fails with a sensible exception' do
        expect {
          bosh_manifest.set_property('some_property', 3)
        }.to raise_error(Hula::BoshManifest::NoManifestPathGiven)
      end
    end

    it 'changes the value of the given property in the manifest on disk' do
      bosh_manifest = Hula::BoshManifest.from_file(path)
      expect {
        bosh_manifest.set_property('some_property', 2)
      }.to change { bosh_manifest.property('some_property') }.from(1).to(2)

      reloaded_bosh_manifest = Hula::BoshManifest.from_file(path)
      expect(reloaded_bosh_manifest.property('some_property')).to eq(2)
    end

    context 'when the property is multi-part' do
      let(:properties) {
        {
          'parent_property' => {
            'child_property' => 'value',
          }
        }
      }

      let(:manifest) {
        {
          'properties' => properties
        }.to_yaml
      }

      it 'changes the value of the given property in the manifest on disk' do
        bosh_manifest = Hula::BoshManifest.from_file(path)
        expect {
          bosh_manifest.set_property('parent_property.child_property', 'new_value')
        }.to change { bosh_manifest.property('parent_property.child_property') }.from('value').to('new_value')

        reloaded_bosh_manifest = Hula::BoshManifest.from_file(path)
        expect(reloaded_bosh_manifest.property('parent_property.child_property')).to eq('new_value')
      end

      it 'allows values to be hashes' do
        bosh_manifest = Hula::BoshManifest.from_file(path)
        expect {
          bosh_manifest.set_property('parent_property', 'child_property' => 'new_value')
        }.to change { bosh_manifest.property('parent_property.child_property') }.from('value').to('new_value')

        reloaded_bosh_manifest = Hula::BoshManifest.from_file(path)
        expect(reloaded_bosh_manifest.property('parent_property.child_property')).to eq('new_value')
      end

      context 'when a parent key does not exist' do
        it 'fails with a sensible exception' do
          bosh_manifest = Hula::BoshManifest.from_file(path)
          expect {
            bosh_manifest.set_property('made_up_parent.made_up_child', 'value')
          }.to raise_error("Could not find property 'made_up_parent' in #{properties.inspect}")
        end
      end
    end
  end
end
