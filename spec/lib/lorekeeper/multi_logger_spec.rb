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

    it 'calls all the methods of the loggers' do
      logger.add_logger(console_logger)
      logger.add_logger(json_logger)

      Lorekeeper::FastLogger::LOGGING_METHODS.each do |log_level|
        logger.send(log_level, message) if logger.respond_to? (log_level)

        expect(io.received_message).to include(message)
        expect(json_io.received_message).to include(
          'message' => message,
          'level' => log_level == :warn ? 'warning' : log_level.to_s
        )
      end
    end
  end
end
