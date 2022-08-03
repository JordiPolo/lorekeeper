# frozen_string_literal: true

module Lorekeeper
  # Allows to create a logger that will pass information to any logger registered
  # It is useful so send the same message through different loggers to different sinks
  class MultiLogger
    def initialize
      @loggers = []
    end

    def add_logger(logger)
      @loggers << logger
    end

    def inspect
      "Lorekeeper multilogger, loggers: #{@loggers.map(&:inspect)}"
    end

    # Define all common logging methods within Multilogger to avoid NoMethodError
    def debug(*args, &block); call_loggers(:debug, *args, &block); end

    def debug_with_data(*args, &block); call_loggers(:debug, *args, &block); end

    def info(*args, &block); call_loggers(:info, *args, &block); end

    def info_with_data(*args, &block); call_loggers(:info, *args, &block); end

    def warn(*args, &block); call_loggers(:warn, *args, &block); end

    def warn_with_data(*args, &block); call_loggers(:warn, *args, &block); end

    def error(*args, &block); call_loggers(:error, *args, &block); end

    def error_with_data(*args, &block); call_loggers(:error, *args, &block); end

    def fatal(*args, &block); call_loggers(:fatal, *args, &block); end

    def fatal_with_data(*args, &block); call_loggers(:fatal, *args, &block); end

    def write(*args); call_loggers(:write, *args); end

    def respond_to?(method, all_included: false)
      @loggers.all? { |logger| logger.respond_to?(method, all_included) }
    end

    def call_loggers(method, *args, &block)
      result = @loggers.map do |logger|
        logger.public_send(method, *args, &block) if logger.respond_to?(method)
      end
      # We call all the methods, delete nils and duplicates.
      # Then hope for the best taking the first value
      result.compact.uniq.first
    end

    def method_missing(method, *args, &block)
      call_loggers(method, *args, &block)
    end
  end
end
