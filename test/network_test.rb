$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'gosim'

Packet = Struct.new(:seq_num)

class TestNode < GoSim::Net::Node
  attr_reader :failed_packets

  def initialize
    super
    @got_message = false
    @pkt_cache = []
    @failed_packets = 0
  end

  def handle_packet(pkt)
    @got_message = true

    unless @pkt_cache.index(pkt.seq_num)
      send_packet(@neighbor_ids, pkt) unless @neighbor_ids.empty?
      @pkt_cache << pkt.seq_num
    end
  end

  def got_message?
    @got_message
  end

  def handle_failed_packet(pkt)
    @failed_packets += 1
  end
end

class TestNetworkSimulation < Test::Unit::TestCase
  NUM_NODES = 10
  CONNECTIVITY = 4

  def setup
    @sim = GoSim::Simulation.instance
    @topo = GoSim::Net::Topology.instance
    
    @sim.log.level = Logger::INFO
    @sim.trace.level = Logger::INFO
  end

  def teardown
    @sim.reset
    @topo.reset
  end
  
  def test_linking
    nodes = {}
    NUM_NODES.times do
      n = TestNode.new
      nodes[n.sid] = n
    end 

    n = TestNode.new
    n.link(nodes.keys)
    assert_equal(NUM_NODES, n.neighbor_ids.size)

    n = TestNode.new
    n.link(nodes[0])
    assert_equal(1, n.neighbor_ids.size)
    n.link(nodes[1])
    assert_equal(2, n.neighbor_ids.size)
  end

  def test_flood
    nodes = {}
    NUM_NODES.times do
      n = TestNode.new
      nodes[n.sid] = n
    end 

    # Seed the random generator so it's the same each time.
    srand(1234)

    nodes.each do |sid, node|
      (rand(CONNECTIVITY) + 1).times do
        neighbor = nodes.keys[rand(NUM_NODES)]
        node.link(neighbor) unless neighbor == sid
      end
    end

    @sim.schedule_event(nodes.keys[0], 0, Packet.new(1))
    @sim.run

    nodes.values.each { |node| assert(node.got_message?) }
  end

  def test_liveness_and_failure
    nodes = {}
    node_a = TestNode.new
    node_b = TestNode.new

    node_a.link(node_b.sid)

    4.times {|i| @sim.schedule_event(node_a.sid, 2 * i, Packet.new(i)) }
    @sim.schedule_event(node_b.sid, 3 + GoSim::Net::MEDIAN_LATENCY, 
                        GoSim::Net::LivenessPacket.new(false))
    @sim.run

    assert_equal(2, node_a.failed_packets)
  end
end

