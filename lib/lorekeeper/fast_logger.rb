# frozen_string_literal: true

require 'logger'

module Lorekeeper
  # Very simple, very fast logger
  class FastLogger
    include ::Logger::Severity # contains the levels constants: DEBUG, ERROR, etc.
    attr_accessor :level, :formatter # Current level, default: DEBUG    # Just for compatibility with Logger, not used

    def debug?
      level <= DEBUG
    end

    def info?
      level <= INFO
    end

    def warn?
      level <= WARN
    end

    def error?
      level <= ERROR
    end

    def fatal?
      level <= FATAL
    end

    def initialize(file)
      @level = DEBUG
      @iodevice = LogDevice.new(file)
      @file = file # We only keep this so we can inspect where we are sending the logs
    end

    LOGGING_METHODS = %i[
      debug
      info
      warn
      error
      fatal
    ].freeze

    METHOD_SEVERITY_MAP = {
      debug: DEBUG,
      info: INFO,
      warn: WARN,
      error: ERROR,
      fatal: FATAL
    }.freeze

    SEVERITY_NAMES_MAP = {
      DEBUG => 'debug',
      INFO => 'info',
      WARN => 'warning',
      ERROR => 'error',
      FATAL => 'fatal'
    }.freeze

    # We define the behaviour of all the usual logging methods
    # We support a string as a parameter and also a block
    LOGGING_METHODS.each do |method_name|
      define_method method_name.to_s, lambda { |message_param = nil, &block|
        add(METHOD_SEVERITY_MAP[method_name], message_param, nil, &block)
      }
    end

    # This is part of the standard Logger API, we need this to be compatible
    def add(severity, message_param = nil, progname = nil, &block)
      return true if severity < @level

      message = block&.call || message_param || progname
      log_data(severity, message.freeze)
    end

    # Some gems like to add this method. For instance:
    # https://github.com/rails/activerecord-session_store
    # To avoid needing to monkey-patch Lorekeeper just to get this method, we are adding a simple
    # non-functional version here.
    def silence_logger
      yield if block_given?
    end

    # activerecord-session_store v2 is now simply calling silence instead of silence_logger
    def silence
      yield if block_given?
    end

    # inherited classes probably want to reimplement this
    def log_data(_severity, message)
      write(message)
    end

    def write(message)
      @iodevice.write(message)
    end

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

        iodevice = if file.respond_to?(:write) && file.respond_to?(:close)
                     file
                   else
                     open_logfile(file)
                   end

        iodevice.sync = true if iodevice.respond_to?(:sync=)
        iodevice
      end

      def open_logfile(filename)
        File.open(filename, (File::WRONLY | File::APPEND))
      rescue Errno::ENOENT
        create_logfile(filename)
      end

      def create_logfile(filename)
        File.open(filename, (File::WRONLY | File::APPEND | File::CREAT))
      rescue Errno::EEXIST
        open_logfile(filename)
      end
    end
  end
end
