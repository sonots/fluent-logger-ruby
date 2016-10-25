require 'fluent/load'
require 'fluent/test'
require 'socket'
require 'plugin/out_test'
require 'stringio'

$log = Fluent::Log.new(StringIO.new) # XXX should remove $log from fluentd

class DummyFluentd
  def initialize
    output.emits.clear rescue nil
  end

  WAIT = ENV['WAIT'] ? ENV['WAIT'].to_f : 0.1

  def wait_transfer
    sleep WAIT
  end

  def port
    return @port if @port
    @port = 60001
    loop do
      begin
        TCPServer.open('localhost', @port).close
        break
      rescue Errno::EADDRINUSE
        @port += 1
      end
    end
    @port
  end

  def output
    sleep 0.0001 # next tick
    if Fluent::Engine.respond_to?(:match)
      Fluent::Engine.match('logger-test').output
    else
      Fluent::Engine.root_agent.event_router.match('logger-test')
    end
  end

  def queue
    queue = []
    output.emits.each {|tag, time, record|
      queue << [tag, record]
    }
    queue
  end

  def startup
    config = Fluent::Config.parse(<<EOF, '(logger-spec)', '(logger-spec-dir)', true)
<source>
  type forward
  port #{port}
</source>
<match logger-test.**>
  type test
</match>
EOF
    Fluent::Test.setup
    Fluent::Engine.run_configure(config)
    @coolio_default_loop = nil
    @thread = Thread.new {
      @coolio_default_loop = Coolio::Loop.default
      Fluent::Engine.run
    }
    wait_transfer
  end

  def shutdown
    @coolio_default_loop.stop
    Fluent::Engine.send :shutdown
    @thread.join
    @coolio_default_loop = @thread = nil
  end
end
