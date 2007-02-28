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
      @sim.schedule_event(:item, @sid, t * 10, t)
    end
  end

  def handle_item(t)
    @counter += 1
  end
end

NUM_EVENTS = 100000

sim = GoSim::Simulation::instance

Benchmark.bm do |stat|
  puts "Starting benchmark for #{NUM_EVENTS} events:\n"

  b = Benchmarker.new(NUM_EVENTS)
  stat.report { sim.run }

  puts "Benchmark complete after counting #{b.counter} events.\n"
end

