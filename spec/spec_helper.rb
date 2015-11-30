# Copyright (c) 2014-2015 Pivotal Software, Inc.
# All rights reserved.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#

require 'support/assets'

require 'rspec_junit_formatter'
require 'webmock/rspec'

RSpec.configure do |config|
  config.include Support::Assets

  config.filter_run_including focus: true
  config.run_all_when_everything_filtered = true

  config.full_backtrace = true

  config.add_formatter :documentation
  config.add_formatter RSpecJUnitFormatter, 'rspec.xml'

  WebMock.disable_net_connect!(:allow_localhost => true)
end
