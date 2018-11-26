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
require 'hula/service_broker/http_json_client'

require 'json'

RSpec.describe Hula::ServiceBroker::HttpJsonClient do

  subject(:instance) { Hula::ServiceBroker::HttpJsonClient.new }


  let(:url) { "https://www.example.com:443/foos" }
  let(:status) { 200 }
  let(:data) { { key: 'value' } }
  let(:body) { JSON.generate(data) }

  before do
    stub_request(method, url).to_return(body: body, status: status).
      with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'www.example.com', 'User-Agent'=>'Ruby', 'hkey' => 'hvalue'})
  end

  describe '#get' do
    let(:data) { { key: 'value' } }
    let(:body) { JSON.generate(data) }
    let(:method) { :get }
    let(:headers) { { hkey: 'hvalue' } }

    context 'with headers' do
      let(:username) { 'something' }
      let(:password) { 'secret' }
      let(:url) { "https://#{username}:#{password}@www.example.com:443/foos" }

      subject(:request) do
        instance.get(
          URI('https://www.example.com:443/foos'),
          auth: {
            username: username,
            password: password
          },
          headers: { hkey: 'hvalue' }
        )
      end

      it 'returns the correct data' do
        expect(request).to eq(data)
      end
    end

    context 'with auth' do
      let(:username) { 'something' }
      let(:password) { 'secret' }
      let(:url) { "https://#{username}:#{password}@www.example.com:443/foos" }

      subject(:request) do
        instance.get(
          URI('https://www.example.com:443/foos'),
          auth: {
            username: username,
            password: password
          },
          headers: { hkey: 'hvalue' }
        )
      end

      it 'returns the correct data' do
        expect(request).to eq(data)
      end
    end

    context 'without auth' do
      subject(:request) do
        instance.get(URI('https://www.example.com:443/foos'), headers: { hkey: 'hvalue' })
      end

      it 'returns correct data' do
        expect(request).to eq(data)
      end
    end

    context 'when data is not JSON' do
      before do
        stub_request(method, url).to_return(body: body, status: status)
      end

      let(:body) { 'something else' }

      subject(:request) do
        instance.get(URI(url))
      end

      it 'raises an error' do
        expect { request }.to raise_error(Hula::ServiceBroker::JsonParseError)
      end
    end

    context 'with timeout' do
      before do
        stub_request(method, url).to_timeout
      end

      subject(:request) do
        instance.get(URI(url), headers: { hkey: 'hvalue' })
      end

      it 'raises a timeout error' do
        expect { request }.to raise_error(Hula::ServiceBroker::TimeoutError)
      end
    end

    context 'with non 2XX repsonse' do
      before do
        stub_request(method, url).to_return(body: body, status: status)
      end

      let(:status) { 500 }
      let(:body) { 'Internal Server Error' }

      subject(:request) do
        instance.get(URI(url))
      end

      it 'raises a HTTPError' do
        expect { request }.to raise_error(
          Hula::ServiceBroker::HTTPError,
          /Internal Server Error/
        )
      end
    end
  end

  describe '#put' do
    let(:method) { :put }
    let(:data) { { key: 'value' } }
    let(:body) { JSON.generate(data) }

    context 'without auth' do
      it 'sends the correct request' do
        instance.put(URI(url), body: { a_param: 'a_value' }, headers: {'hkey' => 'hvalue'})

        assert_requested :put, 'https://www.example.com:443/foos' do |request|
          JSON.parse(request.body) == { 'a_param' => 'a_value' }
        end
      end

      it 'returns the correct data' do
        result = instance.put(URI(url), body: { a_param: 'a_value' }, headers: {'hkey' => 'hvalue'})
        expect(result).to eq(data)
      end
    end

    context 'with auth' do
      let(:username) { 'something' }
      let(:password) { 'secret' }
      let(:url) { "https://#{username}:#{password}@www.example.com:443/foos" }

      it 'sends the correct request' do
        instance.put(
            URI('https://www.example.com:443/foos'),
            body: { a_param: 'a_value' },
            auth: { username: 'something', password: 'secret' },
            headers: {'hkey' => 'hvalue'}
        )

        assert_requested :put, 'https://something:secret@www.example.com:443/foos' do |request|
          JSON.parse(request.body) == { 'a_param' => 'a_value' }
        end
      end

      it 'returns the correct data' do
        result = instance.put(
            URI('https://www.example.com:443/foos'),
            body: { a_param: 'a_value' },
            auth: { username: 'something', password: 'secret' },
            headers: {'hkey' => 'hvalue'}
        )

        expect(result).to eq(data)
      end
    end

    context 'with non 2XX repsonse' do
      before do
        stub_request(method, url).to_return(body: body, status: status)
      end

      let(:status) { 500 }
      let(:body) { 'Internal Server Error' }

      subject(:request) do
        instance.put(URI(url), body: {})
      end

      it 'raises a HTTPError' do
        expect { request }.to raise_error(
          Hula::ServiceBroker::HTTPError,
          /Internal Server Error/
        )
      end
    end
  end

  describe '#delete' do
    let(:method) { :delete }

    context 'without auth' do
      it 'returns the correct data' do
        result = instance.delete(URI(url), headers: {'hkey' => 'hvalue'})
        expect(result).to eq(data)
      end
    end

    context 'with auth' do
      let(:username) { 'something' }
      let(:password) { 'secret' }
      let(:url) { "https://#{username}:#{password}@www.example.com:443/foos" }

      it 'returns the correct data' do
        result = instance.delete(
          URI('https://www.example.com:443/foos'),
          auth: {
            username: username,
            password: password
          },
          headers: {'hkey' => 'hvalue'}
        )

        expect(result).to eq(data)
      end
    end

    context 'with non 2XX repsonse' do
      before do
        stub_request(method, url).to_return(body: body, status: status)
      end

      let(:status) { 500 }
      let(:body) { 'Internal Server Error' }

      subject(:request) do
        instance.delete(URI(url))
      end

      it 'raises a HTTPError' do
        expect { request }.to raise_error(
          Hula::ServiceBroker::HTTPError,
          /Internal Server Error/
        )
      end
    end
  end
end
