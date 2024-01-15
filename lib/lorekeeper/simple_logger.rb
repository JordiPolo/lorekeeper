# frozen_string_literal: true

require 'lorekeeper/fast_logger'

module Lorekeeper
  # Simple logger provides a logger which outputs messages in a colorized simple text format.
  class SimpleLogger < FastLogger
    # From http://misc.flogisoft.com/bash/tip_colors_and_formatting
    # 39: default for the theme
    # 33: yellow
    # 31: red
    # 37: light gray

    COLOR_DEFAULT = '39'
    COLOR_YELLOW = '33'
    COLOR_RED = '31'
    COLOR_LIGHT_GRAY = '37'

    SEVERITY_TO_COLOR_MAP = {
      DEBUG => COLOR_DEFAULT,
      INFO => COLOR_DEFAULT,
      WARN => COLOR_YELLOW,
      ERROR => COLOR_RED,
      FATAL => COLOR_RED,
      UNKNOWN => COLOR_LIGHT_GRAY
    }.freeze

    # \e[colorm sets a color \e[0m resets all properties
    def log_data(severity, message)
      color = SEVERITY_TO_COLOR_MAP[severity]
      message = message.to_s
      write("\e[#{color}m#{message.gsub('\n', "\n").gsub('\t', "\t")}\e[0m\n")
    end

    def inspect
      "Lorekeeper Simple logger. IO: #{@file.inspect}"
    end

    # Extending the logger API with methods error_with_data, etc
    LOGGING_METHODS.each do |method_name|
      define_method :"#{method_name}_with_data", ->(message_param = nil, data = {}) {
        return true if METHOD_SEVERITY_MAP[method_name] < @level

        log_data(METHOD_SEVERITY_MAP[method_name], "#{message_param}, data: #{data}")
      }
    end

    # To not raise NoMethodError for the methods defined in JSONLogger
    def current_fields(*); end

    def state(*); end

    def add_thread_unsafe_fields(*); end

    def remove_thread_unsafe_fields(*); end

    def add_fields(*); end

    def remove_fields(*); end

    def exception(exception, custom_message = nil, custom_data = nil, custom_level = :error,
      message: nil, data: nil, level: nil)

      param_level = level || custom_level
      param_data = data || custom_data
      param_message = message || custom_message

      log_level = METHOD_SEVERITY_MAP[param_level] || ERROR

      if exception.is_a?(Exception)
        message = param_message || exception.message
        backtrace = "\n\nstack:\n#{exception.backtrace.join("\n")}" if exception.backtrace
        data = "\n\ndata:\n#{param_data}" if param_data
        log_data(log_level, "#{exception.class}: #{exception.message}; #{message} #{backtrace} #{data}")
      else
        log_data(METHOD_SEVERITY_MAP[:warn], 'Logger exception called without exception class.')
        error_with_data("#{exception.class}: #{exception.inspect} #{param_message}", param_data)
      end
    end
  end
end
