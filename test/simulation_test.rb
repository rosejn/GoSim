$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'gosim'

Item = Struct.new(:name, :handler)

class Producer < GoSim::Entity
  def initialize(neighbor, num_items)
    super()
    @neighbor = neighbor 

    # Schedule a bunch of new product events.
    num_items.times do |t| 
      @sim.schedule_event(@sid, t * 10, Item.new("foo", :receive)) 
    end

    @dataset = GoSim::DataSet.new(:producer, "test/output")
  end

  def handle_item(event)
    @sim.schedule_event(@neighbor, 5, event)
    @dataset.log(@sid, event.name)
  end
end

class Consumer < GoSim::Entity
  attr_reader :received

  def initialize
    super()
    @received = 0
  end

  def handle_item(event)
    @received += 1
  end
end

class TimerOuter < GoSim::Entity
  TIMEOUT_TIME = 10

  attr_reader :timer_count

  def initialize
    super()
    @timer_count = 0
    set_timeout(TIMEOUT_TIME, true) do |timeout|
      @timer_count += 1 
      timeout.cancel if @timer_count == 5
    end
  end
end

class TestSimulation < Test::Unit::TestCase
  def setup
    @sim = GoSim::Simulation.reset

    # turn down logging so we don't see debug messages during unit testing
    @sim.trace_log = nil
  end

  def test_logging
    @sim.trace.level = Logger::FATAL
    @sim.log.level = Logger::FATAL
    assert_raise(TypeError, "trace_log method not raising correct exception") do
      @sim.trace_log(123)
    end
  end

  def test_scheduler
    consumer = Consumer.new
    producer = Producer.new(consumer.sid, 10)
    assert_equal(10, @sim.queue_size, "Schedule event not correctly adding to queue.")

    @sim.run
    assert_equal(10, consumer.received)
  end

  def test_data_set
    # Test the regular data logging
    file = File.expand_path(File.join(File.dirname(__FILE__), "output", "producer"))
    File.delete(file) if File.exists?(file)

    consumer = Consumer.new
    producer = Producer.new(consumer.sid, 2)

    @sim.run
    assert_equal("0, 1, foo\n10, 1, foo\n", IO::read(file))

    # Now try with an attached handler instead
    @sim.reset
    consumer = Consumer.new
    producer = Producer.new(consumer.sid, 5)

    count = 0
    GoSim::DataSet.add_handler(:producer) { count += 1 }
    @sim.run
    assert_equal(5, count)
  end

  def test_timeouts
    #@sim.log.level = Logger::DEBUG
    sim_timer = TimerOuter.new
    @sim.run
    assert_equal(5, sim_timer.timer_count)
  end

  def test_sim_run
    sim_timer = TimerOuter.new
    @sim.run(3 * TimerOuter::TIMEOUT_TIME)
    assert_equal(3, sim_timer.timer_count)
  end
end
