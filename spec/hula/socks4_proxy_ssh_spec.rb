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

require 'hula/socks4_proxy_ssh'
require 'hula/helpers/socket_tools'

require 'sys/proctable'

RSpec.describe Hula::Socks4ProxySsh do

  include Hula::Helpers::SocketTools

  let(:password) { 'SECRET' }

  subject(:proxy) {
    described_class.new(
      ssh_bin:      asset_path('fake_ssh'),
      ssh_host:     'HOST',
      ssh_username: 'USERNAME',
      ssh_password: password,
      retry_count: 1
    )
  }

  after do
    proxy.stop
  end

  describe '#start' do
    context 'with correct password' do
      it 'starts ssh' do
        proxy.start

        expect(port_open?(host: proxy.socks_host, port: proxy.socks_port)).to be(true)
      end
    end

    context 'with incorrect password' do
      let(:password) { 'WR0NG' }

      it 'fails to start ssh' do
        expect { proxy.start }.to raise_error(Hula::Socks4ProxySsh::FailedToStart)
      end
    end
  end

  describe '#stop' do
    it 'kill ssh correctly' do
      proxy.start
      expect(port_open?(host: proxy.socks_host, port: proxy.socks_port)).to be(true)

      proxy.stop
      expect(port_open?(host: proxy.socks_host, port: proxy.socks_port)).to be(false)
    end
  end
end
