# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'active_support'

RSpec.describe Lorekeeper do
  describe Lorekeeper::JSONLogger do
    let(:io) { FakeJSONIO.new }
    let(:current_time) { Time.utc(1897, 1, 1) }
    let(:time_string) { '1897-01-01T00:00:00.000000Z'}
    let(:level) { 'debug' }
    let(:error_level) { { 'level' => 'error' } }
    let(:message) { 'Blazing Hyperion on his orbed fire still sat' }
    let(:data) { { 'some' => 'data' } }
    let(:base_message) { { 'message' => message, 'timestamp' => time_string, 'level' => level } }
    let(:data_field) { { 'data' => data } }
    let(:level_name) do
      -> (method_sym) {
        # 'warn' is logged as 'warning' so we need to look it up instead of using the method name... :facepalm:
        severity = described_class::METHOD_SEVERITY_MAP[method_sym]
        described_class::SEVERITY_NAMES_MAP[severity]
      }
    end

    before do
      Timecop.freeze(current_time)
    end

    shared_examples_for 'Logging methods' do
      described_class::LOGGING_METHODS.each do |method|
        it "Outputs the correct format for #{method}" do
          logger.send(method, message)
          expect(io.received_message).to eq(expected.merge('level' => level_name.(method)))
        end
        it 'preserves the order of keys' do
          logger.send(method, message)
          expect(io.received_message.keys[0..2]).to eq(%w[timestamp message level])
        end
        it "Outputs the correct format for #{method}_with_data" do
          logger.send("#{method}_with_data", message, data)
          expect(io.received_message).to eq(expected_data.merge('level' => level_name.(method)))
        end
      end
    end

    context 'Logger with proper IO' do
      let(:logger) { described_class.new(io) }
      let(:expected) { base_message }
      let(:expected_data) { base_message.merge(data_field) }

      it_behaves_like 'Logging methods'

      describe '#inspect' do
        it 'returns info about the logger itself' do
          expect(logger.inspect).to match(/\ALorekeeper JSON logger. IO: #<FakeJSONIO/)
        end
      end

      describe '#exception' do
        let(:exception_msg) { 'This is an exception' }
        let(:exception) { StandardError.new(exception_msg) }
        let(:expected) { base_message.merge(exception_data) }
        let(:backtrace) { ['First line', 'Second line'] }
        let(:stack) { ['First line', 'Second line'] }
        let(:exception_data) do
          base_message.merge(
            'exception' => "StandardError: #{exception_msg}",
            'message' => exception_msg,
            'stack' => stack
          )
          .merge(error_level)
        end
        let(:new_backtrace) do
          [
            "/ruby/2.5.0/gems/activesupport-4.2.11/lib/active_support/callbacks.rb:121:in `instance_exec'",
            "/ruby/2.5.0/gems/activesupport-4.2.11/lib/active_support/callbacks.rb:121:in `block in run_callbacks'",
            "/ruby/2.5.0/gems/newrelic_rpm-5.7.0.350/lib/new_relic/agent/instrumentation/middleware_tracing.rb:92:in `call'",
            "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/cookies.rb:560:in `call'",
            "/ruby/2.5.0/gems/newrelic_rpm-5.7.0.350/lib/new_relic/agent/instrumentation/middleware_tracing.rb:92:in `call'",
            "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/callbacks.rb:29:in `block in call'",
            "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/callbacks.rb:27:in `call'",
            "/ruby/2.5.0/gems/newrelic_rpm-5.7.0.350/lib/new_relic/agent/instrumentation/middleware_tracing.rb:92:in `call'",
            "/ruby/2.5.0/gems/zipkin-tracer-0.47.3/lib/zipkin-tracer/rack/zipkin-tracer.rb:29:in `block (3 levels) in call'",
            "/ruby/2.5.0/gems/zipkin-tracer-0.47.3/lib/zipkin-tracer/rack/zipkin-tracer.rb:51:in `trace!'",
            "/ruby/2.5.0/gems/zipkin-tracer-0.47.3/lib/zipkin-tracer/rack/zipkin-tracer.rb:29:in `block (2 levels) in call'",
            "/ruby/2.5.0/gems/zipkin-tracer-0.47.3/lib/zipkin-tracer/zipkin_sender_base.rb:17:in `with_new_span'",
            "/ruby/2.5.0/gems/zipkin-tracer-0.47.3/lib/zipkin-tracer/rack/zipkin-tracer.rb:27:in `block in call'"
          ]
        end

        before do
          exception.set_backtrace(backtrace)
          allow(Gem).to receive(:path).and_return(["/ruby/2.5.0"])
        end

        context 'Logging just an exception' do
          it 'Falls back to ERROR if if the specified level is not recognized' do
            logger.exception(exception, nil, nil, :critical)
            expect(io.received_message).to eq(exception_data)

            logger.exception(exception, level: :critical)
            expect(io.received_message).to eq(exception_data)
          end

          it 'Logs the exception with the error level by default' do
            logger.exception(exception)
            expect(io.received_message).to eq(exception_data)
          end

          it 'Logs the exception with a specified error level' do
            logger.exception(exception, nil, nil, :fatal)
            expect(io.received_message).to eq(exception_data.merge('level' => 'fatal'))

            logger.exception(exception, level: :fatal)
            expect(io.received_message).to eq(exception_data.merge('level' => 'fatal'))
          end

          it 'Clears the exception fields after logging the exception' do
            logger.exception(exception)
            logger.info(message)
            expect(io.received_messages).to eq([
              exception_data,
              base_message.merge('level' => 'info')
            ])
          end

          it 'Does not log Newrelic instrumentation information and active_support callbacks' do
            exception.set_backtrace(new_backtrace)
            logger.exception(exception)

            no_newrelic_backtrace = if ActiveSupport::VERSION::MAJOR < 6
                [
                  "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/cookies.rb:560:in `call'",
                  "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/callbacks.rb:29:in `block in call'",
                  "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/callbacks.rb:27:in `call'",
                ]
              else
                [
                  "actionpack (4.2.11) lib/action_dispatch/middleware/cookies.rb:560:in `call'",
                  "actionpack (4.2.11) lib/action_dispatch/middleware/callbacks.rb:29:in `block in call'",
                  "actionpack (4.2.11) lib/action_dispatch/middleware/callbacks.rb:27:in `call'",
                ]
              end
            expected = exception_data.merge('stack' => no_newrelic_backtrace)

            expect(io.received_message).to eq(expected)
          end

          it 'Logs all backtraces when ActiveSupport::BacktraceCleaner is not defined' do
            hide_const('ActiveSupport::BacktraceCleaner')

            exception.set_backtrace(new_backtrace)
            logger.exception(exception)
            expected = exception_data.merge('stack' => new_backtrace)

            expect(io.received_message).to eq(expected)
          end
        end

        context 'Logging an exception with custom level' do
          let(:exception_data) do
            base_message.merge(
              'exception' => "StandardError: #{exception_msg}",
              'message' => exception_msg,
              'stack' => stack,
              'level' => 'info'
            )
          end

          it 'Logs the exception with the level in the parameters' do
            logger.exception(exception, nil, nil, :info)
            expect(io.received_message).to eq(exception_data)

            logger.exception(exception, level: :info)
            expect(io.received_message).to eq(exception_data)
          end
        end

        context 'Logging an exception with custom message' do
          let(:exception_data) do
            base_message.merge(
              'exception' => "StandardError: #{exception_msg}",
              'message' => message,
              'stack' => stack
            )
            .merge(error_level)
          end
          it 'Logs the exception' do
            logger.exception(exception, message)
            expect(io.received_message).to eq(exception_data)

            logger.exception(exception, message: message)
            expect(io.received_message).to eq(exception_data)
          end
        end

        context 'Logging an exception with custom message and data' do
          let(:exception_data) do
            base_message
              .merge(
                'exception' => "StandardError: #{exception_msg}",
                'message' => message,
                'stack' => stack
              )
              .merge(data_field)
              .merge(error_level)
          end
          it 'Logs the exception' do
            logger.exception(exception, message, data)
            expect(io.received_message).to eq(exception_data)

            logger.exception(exception, message: message, data: data)
            expect(io.received_message).to eq(exception_data)
          end
        end

        context 'Logging an exception with custom message and data in symbol key' do
          let(:data_with_symbol_key) { { some: 'data' } }
          let(:exception_data) do
            base_message
              .merge(
                'exception' => "StandardError: #{exception_msg}",
                'message' => message,
                'stack' => stack
              )
              .merge(data_field)
              .merge(error_level)
          end
          it 'Logs the exception with data in string key' do
            logger.exception(exception, message: message, data: data_with_symbol_key)
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
            [
              {
                'level' => 'warning',
                'message' => 'Logger exception called without exception class.',
                'timestamp' => time_string
              },
              {
                'level' => 'error',
                'data' => { 'planet' => 'hyperion' },
                'message' => "String: #{message.inspect} second part not good",
                'timestamp' => time_string
              }
            ]
          end

          it 'Logs the exception message' do
            logger.exception(message, message: 'second part not good', data: { 'planet' => 'hyperion' })
            expect(io.received_messages).to eq(base_message)
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
            expect(io.received_message).to eq(base_message.merge(error_level))
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

          it 'removes information from the local thread' do
            expect(Thread.current[Lorekeeper::JSONLogger::THREAD_KEY]).to be_nil
          end
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

      describe '#inspect' do
        it 'returns info about the logger itself' do
          expect(logger.inspect).to eq("Lorekeeper JSON logger. IO: nil")
        end
      end

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
