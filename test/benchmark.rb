$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/..')

require 'rational'
require 'gosim'

require 'rubygems'
require 'benchmark'

class Benchmarker < GoSim::Entity
  attr_reader :counter

  def initialize(n)
    super()

    @counter = 0

    n.times do |t|
      @sim.schedule_event(:handle_item, @sid, t * 10, t)
    end
  end

  def handle_item(t)
    @counter += 1
  end
end

def run_benchmark(num_events)
  sim = GoSim::Simulation::instance

  puts "Starting benchmark for #{num_events} events:\n"

  Benchmark.bm do |stat|
    b = Benchmarker.new(num_events)
    stat.report { sim.run }
  end
end

NUM_EVENTS = 50000

# Without the C extension
#run_benchmark(NUM_EVENTS)

# With the C extension
require 'ext/guts/gosim_guts'
run_benchmark(NUM_EVENTS)


