# frozen_string_literal: true

require 'oj'
require 'lorekeeper/fast_logger'

module Lorekeeper
  # The JSONLogger provides a logger which will output messages in JSON format
  class JSONLogger < FastLogger
    def initialize(file)
      reset_state
      @base_fields = { MESSAGE => '', TIMESTAMP => '', LEVEL => '' }
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
        extra_fields = { DATA => (data || {}) }
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
    def exception(exception, custom_message = nil, custom_data = nil, custom_level = :error,
                             message: nil, data: nil, level: nil) # Backwards compatible named params

      param_level = level || custom_level
      param_data = data || custom_data
      param_message = message || custom_message

      log_level = METHOD_SEVERITY_MAP[param_level] || ERROR

      if exception.is_a?(Exception)
        backtrace = exception.backtrace || []
        exception_fields = {
          EXCEPTION => "#{exception.class}: #{exception.message}",
          STACK => backtrace
        }
        exception_fields[DATA] = param_data if param_data

        message = param_message || exception.message
        with_extra_fields(exception_fields) { log_data(log_level, message) }
      else
        log_data(METHOD_SEVERITY_MAP[:warn], 'Logger exception called without exception class.')
        message = "#{exception.class}: #{exception.inspect} #{param_message}"
        with_extra_fields(DATA => (param_data || {})) { log_data(log_level, message) }
      end
    end

    def inspect
      "Lorekeeper JSON logger. IO: #{@file.inspect}"
    end

    private

    THREAD_KEY = 'lorekeeper_jsonlogger_key' # Shared by all threads but unique by thread
    LEVEL = 'level'
    MESSAGE = 'message'
    TIMESTAMP = 'timestamp'
    DATE_FORMAT = '%FT%T.%6NZ'
    EXCEPTION = 'exception'
    STACK = 'stack'
    DATA = 'data'

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

    def log_data(severity, message)
      # merging is slow, we do not want to merge with empty hash if possible
      fields_to_log = if state[:extra_fields].empty?
        state[:base_fields]
      else
        state[:base_fields].merge(state[:extra_fields])
      end

      fields_to_log[MESSAGE] = message
      fields_to_log[TIMESTAMP] = Time.now.utc.strftime(DATE_FORMAT)
      fields_to_log[LEVEL] = SEVERITY_NAMES_MAP[severity]

      @iodevice.write(Oj.dump(fields_to_log) << "\n")
    end
  end
end
