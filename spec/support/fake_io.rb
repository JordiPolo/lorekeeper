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
    @msg && load_json(@msg)
  end

  def received_messages
    @received_messages.map { |m| load_json(m) }
  end

  private

  def load_json(message)
    if defined?(Oj)
      Oj.load(message)
    else
      JSON.parse(message)
    end
  end
end
