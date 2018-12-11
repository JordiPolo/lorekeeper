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
        "\e[31mStandardError: #{exception_msg}; #{exception_msg}, data: First line\nSecond line\e[0m\n"
      end

      it 'Falls back to ERROR if if the specified level is not recognized' do
        logger.exception(exception, nil, nil, :critical)
        expect(io.received_message).to eq(expected)
      end

      it 'Logs the exception with the error level by default' do
        logger.exception(exception)
        expect(io.received_message).to eq(expected)
      end

      it 'Logs the exception with a specified error level' do
        logger.exception(exception, nil, nil, :fatal)
        expect(io.received_message).to eq(expected)
      end
    end

    context 'with a custom message' do
      let(:custom_message) { 'some unreal condition happened' }
      let(:expected) do
        "\e[31mStandardError: #{exception_msg}; #{custom_message}, data: First line\nSecond line\e[0m\n"
      end

      it 'Logs the exception with the error level by default' do
        logger.exception(exception, custom_message)
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
end
