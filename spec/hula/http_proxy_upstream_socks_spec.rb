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

require 'hula/http_proxy_upstream_socks'
require 'hula/helpers/socket_tools'

require 'open-uri'
require 'rack'
require 'proxymachine'
require 'sys/proctable'

RSpec.describe Hula::HttpProxyUpstreamSocks do
  include Hula::Helpers::SocketTools

  def polipo_child_processes
    Sys::ProcTable.ps.select{ |pe|
      pe.ppid == Process.pid
    }.map(&:cmdline).count { |name|
      name =~ /polipo/
    }
  end

  let(:socks_proxy_port) { '54322' }

  let(:socks_proxy) {
    proxy = Struct.new(:socks_host, :socks_port)
    proxy.new('localhost', socks_proxy_port)
  }

  def proxy(args = {})
    defaults = { socks_proxy: socks_proxy }
    @proxy ||= described_class.new(defaults.merge(args))
  end

  context 'with a running http server and SOCKS4 proxy' do
    let(:http_port) { '54321' }
    let(:http_server_thread) do
      Thread.new do
        app = ->(env) { [200, {'Content-Type' => 'text/html'}, ['test_response_body']] }
        Rack::Handler::WEBrick.run(app, { :Host => 'localhost', :Port => http_port })
      end
    end

    let(:socks_server_process) do
      Process.fork do
        ProxyMachine.set_router(->(data) {
          return  if data.size < 9
          v, c, port, _, _, _, _, user = data.unpack("CCnC4a*")
          return { :close => "\0\x5b\0\0\0\0\0\0" }  if v != 4 or c != 1
          return  if ! idx = user.index("\0")
          { :remote => "localhost:#{port}",
            :reply => "\0\x5a\0\0\0\0\0\0",
            :data => data[idx+9..-1] }
        })
        ProxyMachine.run('socks_proxy', 'localhost', socks_proxy_port)
      end
    end

    before do
      http_server_thread
      wait_for_port(host: 'localhost', port: http_port)

      socks_server_process
      wait_for_port(host: 'localhost', port: socks_proxy.socks_port)

      proxy.start
    end

    after do
      proxy.stop
      http_server_thread.kill
      Process.kill('KILL', socks_server_process)
      Process.wait(socks_server_process)
    end

    let(:http_server_uri) { URI::HTTP.build(:host => 'localhost', :port => http_port.to_i) }
    let(:http_proxy_uri) { URI::HTTP.build(:host => 'localhost', :port => proxy.http_port.to_i) }

    it 'allows connections via a http proxy, upstreamed through a SOCKS proxy, to a http server' do
      expect(
        http_server_uri.read(:proxy => http_proxy_uri)
      ).to eq('test_response_body')
    end

    it 'launches polipo as a single child process' do
      expect(polipo_child_processes).to eq(1)
    end
  end

  after do proxy.stop end

  it 'kills polipo correctly' do
    proxy.start
    expect(polipo_child_processes).to eq(1)

    proxy.stop
    expect(polipo_child_processes).to eq(0)
  end

  it 'raises helpful error when polipo is not installed' do
    expect {
      proxy(:polipo_bin => '/does/not/exist')
    }.to raise_error(%r{/does/not/exist})
  end

end
