# Copyright (c) 2014-2015 Pivotal Software, Inc.
# All rights reserved.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#

require 'yaml'
require 'hula/bosh_manifest/job'

module Hula
  class BoshManifest
    class NoManifestPathGiven < StandardError; end

    attr_reader :path

    def initialize(manifest_yaml, path: nil)
      @manifest_hash = YAML.load(manifest_yaml)
      @path = path
      fail 'Invalid manifest' unless manifest_hash.is_a?(Hash)
    end

    def self.from_file(path)
      new(File.read(path), path: path)
    rescue Errno::ENOENT
      raise "Could not open the manifest file: '#{path}'"
    end

    def property(property_name)
      components = property_components(property_name)
      traverse_properties(components)
    rescue KeyError
      raise "Could not find property '#{property_name}' in #{properties.inspect}"
    end

    def set_property(property_name, value)
      components = property_components(property_name)
      traverse_properties_and_set(properties, components, value)
      save
    end

    def deployment_name
      manifest_hash.fetch('name')
    rescue KeyError
      raise "Could not find deployment name in #{manifest_hash.inspect}"
    end

    def jobs_by_regexp(job_name_regexp)
      if manifest_hash.has_key?('instance_groups')
        key = "instance_groups"
      else
        key = "jobs"
      end

      jobs_property = manifest_hash.fetch(key)
      jobs = jobs_property.select { |job| !job.fetch('name').match(job_name_regexp).nil? }

      fail "Could not find job name '#{job_name_regexp}' in job list: #{jobs_property.inspect}" if jobs.empty?

      jobs.map { |job| Job.new(job) }
    end

    def job(job_name)
      if manifest_hash.has_key?('instance_groups')
        key = "instance_groups"
      else
        key = "jobs"
      end

      jobs = manifest_hash.fetch(key)
      job = jobs.detect { |j| j.fetch('name') == job_name }

      fail "Could not find job name '#{job_name}' in job list: #{jobs.inspect}" if job.nil?

      Job.new(job)
    end

    def resource_pools
      manifest_hash.fetch('resource_pools')
    end

    def properties
      manifest_hash.fetch('properties')
    end

    private

    attr_reader :manifest_hash

    def save
      unless path
        fail NoManifestPathGiven, 'Cannot save manifest without providing a path'
      end
      File.write(path, manifest_hash.to_yaml)
    end

    def property_components(property_name)
      property_name.split('.')
    end

    def traverse_properties(components)
      components.inject(properties) do |current_node, component|
        current_node.fetch(component)
      end
    end

    def traverse_properties_and_set(properties, components, value)
      component = components.shift

      if components.any?
        unless properties.key?(component)
          fail "Could not find property '#{component}' in #{properties.inspect}"
        end
        traverse_properties_and_set(properties[component], components, value)
      else
        properties[component] = value
      end
    end
  end
end
