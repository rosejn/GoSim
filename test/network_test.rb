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
    @neighbors = {}
  end

  def add_neighbor(addr)
    @neighbors[addr] = GoSim::Net::Peer.new(self, addr)
  end

  def start_flood(pkt)
    forward_packet(pkt)
  end

  def handle_packet(pkt)
    @got_message = true
    forward_packet(pkt)
  end

  def forward_packet(pkt)
    unless @pkt_cache.index(pkt.seq_num)
      @neighbors.values.each do |n| 
        d = n.handle_packet(pkt)
        d.add_errback {|f| @failed_packets += 1}
      end

      @pkt_cache << pkt.seq_num
    end
  end

  def got_message?
    @got_message
  end
end

class TestNetworkSimulation < Test::Unit::TestCase
  NUM_NODES = 10
  CONNECTIVITY = 4

  def setup
    @sim = GoSim::Simulation.instance
    @topo = GoSim::Net::Topology.instance
    
    @sim.quiet
  end

  def teardown
    @sim.reset
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
        n_addr = nodes.keys[rand(NUM_NODES)]
        node.add_neighbor(n_addr) unless n_addr == node.addr
      end
    end

    @sim.schedule_event(:start_flood, nodes.keys[0], 0, Packet.new(1))
    @sim.run

    nodes.values.each { |node| assert(node.got_message?, "#{node.addr}->#{node.got_message?}") }
  end

  def test_liveness_and_failure
    node_a = TestNode.new
    node_b = TestNode.new

    node_a.add_neighbor(node_b.addr)

    10.times {|i| @sim.schedule_event(:handle_packet, node_a.sid, i*1000, Packet.new(i)) }
    @sim.schedule_event(:alive, node_b.sid, 5000, false)
    @sim.run

    assert_equal(5, node_a.failed_packets)
  end

  def test_net_deferred
    node_a = TestNode.new
    node_b = TestNode.new

  end
end

