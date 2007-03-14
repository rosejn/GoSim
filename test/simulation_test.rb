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
      @sim.schedule_event(:new_item, @sid, t * 10, Item.new("foo", :receive)) 
    end

    dir_name = File.join(File.dirname(__FILE__), "output")
    Dir.mkdir(dir_name) unless File.exists?(dir_name)
    @dataset = GoSim::Data::DataSet.new(:producer)
    GoSim::Data::DataSetWriter.instance.set_output_file(dir_name + "/trace.gz")
  end

  def new_item(event)
    log {"got new #{event.class} event"}
    @sim.schedule_event(:new_item, @neighbor, 5, event)
    @dataset.log(@sid, event.name)
  end
end

class Consumer < GoSim::Entity
  attr_reader :received

  def initialize
    super()
    @received = 0
  end

  def new_item(event)
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
    @sim = GoSim::Simulation.instance
    @sim.quiet

    # turn down logging so we don't see debug messages during unit testing
    @sim.trace_log = nil
  end

  def teardown
    GoSim::Simulation.reset
  end

  def test_logging
    @sim.trace.level = Logger::FATAL
    @sim.quiet 
    assert_raise(TypeError, "trace_log method not raising correct exception") do
      @sim.trace_log(123)
    end
  end

  def test_scheduler
    num_items = 10000
    consumer = Consumer.new
    producer = Producer.new(consumer.sid, num_items)
    assert_equal(num_items, @sim.queue_size, "Schedule event not correctly adding to queue.")

    @sim.run
    assert_equal(num_items, consumer.received)
  end

  def test_single_step
    num_items = 10
    consumer = Consumer.new
    producer = Producer.new(consumer.sid, num_items)

    (num_items * 10).times {|i| @sim.run(i) }
    assert_equal(10, consumer.received)
  end

  def test_data_set
    # Test the regular data logging
    file = File.expand_path(File.join(File.dirname(__FILE__), "output", "trace.gz"))
    File.delete(file) if File.exists?(file)

    consumer = Consumer.new
    producer = Producer.new(consumer.sid, 2)

    @sim.run

    ds = GoSim::EventReader.new(file)
    event = ds.next
    assert_equal(:time, event[0])

    # Now try with an attached handler instead
    @sim.reset
    consumer = Consumer.new
    producer = Producer.new(consumer.sid, 5)

    count = 0
    GoSim::Data::DataSet.add_handler(:producer) { count += 1 }
    @sim.run
    assert_equal(5, count)
  end

  def test_timeouts
    #@sim.verbose
    sim_timer = TimerOuter.new
    @sim.run
    assert_equal(5, sim_timer.timer_count)
  end

  def test_sim_run
    #@sim.verbose
    sim_timer = TimerOuter.new
    @sim.run(3 * TimerOuter::TIMEOUT_TIME)
    assert_equal(3, sim_timer.timer_count)

  end
end
