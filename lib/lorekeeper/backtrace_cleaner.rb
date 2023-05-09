# frozen_string_literal: true

require 'singleton'

module Lorekeeper
  class BacktraceCleaner
    include Singleton

    def initialize
      @backtrace_cleaner = set_backtrace_cleaner
      @rails_root = defined?(Rails.root) ? Rails.root.to_s : nil
      @rails_root_size = @rails_root.to_s.size
      @gem_path = defined?(Gem.path) ? Gem.path : []
      @denylisted_fingerprint = denylisted_fingerprint
    end

    def clean(backtrace)
      return [] unless backtrace.is_a?(Array)

      backtrace = filter_rails_root_backtrace(backtrace)
      @backtrace_cleaner&.clean(backtrace) || backtrace
    end

    private

    DENYLISTED_FINGERPRINT =
      %r{newrelic_rpm|active_support/callbacks.rb|zipkin-tracer|puma|phusion_passenger|opentelemetry}.freeze

    def denylisted_fingerprint
      return DENYLISTED_FINGERPRINT unless ENV.key?('LOREKEEPER_DENYLIST')

      /#{ENV.fetch('LOREKEEPER_DENYLIST').split(',').map(&:strip).join('|')}/
    end

    def filter_rails_root_backtrace(backtrace)
      return backtrace unless @rails_root

      last_index = nil
      result = []
      backtrace.each_with_index do |line, idx|
        if line.start_with?(@rails_root) && @gem_path.none? { |path| line.start_with?(path) }
          result << line[@rails_root_size..]
          last_index = idx
        else
          result << line
        end
      end

      last_index ? result[..last_index] : result
    end

    def set_backtrace_cleaner
      return nil unless defined?(ActiveSupport::BacktraceCleaner)

      cleaner = ActiveSupport::BacktraceCleaner.new
      cleaner.remove_silencers!
      cleaner.add_silencer do |line|
        line.match?(@denylisted_fingerprint) || line.start_with?(RbConfig::CONFIG['rubylibdir'])
      end
      cleaner
    end
  end
end
