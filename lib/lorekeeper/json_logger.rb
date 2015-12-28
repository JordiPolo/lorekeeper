# frozen_string_literal: true
# The comment above will make all strings in a current file frozen
require 'oj'
require 'lorekeeper/fast_logger'

module Lorekeeper
  # The JSONLogger provides a logger which will output messages in JSON format
  class JSONLogger < FastLogger
    def initialize(file)
      @base_fields = { 'message' => '', 'timestamp' => '' }
      super(file)
    end

    def state
      thread_key = @thread_key ||= "lorekeeper_#{object_id}".freeze
      Thread.current[thread_key] ||= begin
        { base_fields: @base_fields.dup, extra_fields: {}}
      end
    end

    # Delegates methods to the existing Logger instance
    # We are extending the logger API with methods error_with_data, etc
    LOGGING_METHODS.each do |method_name|
      define_method "#{method_name}_with_data", ->(message_param = nil, data = {}, &block) do
        return true if METHOD_SEVERITY_MAP[method_name] < @level
        extra_fields = {'data' => (data || {}) }
        message = message_param || (block && block.call)
        with_extra_fields(extra_fields) { log_data(method_name, message.freeze) }
      end
    end

    def add_thread_unsafe_fields(fields)
      fields.delete_if { |_, v| v.nil? }
      @base_fields.merge!(fields)
    end

    def remove_thread_unsafe_fields(fields)
      [*fields].each do |field|
        @base_fields.delete(field)
      end
    end

    def add_fields(fields)
       fields.delete_if { |_, v| v.nil? }
       state[:base_fields].merge!(fields)
    end

    def remove_fields(fields)
      [*fields].each do |field|
        state[:base_fields].delete(field)
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

   def with_extra_fields(fields)
     state[:extra_fields] = fields
     yield
     state[:extra_fields] = {}
   end

    DATE_FORMAT = '%FT%T.%L%z'.freeze
    MESSAGE = 'message'.freeze
    TIMESTAMP = 'timestamp'.freeze

    def log_data(_method_sym, message)
      fields_to_log = if state[:extra_fields].empty?
        state[:base_fields]
      else
        state[:base_fields].merge(state[:extra_fields])
      end

      fields_to_log[MESSAGE] = message
      fields_to_log[TIMESTAMP] = Time.now.strftime(DATE_FORMAT)

      @iodevice.write(Oj.dump(fields_to_log) + "\n")
    end
  end

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
      @loggers.each do |logger|
        logger.send(method, *args, &block) if logger.respond_to?(method)
      end
    end
  end

  # Simple logger which tries to have an easy to see output.
  class SimpleLogger < FastLogger
    SUCCESS = '96'
    WHITE = '97'
    SEVERITY_TO_COLOR_MAP   = {debug: '0;37', info: '0;37', warn: '33', error: '31', fatal: '31', unknown: '37'}
    INDENT = ' ' * 8
    TITLE_RIBBON = "\n****************************************************************************\n".freeze

    def log_data(method_sym, message)
      color = SEVERITY_TO_COLOR_MAP[method_sym]
      indent = ''

      if message.start_with?('Started ')
        color = WHITE
        message = message + TITLE_RIBBON
      end

      completed_transaction = message.match(/Completed (\d*)/)
      if completed_transaction
        if completed_transaction.captures.first.to_i > 400
          color = SEVERITY_TO_COLOR_MAP[:error]
        else
          color = SUCCESS #SEVERITY_TO_COLOR_MAP[:info]
        end
        message = TITLE_RIBBON + message + TITLE_RIBBON
      end
      @iodevice.write("#{indent}\033[#{color}m#{message}\033[0m\n")
    end
  end


end
