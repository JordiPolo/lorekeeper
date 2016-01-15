# frozen_string_literal: true
module Lorekeeper
  # Allows to create a logger that will pass information to any logger registered
  # It is useful so send the same message thought different loggers to different sinks
  class MultiLogger
    def initialize
      @loggers = []
    end

    def add_logger(logger)
      @loggers << logger
    end

    def method_missing(method, *args, &block)
      result = @loggers.map do |logger|
        logger.public_send(method, *args, &block) if logger.respond_to?(method)
      end
      # We call all the methods, delete nils and duplicates.
      # Then hope for the best taking the first value
      result.compact.uniq.first
    end
  end
end
