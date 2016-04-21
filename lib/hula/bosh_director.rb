# Copyright (c) 2014-2015 Pivotal Software, Inc.
# All rights reserved.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#

require 'tempfile'
require 'yaml'
require 'socket'
require 'uri'

require 'hula/command_runner'

module Hula
  class BoshDirector
    class NoManifestSpecified < StandardError; end
    class DirectorPortNotOpen < StandardError; end
    class DirectorIsBroken < StandardError; end

    def initialize(
      target_url:,
      username:,
      password:,
      manifest_path: nil,
      command_runner: CommandRunner.new,
      logger: default_logger
    )
      @target_url            = target_url
      @username              = username
      @password              = password
      @default_manifest_path = manifest_path
      @command_runner        = command_runner
      @logger                = logger

      target_and_login
    end

    # Should rely on `bosh status` and CPI, but currently Bosh Lite is
    # reporting 'vsphere' instead of 'warden'.
    def lite?
      target_url.include? '192.168.50.4'
    end

    def deploy(manifest_path = default_manifest_path)
      run_bosh("--deployment #{manifest_path} deploy")
    end

    def delete_deployment(deployment_name, force: false)
      cmd = ["delete deployment #{deployment_name}"]
      cmd << '-f' if force
      run_bosh(cmd.join(' '))
    end

    def run_errand(name, manifest_path: default_manifest_path, keep_alive: false)
        command = "--deployment #{manifest_path} run errand #{name}"

      if keep_alive
        command << " --keep-alive"
      end

      run_bosh(command)
    end

    def recreate_all(jobs)
      jobs.each do |name|
        recreate(name)
      end
    end

    def recreate_instance(name, index)
      validate_job_instance_index(name, index)

      run_bosh("recreate #{name} #{index}")
    end

    def recreate(name)
      properties = job_properties(name)

      instances = properties.fetch('instances')

      instances.times do |instance_index|
        run_bosh("recreate #{name} #{instance_index}")
      end
    end

    def stop(name, index)
      validate_job_instance_index(name, index)

      run_bosh("stop #{name} #{index} --force")
    end

    def start(name, index)
      validate_job_instance_index(name, index)

      run_bosh("start #{name} #{index} --force")
    end

    def job_logfiles(job_name)
      tmpdir = Dir.tmpdir
      run_bosh("logs #{job_name} 0 --job --dir #{tmpdir}")
      tarball = Dir[File.join(tmpdir, job_name.to_s + '*.tgz')].last
      output = command_runner.run("tar tf #{tarball}")
      lines = output.split(/\n+/)
      filepaths = lines.map { |f| Pathname.new(f) }
      logpaths = filepaths.select { |f| f.extname == '.log' }
      logpaths.map(&:basename).map(&:to_s)
    end

    def has_logfiles?(job_name, logfile_names)
      logs = job_logfiles(job_name)
      logfile_names.each do |logfile_name|
        return false unless logs.include?(logfile_name)
      end
      true
    end

    def deployment_names
      deployments = run_bosh('deployments')
      # [\n\r]+ a new line,
      # \s* maybe followed by whitespace,
      # \| followed by a pipe,
      # \s+ followed by whitespace,
      # ([^\s]+) followed some characters (ie, not whitespace, or a pipe) — this is the match
      first_column = deployments.scan(/[\n\r]+\s*\|\s+([^\s\|]+)/).flatten

      first_column.drop(1) # without header
    end

    # Parses output of `bosh vms` like below, getting an array of IPs for a job name
    # +------------------------------------+---------+---------------+--------------+
    # | Job/index                          | State   | Resource Pool | IPs          |
    # +------------------------------------+---------+---------------+--------------+
    # | api_z1/0                           | running | large_z1      | 10.244.0.138 |
    # ...
    #
    # Also matches output from 1.3184 bosh_cli e.g.
    #
    # +------------------------------------------------+---------+----------------+--------------+
    # | VM                                             | State   | AZ  | VM Type  | IPs          |
    # +------------------------------------------------+---------+----------------+--------------+
    # | api_z1/0 (fe04916e-afd0-42a3-aaf5-52a8b163f1ab)| running | n/a | large_z1 | 10.244.0.138 |
    # ...
    #
    def ips_for_job(job, deployment_name = nil)
      output = run_bosh("vms #{deployment_name}")
      deployments = output.split(/^Deployment/)

      job_ip_map = {}

      deployments.each do |deployment|
        rows = deployment.split("\n")
        row_cols = rows.map { |row| row.split('|') }
        job_cols = row_cols.  select { |cols| cols.length == 5 || cols.length == 6 } # match job boxes
        job_ip_pairs = job_cols.map { |cols| [cols[1].strip.split(' ')[0], cols.last.strip] }
        jobs_with_real_ips = job_ip_pairs.select { |pairs| pairs.last =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/ }
        # converts eg   cf-redis-broker/2  to cf-redis-broker
        jobs_without_instance_numbers = jobs_with_real_ips.map { |pair| [pair.first.gsub(/\/.*/, ''), pair.last] }
        jobs_without_instance_numbers.each do |job|
          name, ip = job
          job_ip_map[name] ||= []
          job_ip_map[name] << ip
        end
      end

      job_ip_map.fetch(job, [])
    end

    def download_manifest(deployment_name)
      output = run_bosh("download manifest #{deployment_name}")
      YAML.load(output)
    end

    private

    attr_reader :target_url, :username, :password, :command_runner, :logger

    def job_properties(job_name)
      manifest.fetch('jobs').find { |job| job.fetch('name') == job_name }.tap do |properties|
        fail ArgumentError.new('Job not found in manifest') unless properties
      end
    end

    def validate_job_instance_index(job_name, index)
      properties = job_properties(job_name)
      instances = properties.fetch('instances')
      fail ArgumentError.new('Index out of range') unless (0...instances).include? index
    end

    def default_logger
      @default_logger ||= begin
        STDOUT.sync = true
        require 'logger'
        Logger.new(STDOUT)
      end
    end

    def default_manifest_path?
      !!@default_manifest_path
    end

    def default_manifest_path
      fail NoManifestSpecified unless default_manifest_path?
      @default_manifest_path
    end

    def manifest
      YAML.load_file(default_manifest_path)
    end

    def target_and_login
      run_bosh("target #{target_url}")
      run_bosh("deployment #{default_manifest_path}") if default_manifest_path?
      run_bosh("login #{username} #{password}")
    end

    def run_bosh(cmd)
      command = "bosh -v -n --config '#{bosh_config_path}' #{cmd}"
      logger.info(command)

      command_runner.run(command)
    rescue CommandFailedError => e
      logger.error(e.message)
      health_check!
      raise e
    end

    def bosh_config_path
      # We should keep a reference to the tempfile, otherwise,
      # when the object gets GC'd, the tempfile is deleted.
      @bosh_config_tempfile ||= Tempfile.new('bosh_config')
      @bosh_config_tempfile.path
    end

    def health_check!
      check_port!
      check_deployments!
    end

    def target_uri
      @target_uri ||= URI.parse(target_url)
    end

    def check_deployments!
      http = Net::HTTP.new(target_uri.host, target_uri.port)
      http.use_ssl = target_uri.scheme == 'https'
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Get.new('/deployments')
      request.basic_auth username, password
      response = http.request request

      unless response.is_a? Net::HTTPSuccess
        fail DirectorIsBroken, "Failed to GET /deployments from #{target_uri}. Returned:\n\n#{response.to_hash}\n\n#{response.body}"
      end
    end

    def check_port!
      socket = TCPSocket.new(target_uri.host, target_uri.port)
      socket.close
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      raise DirectorPortNotOpen, "Cannot connect to #{target_uri.host}:#{target_uri.port}"
    end
  end
end
