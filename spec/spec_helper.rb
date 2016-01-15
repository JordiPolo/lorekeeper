$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require_relative 'support/fake_io'
require 'lorekeeper'
require 'timecop'

Bundler.setup

RSpec.configure do |config|
  config.mock_with :rspec do |c|
    c.syntax = :expect
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.order = 'random'
end
