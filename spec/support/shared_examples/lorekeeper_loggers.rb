# frozen_string_literal: true

RSpec.shared_examples 'Lorekeeper loggers' do
  let(:message) { 'All was well.' }

  it 'respond to write' do
    logger.public_send(:write, message)
    expect(io.received_message).to eq(message)
  end
end
