# frozen_string_literal: true

require 'spec_helper'
require 'active_support'

RSpec.describe Lorekeeper do
  describe Lorekeeper::BacktraceCleaner do
    let(:instance) { described_class.instance }

    around(:example) do |ex|
      described_class.instance_variable_set(:@singleton__instance__, nil)
      ex.run
      described_class.instance_variable_set(:@singleton__instance__, nil)
    end

    describe 'clean' do
      let(:new_backtrace) do
        [
          "/home/app/web/app/controllers/api/v2/users_controller.rb:39:in `show'",
          "/ruby/2.5.0/gems/activesupport-4.2.11/lib/active_support/callbacks.rb:121:in `instance_exec'",
          "/ruby/2.5.0/gems/activesupport-4.2.11/lib/active_support/callbacks.rb:121:in `block in run_callbacks'",
          "/ruby/2.5.0/gems/newrelic_rpm-5.7.0.350/lib/new_relic/agent/instrumentation/middleware_tracing.rb:92:in
          `call'",
          "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/cookies.rb:560:in `call'",
          '/ruby/2.5.0/gems/newrelic_rpm-5.7.0.350/lib/new_relic/agent/instrumentation/middleware_tracing.rb' \
          ":92:in`call'",
          "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/callbacks.rb:29:in `block in call'",
          "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/callbacks.rb:27:in `call'",
          '/ruby/2.5.0/gems/newrelic_rpm-5.7.0.350/lib/new_relic/agent/instrumentation/middleware_tracing.rb' \
          ":92:in `call'",
          "/usr/local/rvm/rubies/ruby-2.7.6/lib/ruby/2.7.0/benchmark.rb:308:in `realtime'",
          '/ruby/2.5.0/gems/zipkin-tracer-0.47.3/lib/zipkin-tracer/rack/zipkin-tracer.rb:29' \
          ":in `block (3 levels) in call'",
          "/ruby/2.5.0/gems/zipkin-tracer-0.47.3/lib/zipkin-tracer/rack/zipkin-tracer.rb:51:in `trace!'",
          '/ruby/2.5.0/gems/zipkin-tracer-0.47.3/lib/zipkin-tracer/rack/zipkin-tracer.rb:29' \
          ":in `block (2 levels) incall'",
          "/ruby/2.5.0/gems/zipkin-tracer-0.47.3/lib/zipkin-tracer/zipkin_sender_base.rb:17:in `with_new_span'",
          "/ruby/2.5.0/gems/zipkin-tracer-0.47.3/lib/zipkin-tracer/rack/zipkin-tracer.rb:27:in `block in call'",
          "/ruby/2.5.0/gems/puma-5.3.2/lib/puma/configuration.rb:249:in `call'",
          "/usr/lib/ruby/vendor_ruby/phusion_passenger/rack/thread_handler_extension.rb:107:in `process_request'",
          "/ruby/2.5.0/gems/opentelemetry-api-1.0.1/lib/opentelemetry/trace/tracer.rb:29:in `block in in_span'",
          "/home/app/web/app/controllers/api/v2/users_controller.rb:39:in `show'",
          "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/callbacks.rb:29:in `block in call'",
          "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/callbacks.rb:27:in `call'",
          "/home/app/web/vendor/bundle/ruby/2.7.0/bin/rake:25:in `load'"
        ]
      end
      let(:new_backtrace_location) { new_backtrace.map { |bt| BacktraceLocation.new('', '', bt) } }

      before do
        allow(Gem).to receive(:path).and_return(['/ruby/2.5.0', '/home/app/web/vendor/bundle/ruby/2.7.0'])
        stub_const('RbConfig::CONFIG', { 'rubylibdir' => '/usr/local/rvm/rubies/ruby-2.7.6/lib/ruby/2.7.0' })
        stub_const('Rails', double(root: '/home/app/web'))
        stub_const('BacktraceLocation', Struct.new(:path, :lineno, :to_s)) # https://github.com/rails/rails/blob/v7.1.2/activesupport/lib/active_support/syntax_error_proxy.rb#L15
      end

      context 'Logging just an exception' do
        let(:active_support_exception_v6) do
          [
            "/app/controllers/api/v2/users_controller.rb:39:in `show'",
            "actionpack (4.2.11) lib/action_dispatch/middleware/cookies.rb:560:in `call'",
            "actionpack (4.2.11) lib/action_dispatch/middleware/callbacks.rb:29:in `block in call'",
            "actionpack (4.2.11) lib/action_dispatch/middleware/callbacks.rb:27:in `call'",
            "/app/controllers/api/v2/users_controller.rb:39:in `show'"
          ]
        end
        let(:active_support_exception_less_than_v6) do
          [
            "/app/controllers/api/v2/users_controller.rb:39:in `show'",
            "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/cookies.rb:560:in `call'",
            "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/callbacks.rb:29:in `block in call'",
            "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/callbacks.rb:27:in `call'",
            "/app/controllers/api/v2/users_controller.rb:39:in `show'"
          ]
        end
        let(:no_noise_backtrace) do
          ActiveSupport::VERSION::MAJOR < 6 ? active_support_exception_less_than_v6 : active_support_exception_v6
        end

        it 'does not log the lines matched with the denylist' do
          expect(instance.clean(new_backtrace)).to eq(no_noise_backtrace)
        end

        context 'with backtrace location' do
          it 'does not log the lines matched with the denylist' do
            expect(instance.clean(new_backtrace_location)).to eq(no_noise_backtrace)
          end
        end

        it 'logs all backtraces when ActiveSupport::BacktraceCleaner and Rails.root are not defined' do
          hide_const('ActiveSupport::BacktraceCleaner')
          hide_const('Rails')

          expect(instance.clean(new_backtrace)).to eq(new_backtrace)
        end

        it 'drops backtrace lines after the last line of Rails app logs' do
          hide_const('ActiveSupport::BacktraceCleaner')

          expect(instance.clean([
            "/ruby/2.5.0/gems/activesupport-4.2.11/lib/active_support/callbacks.rb:121:in `instance_exec'",
            "/home/app/web/app/controllers/api/v2/users_controller.rb:39:in `show'",
            "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/callbacks.rb:27:in `call'",
            "/home/app/web/vendor/bundle/ruby/2.7.0/bin/rake:25:in `load'"
          ])).to eq([
            "/ruby/2.5.0/gems/activesupport-4.2.11/lib/active_support/callbacks.rb:121:in `instance_exec'",
            "/app/controllers/api/v2/users_controller.rb:39:in `show'"
          ])
        end

        it 'returns an empty array when nil is passed' do
          expect(instance.clean(nil)).to eq([])
        end

        context 'with LOREKEEPER_DENYLIST env var' do
          before do
            allow(ENV).to receive(:key?).with('LOREKEEPER_DENYLIST').and_return(true)
            allow(ENV).to receive(:fetch).with('LOREKEEPER_DENYLIST').and_return(lorekeeper_denylist)
          end
          let(:lorekeeper_denylist) { 'newrelic_rpm, active_support/callbacks.rb, zipkin-tracer, puma' }
          let(:active_support_exception_v6) do
            [
              "/app/controllers/api/v2/users_controller.rb:39:in `show'",
              "actionpack (4.2.11) lib/action_dispatch/middleware/cookies.rb:560:in `call'",
              "actionpack (4.2.11) lib/action_dispatch/middleware/callbacks.rb:29:in `block in call'",
              "actionpack (4.2.11) lib/action_dispatch/middleware/callbacks.rb:27:in `call'",
              "/usr/lib/ruby/vendor_ruby/phusion_passenger/rack/thread_handler_extension.rb:107:in `process_request'",
              "opentelemetry-api (1.0.1) lib/opentelemetry/trace/tracer.rb:29:in `block in in_span'",
              "/app/controllers/api/v2/users_controller.rb:39:in `show'"
            ]
          end
          let(:active_support_exception_less_than_v6) do
            [
              "/app/controllers/api/v2/users_controller.rb:39:in `show'",
              "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/cookies.rb:560:in `call'",
              "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/callbacks.rb:29:in `block in call'",
              "/ruby/2.5.0/gems/actionpack-4.2.11/lib/action_dispatch/middleware/callbacks.rb:27:in `call'",
              "/usr/lib/ruby/vendor_ruby/phusion_passenger/rack/thread_handler_extension.rb:107:in `process_request'",
              "/ruby/2.5.0/gems/opentelemetry-api-1.0.1/lib/opentelemetry/trace/tracer.rb:29:in `block in in_span'",
              "/app/controllers/api/v2/users_controller.rb:39:in `show'"
            ]
          end

          it 'Does not log the lines matched with the denylist' do
            expect(instance.clean(new_backtrace)).to eq(no_noise_backtrace)
          end
        end
      end
    end
  end
end
