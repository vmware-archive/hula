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
require 'hula/cloud_foundry/service_broker'

require 'ostruct'

describe Hula::CloudFoundry::ServiceBroker do
  describe "equality" do
    it "requires an object of the same class" do
      one = Hula::CloudFoundry::ServiceBroker.new(name: 'name', url: 'url')
      two = OpenStruct.new(name: 'name', url: 'url')

      expect(one).to_not eq(two)
    end

    it "requires name to be equal" do
      one = Hula::CloudFoundry::ServiceBroker.new(name: 'name_a', url: 'url')
      two = Hula::CloudFoundry::ServiceBroker.new(name: 'name_a', url: 'url')
      three = Hula::CloudFoundry::ServiceBroker.new(name: 'name_b', url: 'url')

      expect(one).to eq(two)
      expect(one).to_not eq(three)
    end

    it "requires url to be equal" do
      one = Hula::CloudFoundry::ServiceBroker.new(name: 'name', url: 'url_a')
      two = Hula::CloudFoundry::ServiceBroker.new(name: 'name', url: 'url_a')
      three = Hula::CloudFoundry::ServiceBroker.new(name: 'name', url: 'url_b')

      expect(one).to eq(two)
      expect(one).to_not eq(three)
    end
  end

  describe '#name' do
    subject { Hula::CloudFoundry::ServiceBroker.new(name: 'NAME', url: 'urla').name }
    it { is_expected.to eq('NAME') }
  end

  describe '#uri' do
    it 'returns an object with host and port' do
      uri = Hula::CloudFoundry::ServiceBroker.new(
        name: 'name',
        url: 'http://example.com:12345'
      ).uri

      expect(uri.host).to eq('example.com')
      expect(uri.port).to eq(12345)
    end
  end
end
