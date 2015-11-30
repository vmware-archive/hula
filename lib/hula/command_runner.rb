# Copyright (c) 2014-2015 Pivotal Software, Inc.
# All rights reserved.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#

require 'open3'

module Hula
  class CommandFailedError < StandardError; end

  class CommandRunner
    def initialize(environment: ENV)
      @environment = environment
    end

    def run(command, allow_failure: false)
      stdout_and_stderr, status = Open3.capture2e(environment, command)

      if !allow_failure && !status.success?
        message = "Command failed! - #{command}\n\n#{stdout_and_stderr}\n\nexit status: #{status.exitstatus}"
        fail CommandFailedError, message
      end

      stdout_and_stderr
    rescue => e
      raise CommandFailedError, e
    end

    private

    attr_reader :environment
  end
end
