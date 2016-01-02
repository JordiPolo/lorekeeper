require 'spec_helper'

RSpec.describe Lorekeeper::MultiLogger do
  let(:io) { FakeIO.new }
  let(:io2) { FakeIO.new }
  let(:logger) { described_class.new }

  context 'no loggers added' do
    it 'does not raise any error calling any method' do
      expect{ logger.error }.not_to raise_error
    end
  end

  context 'loggers added' do
    let(:message) { 'My heart aches, and a drowsy numbness pains my sense' }
    before do
      logger.add_logger(io)
      logger.add_logger(io2)
    end
    it 'calls the methods of the loggers' do
      logger.write(message)
      expect(io.received_message).to eq(message)
      expect(io2.received_message).to eq(message)
    end

    it 'does not call the methods if they do not exist' do
      logger.idonotexist(message)
      expect(io.received_message).to eq(nil)
      expect(io2.received_message).to eq(nil)
    end

  end

end
