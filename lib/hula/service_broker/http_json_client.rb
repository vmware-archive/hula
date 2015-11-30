# Copyright (c) 2014-2015 Pivotal Software, Inc.
# All rights reserved.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#

require 'net/http'

require 'hula/service_broker/errors'

module Hula
  module ServiceBroker

    class HttpProxyNull
      def http_host
        nil
      end
      def http_port
        nil
      end
    end

    class HttpJsonClient
      def initialize(http_proxy: HttpProxyNull.new)
        @http_proxy = http_proxy
      end

      def get(uri, auth: nil)
        request = Net::HTTP::Get.new(uri)
        request.basic_auth auth.fetch(:username), auth.fetch(:password) unless auth.nil?
        send_request(request)
      end

      def put(uri, body: nil, auth: nil)
        request = Net::HTTP::Put.new(uri)
        request.body = JSON.generate(body) if body
        request.basic_auth auth.fetch(:username), auth.fetch(:password) unless auth.nil?
        send_request(request)
      end

      def delete(uri, auth: nil)
        request = Net::HTTP::Delete.new(uri)
        request.basic_auth auth.fetch(:username), auth.fetch(:password) unless auth.nil?
        send_request(request)
      end

      private

      attr_reader :http_proxy

      def send_request(request)
        uri = request.uri
        make_request(uri.hostname, uri.port, uri.scheme, request)
      end

      def make_request(host, port, scheme, request)
        response = Net::HTTP.start(
          host,
          port,
          http_proxy.http_host,
          http_proxy.http_port,
          use_ssl: scheme == 'https',
          verify_mode: OpenSSL::SSL::VERIFY_NONE
        ) { |http| http.request(request) }

        handle(response)
      rescue Timeout::Error => e
        raise TimeoutError, e
      end

      def handle(response)
        unless response.is_a?(Net::HTTPSuccess)
          fail HTTPError, [
            response.uri.to_s,
            response.code,
            response.body
          ].join("\n\n")
        end

        JSON.parse(response.body, symbolize_names: true)
      rescue JSON::ParserError => e
        raise JsonParseError, e
      end
    end
  end
end
