$:.unshift(File.dirname(__FILE__) + '/../lib')

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
      @sim.schedule_event(:handle_item, @sid, t * 10 + 1, t)
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

num_events = ARGV.first.to_i || 1000000

run_benchmark(num_events)
