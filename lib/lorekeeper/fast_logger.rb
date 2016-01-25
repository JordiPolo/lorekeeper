# frozen_string_literal: true
# The comment above will make all strings in a current file frozen
require 'logger'

module Lorekeeper
  # Very simple, very fast logger
  class FastLogger
    include ::Logger::Severity  # contains the levels constants: DEBUG, ERROR, etc.
    attr_accessor :level        # Current level, default: DEBUG
    attr_accessor :formatter    # Just for compatibility with Logger, not used

    def debug?; level <= DEBUG; end
    def info?; level <= INFO; end
    def warn?; level <= WARN; end
    def error?; level <= ERROR; end
    def fatal?; level <= FATAL; end

    def initialize(file)
      @level = DEBUG
      @iodevice = LogDevice.new(file)
    end

    LOGGING_METHODS = %i(debug info warn error fatal)
    METHOD_SEVERITY_MAP = { debug: DEBUG, info: INFO, warn: WARN, error: ERROR, fatal: FATAL }

    # We define the behaviour of all the usual logging methods
    # We support a string as a parameter and also a block
    LOGGING_METHODS.each do |method_name|
      define_method method_name.to_s, ->(message_param = nil, &block) do
        add(METHOD_SEVERITY_MAP[method_name], message_param, nil, &block)
      end
    end

    # This is part of the standard Logger API, we need this to be compatible
    def add(severity, message_param = nil, _ = nil, &block)
      return true if severity < @level
      message = message_param || (block && block.call)
      log_data(severity, message.freeze)
    end

    # Some gems like to add this method. For instance:
    # https://github.com/rails/activerecord-session_store
    # To avoid needing to monkey-patch Lorekeeper just to get this method, we are adding a simple
    # non-functional version here.
    def silence_logger(&block)
      yield if block_given?
    end

    # inherited classes probably want to reimplement this
    def log_data(_severity, message)
      @iodevice.write(message)
    end

    private

    require 'monitor'
    # Mutex to avoid broken lines when multiple threads access the log file
    class LogDeviceMutex
      include MonitorMixin
    end

    # Very fast class to write to a log file.
    class LogDevice
      def initialize(file)
        @iodevice = to_iodevice(file)
        @iomutex = LogDeviceMutex.new
      end

      def write(message)
        return unless @iodevice
        @iomutex.synchronize do
          @iodevice.write(message)
        end
      end

      private

      def to_iodevice(file)
        return nil unless file
        iodevice = if file.respond_to?(:write) and file.respond_to?(:close)
          file
        else
          open_logfile(file)
        end
        iodevice.sync = true if iodevice.respond_to?(:sync=)
        iodevice
      end

      def open_logfile(filename)
        File.open(filename, (File::WRONLY | File::APPEND))
      rescue Errno::ENOENT => e
        puts "File #{filename} can't be open for logging. #{e.message}"
      end
    end
  end
end
