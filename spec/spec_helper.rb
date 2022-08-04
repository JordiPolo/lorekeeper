# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require_relative 'support/fake_io'
require 'lorekeeper'
require 'timecop'
require 'byebug'
require 'support/shared_examples/lorekeeper_loggers'

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.mock_with :rspec do |c|
    c.syntax = :expect
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.warnings = true

  config.order = :random
  Kernel.srand config.seed
end
