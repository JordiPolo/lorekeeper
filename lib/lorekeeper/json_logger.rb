# frozen_string_literal: true
# The comment above will make all strings in a current file frozen
require 'oj'
require 'lorekeeper/fast_logger'

module Lorekeeper
  # The JSONLogger provides a logger which will output messages in JSON format
  class JSONLogger < FastLogger

    def initialize(file)
      reset_state
      @base_fields = { MESSAGE => '', TIMESTAMP => '' }
      super(file)
    end

    def current_fields
      state[:base_fields]
    end

    def state
      Thread.current[THREAD_KEY] ||= { base_fields: @base_fields.dup, extra_fields: {} }
    end

    def reset_state
      Thread.current[THREAD_KEY] = nil
    end

    # Delegates methods to the existing Logger instance
    # We are extending the logger API with methods error_with_data, etc
    LOGGING_METHODS.each do |method_name|
      define_method "#{method_name}_with_data", ->(message_param = nil, data = {}, &block) do
        return true if METHOD_SEVERITY_MAP[method_name] < @level
        extra_fields = { 'data' => (data || {}) }
        with_extra_fields(extra_fields) { # Using do/end here only valid on Ruby>= 2.3
          add(METHOD_SEVERITY_MAP[method_name], message_param, nil, &block)
        }
      end
    end

    def add_thread_unsafe_fields(fields)
      remove_invalid_fields(fields)
      @base_fields.merge!(fields)
      reset_state # Forcing to recreate the thread safe information
    end

    def remove_thread_unsafe_fields(fields)
      [*fields].each do |field|
        @base_fields.delete(field)
      end
      reset_state
    end

    def add_fields(fields)
      remove_invalid_fields(fields)
      state.fetch(:base_fields).merge!(fields)
    end

    def remove_fields(fields)
      [*fields].each do |field|
        state.fetch(:base_fields).delete(field)
      end
    end

    # @param exception: instance of a class inheriting from Exception
    # We will output backtrace twice. Once inside the stack so it can be parsed by software
    # And the other inside the message so it is readable to humans
    def exception(exception, custom_message = nil, custom_data = nil)
      if exception.is_a?(Exception)
        backtrace = exception.backtrace || []
        exception_fields = {
          'exception' => "#{exception.class}: #{exception.message}",
          'stack' => backtrace
        }
        exception_fields['data'] = custom_data if custom_data

        message = custom_message || exception.message
        with_extra_fields(exception_fields) { log_data(:error, message) }
      else
        log_data(:warning, 'Logger exception called without exception class.')
        error_with_data("#{exception.class}: #{exception.inspect} #{custom_message}", custom_data)
      end
    end

    private

    THREAD_KEY = 'lorekeeper_jsonlogger_key'.freeze # Shared by all threads but unique by thread
    MESSAGE = 'message'.freeze
    TIMESTAMP = 'timestamp'.freeze
    DATE_FORMAT = '%FT%T.%L%z'.freeze

    def with_extra_fields(fields)
      state[:extra_fields] = fields
      yield
      state[:extra_fields] = {}
    end

    def remove_invalid_fields(fields)
      fields.delete_if do |_, v|
        v.nil? || v.respond_to?(:empty?) && v.empty?
      end
    end

    def log_data(_severity, message)
      # merging is slow, we do not want to merge with empty hash if possible
      fields_to_log = if state[:extra_fields].empty?
        state[:base_fields]
      else
        state[:base_fields].merge(state[:extra_fields])
      end

      fields_to_log[MESSAGE] = message
      fields_to_log[TIMESTAMP] = Time.now.utc.strftime(DATE_FORMAT)

      @iodevice.write(Oj.dump(fields_to_log) + "\n")
    end
  end

  # Simple logger which tries to have an easy to see output.
  class SimpleLogger < FastLogger
    SEVERITY_TO_COLOR_MAP = {
      DEBUG => '0;37', INFO => '0;37', WARN => '33',
      ERROR => '31', FATAL => '31', UNKNOWN => '37'
    }

    def log_data(severity, message)
      color = SEVERITY_TO_COLOR_MAP[severity]
      @iodevice.write("\033[#{color}m#{message}\033[0m\n")
    end
  end


end
