require 'spec_helper'
require 'json'

RSpec.describe Lorekeeper do
  describe Lorekeeper::JSONLogger do
    let(:io) { FakeJSONIO.new }
    let(:current_time) { Time.utc(1897, 1, 1) }
    let(:time_string) { '1897-01-01T00:00:00.000000Z'}
    let(:message) { 'Blazing Hyperion on his orbed fire still sat' }
    let(:data) { { 'some' => 'data' } }
    let(:base_message) { { 'timestamp' => time_string, 'message' => message } }
    let(:data_field) { { 'data' => data } }

    before(:each) do
      Timecop.freeze(current_time)
    end

    shared_examples_for 'Logging methods' do
      Lorekeeper::JSONLogger::LOGGING_METHODS.each do |method|
        it "Outputs the correct format for #{method}" do
          logger.send(method, message)
          expect(io.received_message).to eq(expected)
        end
        it 'The first key is timestamp' do
          logger.send(method, message)
          expect(io.received_message.keys[0]).to eq('timestamp')
        end
        it 'The second key is message' do
          logger.send(method, message)
          expect(io.received_message.keys[1]).to eq('message')
        end
        it "Outputs the correct format for #{method}_with_data" do
          logger.send("#{method}_with_data", message, data)
          expect(io.received_message).to eq(expected_data)
        end
      end
    end

    context 'Logger with proper IO' do
      let(:logger) { described_class.new(io) }
      let(:expected) { base_message }
      let(:expected_data) { base_message.merge(data_field) }

      it_behaves_like 'Logging methods'

      describe '#exception' do
        let(:exception_msg) { 'This is an exception' }
        let(:exception) { StandardError.new(exception_msg) }
        let(:expected) { base_message.merge(exception_data) }
        let(:backtrace) { ['First line', 'Second line'] }
        let(:stack) { ['First line', 'Second line'] }
        let(:exception_data) do
          base_message.merge(
            'exception' => "StandardError: #{exception_msg}",
            'message' => exception_msg, 'stack' => stack
          )
        end

        before do
          exception.set_backtrace(backtrace)
        end

        context 'Logging just an exception' do
          it 'Logs the exception' do
            logger.exception(exception)
            expect(io.received_message).to eq(exception_data)
          end

          it 'Uses error level to log the exception' do
            expect(logger).to receive(:log_data).with(:error, anything)
            logger.exception(exception)
          end

          it 'Clears the exception fields after logging the exception' do
            logger.exception(exception)
            logger.info(message)
            expect(io.received_message).to eq(base_message)
          end
        end

        context 'Logging an exception with custom message' do
          let(:exception_data) do
            base_message.merge(
              'exception' => "StandardError: #{exception_msg}",
              'message' => message, 'stack' => stack
            )
          end
          it 'Logs the exception' do
            logger.exception(exception, message)
            expect(io.received_message).to eq(exception_data)
          end
        end

        context 'Logging an exception with custom message and data' do
          let(:exception_data) do
            base_message.merge(
              { 'exception' => "StandardError: #{exception_msg}",
                'message' => message, 'stack' => stack }.merge(data_field)
            )
          end
          it 'Logs the exception' do
            logger.exception(exception, message, data)
            expect(io.received_message).to eq(exception_data)
          end
        end

        context 'logging an exception without backtrace' do
          let(:stack) { [] }
          before do
            exception.set_backtrace(nil)
          end
          it 'logs an empty stack' do
            logger.exception(exception)
            expect(io.received_message).to eq(exception_data)
          end
        end

        context 'error when there is no exception class' do
          let(:base_message) do
            { 'timestamp' => time_string, 'message' => "String: #{message.inspect} ", 'data' => {} }
          end

          it 'Logs the exception message' do
            logger.exception(message)
            expect(io.received_message).to eq(base_message)
          end
        end
      end

      context 'Added some thread safe fields' do
        let(:new_fields) { { 'planet' => 'hyperion' } }
        let(:expected) { base_message.merge(new_fields) }
        let(:expected_data) { base_message.merge(data_field).merge(new_fields) }
        before do
          logger.add_fields(new_fields)
        end

        it_behaves_like 'Logging methods'

        it 'fields can be retrieved with #current_fields' do
          logger.debug(message)
          expect(logger.current_fields).to eq(expected)
        end

        context 'Keys which data is nil are not present in the output' do
          let(:new_fields) { { 'tree' => nil } }
          let(:expected) { base_message }
          let(:expected_data) { base_message.merge(data_field) }
          it_behaves_like 'Logging methods'
        end

        context 'Keys which data is empty are not present in the output' do
          let(:new_fields) { { 'tree' => {} } }
          let(:expected) { base_message }
          let(:expected_data) { base_message.merge(data_field) }
          it_behaves_like 'Logging methods'
        end

        context 'can remove fields' do
          let(:expected) { base_message }
          let(:expected_data) { base_message.merge(data_field) }
          before do
            logger.remove_fields(['planet'])
          end
          it_behaves_like 'Logging methods'
        end

        context 'can remove fields not present' do
          let(:expected) { base_message.merge(new_fields) }
          let(:expected_data) { base_message.merge(data_field).merge(new_fields) }
          before do
            logger.remove_fields(['stars'])
          end
          it_behaves_like 'Logging methods'
        end

        context 'Can keep adding fields' do
          let(:more_fields) { { 'shriek' => 'tree' } }
          let(:all_fields) { new_fields.merge(more_fields) }
          let(:expected) { base_message.merge(all_fields) }
          let(:expected_data) { base_message.merge(data_field).merge(all_fields) }
          before do
            logger.add_fields(more_fields)
          end
          it_behaves_like 'Logging methods'
        end

        context 'thread safe variables modified' do
          let(:more_fields) { { 'shriek' => 'tree' } }
          it 'do not modify other threads' do
            logger = described_class.new(io)
            Thread.new do
              logger.add_fields(more_fields)
            end.join
            logger.error(message)
            expect(io.received_message).to eq(base_message)
          end
        end
      end

      context 'Added some thread unsafe fields' do
        let(:new_fields) { { 'planet' => 'hyperion' } }
        let(:expected) { base_message.merge(new_fields) }
        let(:expected_data) { base_message.merge(data_field).merge(new_fields) }
        before do
          logger.add_thread_unsafe_fields(new_fields)
        end

        it_behaves_like 'Logging methods'

        context 'Keys which data is nil are not present in the output' do
          let(:new_fields) { { 'tree' => nil } }
          let(:expected) { base_message }
          let(:expected_data) { base_message.merge(data_field) }
          it_behaves_like 'Logging methods'
        end

        context 'can remove fields' do
          let(:expected) { base_message }
          let(:expected_data) { base_message.merge(data_field) }
          before do
            logger.remove_thread_unsafe_fields(['planet'])
          end
          it_behaves_like 'Logging methods'
        end

        context 'Can keep adding fields' do
          let(:more_fields) { { 'shriek' => 'tree' } }
          let(:all_fields) { new_fields.merge(more_fields) }
          let(:expected) { base_message.merge(all_fields) }
          let(:expected_data) { base_message.merge(data_field).merge(all_fields) }
          before do
            logger.add_thread_unsafe_fields(more_fields)
          end
          it_behaves_like 'Logging methods'
        end

        context 'thread unsafe variables modified' do
          let(:more_fields) { { 'shriek' => 'tree' } }
          let(:all_fields) { new_fields.merge(more_fields) }
          let(:expected) { base_message.merge(all_fields) }
          let(:expected_data) { base_message.merge(data_field).merge(all_fields) }
          before do
            Thread.new do
              logger.add_thread_unsafe_fields(more_fields)
            end.join
          end
          it_behaves_like 'Logging methods'
        end
      end
    end

    context 'Logger with empty IO' do
      let(:logger) { described_class.new(nil) }

      Lorekeeper::JSONLogger::LOGGING_METHODS.each do |method|
        it "No data is written to the device for #{method}" do
          expect(io).not_to receive(:write)
          logger.send(method, message)
        end
        it "No data is written to the device for #{method}_with_data" do
          expect(io).not_to receive(:write)
          logger.send("#{method}_with_data", message, data)
        end
      end
    end
  end
end
