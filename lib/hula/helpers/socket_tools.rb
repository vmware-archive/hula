# Copyright (c) 2014-2015 Pivotal Software, Inc.
# All rights reserved.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#

require 'hula/helpers/timeout_tools'

require 'socket'

module Hula
  module Helpers
    module SocketTools
      module_function def wait_for_port(host:, port:, timeout_seconds: 20)
        error = "Failed to connect to #{host}:#{port} within #{timeout_seconds} seconds"
        TimeoutTools.wait_for(error: error, timeout_seconds: timeout_seconds) do
          port_open?(host: host, port: port)
        end
      end

      module_function def port_open?(host:, port:)
        socket = TCPSocket.new(host, port)
        socket.close unless socket.nil?
        true
      rescue Errno::ECONNREFUSED
        false
      end

      module_function def free_port
        socket = Socket.new(:INET, :STREAM, 0)
        socket.bind(Addrinfo.tcp('127.0.0.1', 0))
        socket.local_address.ip_port
      ensure
        socket.close
      end
    end
  end
end


