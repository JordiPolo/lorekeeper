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
    SEVERITY_TO_COLOR_MAP = {
      DEBUG => '39',
      INFO => DEBUG,
      WARN => '33',
      ERROR => '31',
      FATAL => ERROR,
      UNKNOWN => '37'
    }.freeze

    # \e[colorm sets a color \e[0m resets all properties
    def log_data(severity, message)
      color = SEVERITY_TO_COLOR_MAP[severity]
      @iodevice.write("\e[#{color}m#{message}\e[0m\n")
    end

    def inspect
      "Lorekeeper Simple logger. IO: #{@file.inspect}"
    end

    # Extending the logger API with methods error_with_data, etc
    LOGGING_METHODS.each do |method_name|
      define_method "#{method_name}_with_data", ->(message_param = nil, data = {}, &block) do
        return true if METHOD_SEVERITY_MAP[method_name] < @level
        log_data(METHOD_SEVERITY_MAP[method_name], "#{message_param}, data: #{data}")
      end
    end

    def exception(exception, custom_message = nil, custom_data = nil, level = :error)
      log_level = METHOD_SEVERITY_MAP[level]
      unless log_level
        return log_data(METHOD_SEVERITY_MAP[:warn], "Logger exception called with an invalid level: '#{level}'.")
      end

      if exception.is_a?(Exception)
        backtrace = exception.backtrace || []
        message = custom_message || exception.message
        log_data(log_level, "#{exception.class}: #{message}, data: #{backtrace.join("\n")}")
      else
        log_data(METHOD_SEVERITY_MAP[:warn], 'Logger exception called without exception class.')
        message = "#{exception.class}: #{exception.inspect} #{custom_message}"
        with_extra_fields('data' => custom_data) { log_data(log_level, message) }
      end
    end
  end
end
