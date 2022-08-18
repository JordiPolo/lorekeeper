# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe Lorekeeper::SimpleLogger do
  let(:io) { FakeIO.new }
  let(:logger) { described_class.new(io) }
  let(:message) { 'Blazing Hyperion on his orbed fire still sat' }

  describe 'logging' do
    described_class::LOGGING_METHODS.each do |method|
      it "can log with the method #{method}" do
        logger.send(method, message)
        # output includes color switches so do a partial match instead of using "eq"
        expect(io.received_message).to include(message)
      end
    end
  end

  describe '#log_data' do
    it 'replaces \n and \t' do
      logger.log_data(:info, 'line: 5, column: 27\n\tat io.swagger.v3.parser')
      expect(io.received_message).to eq("\e[mline: 5, column: 27\n\tat io.swagger.v3.parser\e[0m\n")
    end
  end

  describe '#inspect' do
    it 'returns info about the logger itself' do
      expect(logger.inspect).to match(/\ALorekeeper Simple logger. IO: #<FakeIO/)
    end
  end

  describe '#exception' do
    let(:exception_msg) { 'This is an exception' }
    let(:exception) { StandardError.new(exception_msg) }
    let(:backtrace) { ['First line', 'Second line'] }

    before do
      exception.set_backtrace(backtrace)
    end

    context 'Logging just an exception' do
      let(:expected) do
        "\e[31mStandardError: #{exception_msg}; #{exception_msg} \n\nstack:\nFirst line\nSecond line \e[0m\n"
      end

      it 'Falls back to ERROR if if the specified level is not recognized' do
        logger.exception(exception, nil, nil, :critical)
        expect(io.received_message).to eq(expected)

        logger.exception(exception, level: :critical)
        expect(io.received_message).to eq(expected)
      end

      it 'Logs the exception with the error level by default' do
        logger.exception(exception)
        expect(io.received_message).to eq(expected)
      end

      it 'Logs the exception with a specified error level' do
        logger.exception(exception, nil, nil, :fatal)
        expect(io.received_message).to eq(expected)

        logger.exception(exception, level: :fatal)
        expect(io.received_message).to eq(expected)
      end
    end

    context 'with a custom message' do
      let(:custom_message) { 'some unreal condition happened' }
      let(:expected) do
        "\e[31mStandardError: #{exception_msg}; #{custom_message} \n\nstack:\nFirst line\nSecond line \e[0m\n"
      end

      it 'Logs the exception with the error level by default' do
        logger.exception(exception, custom_message)
        expect(io.received_message).to eq(expected)

        logger.exception(exception, message: custom_message)
        expect(io.received_message).to eq(expected)
      end
    end

    context 'with a custom_data' do
      let(:custom_data) { { command: 'java -jar openapi-generator.jar generate' } }
      let(:expected) do
        "\e[31mStandardError: #{exception_msg}; #{exception_msg} \n\nstack:\nFirst line\nSecond line " \
          "\n\ndata:\n{:command=>\"java -jar openapi-generator.jar generate\"}\e[0m\n"
      end

      it 'Logs the exception with the custom_data' do
        logger.exception(exception, data: custom_data)
        expect(io.received_message).to eq(expected)
      end
    end

    context 'error when there is no exception class' do
      let(:expected) do
        [
          "\e[33mLogger exception called without exception class.\e[0m\n",
          "\e[31mString: \"Blazing Hyperion on his orbed fire still sat\" , data: \e[0m\n"
        ]
      end

      it 'Logs the exception message' do
        logger.exception(message)
        expect(io.received_messages).to eq(expected)
      end
    end
  end

  describe 'JSONLogger methods' do
    %i[
      current_fields state add_thread_unsafe_fields remove_thread_unsafe_fields add_fields remove_fields
    ].each do |method|
      it "does not raise NoMethodError for the #{method} method" do
        expect { logger.send(method) }.to_not raise_error
      end
    end
  end
end
