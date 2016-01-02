require 'benchmark'
require 'tempfile'
require 'securerandom'
require 'benchmark/ips'
require 'byebug'
require 'rbtrace'

$LOAD_PATH.unshift(File.expand_path("../lib", __FILE__))
$LOAD_PATH.uniq!

require 'lorekeeper'
require 'logger'

def create_logger
  logfile = Tempfile.new('my_test_log.log')
  extra_fields = {
    machine:"Verylongmachinenametobe-Pro.local",
    component: 'Gilean', version: '0.1.1', trace_id: SecureRandom.hex(16), span_id: SecureRandom.hex(16), parent_span_id: SecureRandom.hex(16)
  }
  log = Lorekeeper::JSONLogger.new(logfile)
  log.add_fields(extra_fields)
  log
end

def create_simple_logger
  logfile = Tempfile.new('my_test_log.log')
  ::Logger.new(logfile.path)
end

# This task is used to help development of Lorekeeper. Use together with rbtrace
desc "Runs the code once, sleeping to allow you to attach to it with rbtrace"
task :run_once do
  contents = 'This is a test, this is only a test. Do not worry about these contents.'
  long_contents = contents * 100

  log = create_logger
  sleep(10)
  log.error(long_contents)
end


# This task is used to help development of Lorekeeer. Make sure it is fast enough for your app.
desc "Runs benchmarks for the library."
task :benchmark do

  contents = 'This is a test, this is only a test. Do not worry about these contents.'
  long_contents = contents * 100

  log = create_logger
  simple_log = create_simple_logger

  Benchmark.ips do |bm|
    bm.report("short content") { log.error(contents) }
    bm.report("Logger short content")  { simple_log.info(contents) }
    bm.report("long content")  { log.info(long_contents) }
    bm.report("Logger long content")   { simple_log.info(long_contents) }
    bm.compare!
  end

  puts "i/s means the number of log messages written into a file per second"

end

