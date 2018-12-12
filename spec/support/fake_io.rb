# frozen_string_literal: true

class FakeIO
  attr_reader :received_messages

  def initialize
    @msg = nil
    @received_messages = []
  end

  def close; end

  def write(msg)
    @msg = msg
    @received_messages << @msg
  end

  def received_message
    @msg
  end
end

class FakeJSONIO < FakeIO
  def received_message
    @msg && Oj.load(@msg)
  end

  def received_messages
    @received_messages.map { |m| Oj.load(m) }
  end
end
