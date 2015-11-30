# Copyright (c) 2014-2015 Pivotal Software, Inc.
# All rights reserved.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#

require 'hula/command_runner'

module Hula
  describe CommandRunner do
    let(:command_runner) { described_class.new }

    describe '#run' do
      context 'when the command runs successfully' do
        it 'returns the output of a successful command' do
          command_output = command_runner.run('echo hello')
          expect(command_output).to eq("hello\n")
        end
      end

      context 'when the command exits with non-zero status' do
        it 'raises' do
          expect {
            command_runner.run('exit 1')
          }.to raise_error(CommandFailedError)
        end
      end

      context 'when the command execution fails' do
        it 'raises' do
          expect {
            command_runner.run('sadfsdfsadfdsfsad')
          }.to raise_error(CommandFailedError)
        end
      end
    end
  end
end
