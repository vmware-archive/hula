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

module Hula
  class HttpProxyUpstreamSocks
    include Helpers::SocketTools

    def initialize(
      polipo_bin: 'polipo',
      socks_proxy:,
      http_host: 'localhost',
      http_port: free_port
    )
      @socks_proxy_host = socks_proxy.socks_host
      @socks_proxy_port = socks_proxy.socks_port
      @http_host = http_host
      @http_port = http_port
      @polipo_bin = polipo_bin

      check_polipo_bin!
    end

    attr_reader :http_host, :http_port

    def start
      @process ||= start_polipo_process
    end

    def stop
      return unless @process

      Process.kill('TERM', @process) rescue Errno::ESRCH
      Process.wait(@process)         rescue Errno::ECHILD
      @process = nil
    end

    private

    attr_reader :socks_proxy_host, :socks_proxy_port, :polipo_bin


    def start_polipo_process
      pid = Process.spawn(polipo_command)
      at_exit { stop }
      wait_for_port(host: http_host, port: http_port)
      Process.detach(pid)
      pid
    end

    def polipo_command
      "#{polipo_bin} diskCacheRoot='' \
        proxyPort=#{http_port} \
        socksParentProxy=#{socks_proxy_host}:#{socks_proxy_port} \
        socksProxyType=socks4a"
    end

    def check_polipo_bin!
      unless system("which #{polipo_bin} > /dev/null 2>&1")
        raise "Could not run polipo (#{polipo_bin}). Please install, or put in PATH"
      end
    end
  end
end
