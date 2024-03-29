# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe Lorekeeper::FastLogger do
  let(:io) { FakeIO.new }
  let(:logger) { described_class.new(io) }
  let(:message) { 'And think that I may never live to trace their shadows' }
  let(:progname) { 'my_progname' }

  describe 'log levels' do
    LEVEL_CHECKERS =
      {
        -1 =>
          { debug?: true, info?: true, warn?: true, error?: true, fatal?: true },
        described_class::DEBUG =>
          { debug?: true, info?: true, warn?: true, error?: true, fatal?: true },
        described_class::INFO =>
          { debug?: false, info?: true, warn?: true, error?: true, fatal?: true },
        described_class::WARN =>
          { debug?: false, info?: false, warn?: true, error?: true, fatal?: true },
        described_class::ERROR =>
          { debug?: false, info?: false, warn?: false, error?: true, fatal?: true },
        described_class::FATAL =>
          { debug?: false, info?: false, warn?: false, error?: false, fatal?: true },
        :debug =>
          { debug?: true, info?: true, warn?: true, error?: true, fatal?: true },
        :info =>
          { debug?: false, info?: true, warn?: true, error?: true, fatal?: true },
        :warn =>
          { debug?: false, info?: false, warn?: true, error?: true, fatal?: true },
        :error =>
          { debug?: false, info?: false, warn?: false, error?: true, fatal?: true },
        :fatal =>
          { debug?: false, info?: false, warn?: false, error?: false, fatal?: true }
      }.freeze
    LEVEL_CHECKERS.each_pair do |log_level, checkers|
      it "level checkers return correct values for #{log_level}" do
        logger.level = log_level
        checkers.each_pair do |method, result|
          expect(logger.send(method)).to eq(result)
        end
      end
    end
  end

  describe '#with_level' do
    it 'changes log level' do
      expect(logger.level).to eq(described_class::DEBUG)

      logger.with_level(:warn) do
        expect(logger.level).to eq(described_class::WARN)

        logger.with_level(:info) do
          expect(logger.level).to eq(described_class::INFO)

          Thread.new do
            expect(logger.level).to eq(described_class::DEBUG)
            logger.with_level(:error) do
              expect(logger.level).to eq(described_class::ERROR)
            end
            expect(logger.level).to eq(described_class::DEBUG)
          end.join

          expect(logger.level).to eq(described_class::INFO)
        end
        expect(logger.level).to eq(described_class::WARN)
      end
      expect(logger.level).to eq(described_class::DEBUG)
    end
  end

  describe 'initialization' do
    it 'defaults to debug level' do
      expect(logger.level).to eq(described_class::DEBUG)
    end

    it 'opens files for writing' do
      filename = Tempfile.new('logging_file')
      logger = described_class.new(filename)
      logger.error(message)
      expect(File.read(filename)).to eq(message)
    end

    it 'creates files for writing if they do not exist' do
      filename = '/tmp/non_existent_file'
      FileUtils.rm_f(filename)
      logger = described_class.new(filename)
      logger.error(message)
      expect(File.read(filename)).to eq(message)
    end
  end

  describe '#add' do
    it 'logs the message_param' do
      expect(logger).to receive(:log_data).with(described_class::DEBUG, message)
      logger.add(described_class::DEBUG, message, progname)
    end

    it 'logs the block if no message_param is given' do
      expect(logger).to receive(:log_data).with(described_class::DEBUG, message)
      logger.add(described_class::DEBUG, nil, progname) { message }
    end

    it 'logs the progname if no message and block are given' do
      expect(logger).to receive(:log_data).with(described_class::DEBUG, progname)
      logger.add(described_class::DEBUG, nil, progname)
    end
  end

  describe '#silence_logger' do
    it 'silencing yields the code passed to it' do
      expect { |b| logger.silence_logger(&b) }.to yield_with_no_args
    end
  end

  describe '#silence' do
    it 'silencing yields the code passed to it' do
      expect { |b| logger.silence(&b) }.to yield_with_no_args
    end
  end

  describe 'logging' do
    Lorekeeper::FastLogger::LOGGING_METHODS.each do |method|
      it "can log with the method #{method}" do
        logger.send(method, message)
        expect(io.received_message).to eq(message)
      end
    end
  end

  describe '#write' do
    it 'writes message to io' do
      logger.write(message)
      expect(io.received_message).to eq(message)
    end
  end

  describe '#coerce' do
    Lorekeeper::FastLogger::METHOD_SEVERITY_MAP.each do |key, level|
      it 'returns log level' do
        logger.coerce(key)
        expect(logger.coerce(key)).to eq(level)
      end
    end

    it 'raises an exception when log level is invalid' do
      expect { logger.coerce(:bad) }.to raise_error(ArgumentError, 'invalid log level: bad')
    end
  end
end
