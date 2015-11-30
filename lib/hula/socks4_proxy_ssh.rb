# Copyright (c) 2014-2015 Pivotal Software, Inc.
# All rights reserved.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#

require 'hula/helpers/socket_tools'
require 'pty'
require 'expect'

module Hula
  class Socks4ProxySsh
    class FailedToStart < StandardError; end
    class DieSignal < StandardError; end

    include Helpers::SocketTools

    def initialize(
      ssh_host:,
      ssh_username:,
      ssh_password:,
      socks_host: 'localhost',
      socks_port: free_port,
      ssh_bin: 'ssh',
      retry_count: 10
    )
      @ssh_bin      = String(ssh_bin)
      @ssh_host     = String(ssh_host)
      @ssh_username = String(ssh_username)
      @ssh_password = String(ssh_password)
      @socks_port   = String(socks_port)
      @socks_host   = String(socks_host)
      @retry_count = retry_count
    end

    attr_reader :socks_port, :socks_host

    def stop
      return unless @thread
      @thread.raise(DieSignal)
      @thread.join
      @thread = nil
    end

    def start
      @thread ||= begin
        thread = start_ssh_socks_thread
        wait_for_port(:host => socks_host, :port => socks_port, timeout_seconds: 30)
        thread
      end
    end

    private

    attr_reader :ssh_host, :ssh_username, :ssh_password, :ssh_bin

    def start_ssh_socks_thread
      # We need to shell out to ssh as this has a SOCKS proxy facility
      # However, there's a problem. SSH does not provide an argument for passing in a password
      # We don't have keys available so we need to use expect to feed the password into the prompt
      Thread.new(
        ssh_command,
        ssh_password
      ) do |ssh_command, ssh_password|
        tries_remaining = @retry_count

        while true
          puts "--- SSH Gateway attempt #{@retry_count + 1 - tries_remaining}"
          sleep 1

          begin
            ssh_out, ssh_in, pid = PTY.spawn(*ssh_command)
            # On BOSH lite a password is used, however on aws an identity is used
            # The below statment will wait on a aws run and the pid is never returned
            ssh_out.expect(/[Pp]assword\:/) { |r| ssh_in.print("#{ssh_password}\n") }
            Process.wait(pid)

            tries_remaining -= 1
            if tries_remaining < 0
              raise FailedToStart, "SSH finished early - SSH Socks Proxy could not be setup or failed"
            end
          rescue Errno::EIO
            tries_remaining -= 1
            # Can't read or write to dead process

            if tries_remaining < 0
              raise FailedToStart, "SSH finished early EIO - SSH Socks Proxy could not be setup or failed"
            end
          rescue DieSignal
            Process.kill('KILL', pid) rescue Errno::ESRCH
            Process.wait(pid)         rescue Errno::ECHILD
            break
          end
        end
      end.tap do |thread|
        thread.abort_on_exception = true
      end
    end

    def ssh_command
      [
        ssh_bin,
        '-D', "#{socks_host}:#{socks_port}",
        '-N',
        "#{ssh_username}@#{ssh_host}",
        '-o', 'UserKnownHostsFile=/dev/null',
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'NumberOfPasswordPrompts=1',
        '-o', 'StrictHostKeyChecking=no'
      ]
    end

  end
end
