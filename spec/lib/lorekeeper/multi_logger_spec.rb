# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lorekeeper::MultiLogger do
  let(:io) { FakeIO.new }
  let(:json_io) { FakeJSONIO.new }
  let(:logger) { described_class.new }

  context 'no loggers added' do
    it 'does not raise any error calling any method' do
      expect { logger.error }.not_to raise_error
    end
  end

  context 'loggers added' do
    let(:message) { 'My heart aches, and a drowsy numbness pains my sense' }
    let(:console_logger) { Lorekeeper::SimpleLogger.new(io) }
    let(:json_logger) { Lorekeeper::JSONLogger.new(json_io) }
    let(:fakeio) { FakeIO.new }

    it 'calls all log level methods of loggers' do
      logger.add_logger(console_logger)
      logger.add_logger(json_logger)

      Lorekeeper::FastLogger::LOGGING_METHODS.each do |log_level|
        logger.send(log_level, message)

        expect(io.received_message).to include(message)
        expect(json_io.received_message).to include(
          'message' => message,
          'level' => log_level == :warn ? 'warning' : log_level.to_s
        )
      end
    end

    context 'with data' do
      it 'calls all log level methods of loggers' do
        logger.add_logger(console_logger)
        logger.add_logger(json_logger)

        Lorekeeper::FastLogger::LOGGING_METHODS.each do |log_level|
          logger.send("#{log_level}_with_data", message, { sum: 123 })

          expect(io.received_message).to include("#{message}, data: {:sum=>123}")
          expect(json_io.received_message).to include(
            'message' => message,
            'level' => log_level == :warn ? 'warning' : log_level.to_s,
            'data' => { 'sum' => 123 }
          )
        end
      end
    end

    context 'with_level' do
      it 'calls with_level method of loggers' do
        logger.add_logger(console_logger)
        logger.add_logger(json_logger)
        logger.level = :info

        logger.with_level(:debug) { logger.debug(message) }

        expect(io.received_message).to include(message)
        expect(json_io.received_message).to include('message' => message, 'level' => 'debug')
        expect(logger.level).to eq(Lorekeeper::FastLogger::INFO)
      end
    end

    %i[
      current_fields state add_thread_unsafe_fields remove_thread_unsafe_fields add_fields remove_fields
    ].each do |method|
      it "does not raise NoMethodError for the #{method} method" do
        logger.add_logger(console_logger)

        expect { logger.send(method) }.to_not raise_error
      end
    end

    it 'calls write method of loggers' do
      logger.add_logger(fakeio)

      logger.write(message)
      expect(fakeio.received_message).to eq(message)
    end
  end
end
