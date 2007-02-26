module GoSim
  module Net
    LATENCY_MEAN = 100
    LATENCY_DEV  = 50

    GSNetworkPacket = Struct.new(:id, :src, :dest, :data)
    FailedPacket = Struct.new(:dest, :data)
    LivenessPacket = Struct.new(:alive)

    ERROR_NODE_FAILURE = 0

    class Topology < Entity
      include Singleton

      def initialize()
        super()

        @sim.add_observer(self)
        @nodes = {}
      end

      def set_latency(latency_mean = LATENCY_MEAN, latency_dev = LATENCY_DEV)
        @latency_mean = latency_mean
        @latency_dev = latency_dev
      end

      # Called by simulation when a reset occurs
      def update
        log "Resetting Topology..."
        reset
        @nodes = {}
        log "Topology now has sid #{sid}"
      end

      def register_node(node)
        @nodes[node.addr] = node
      end

      def get_node(addr)
        @nodes[node.addr]
      end

      # Simple send packet that is always handled by Node#recv_packet
      def send_packet(src, receivers, packet)
        [*receivers].each do |receiver| 
          send_rpc_packet(:recv_packet, src, receiver, packet)
        end
      end

      # An rpc send that gets handled by a specific method on the receiver
      def send_rpc_packet(id, src, receiver, packet)
        @sim.schedule_event(:handle_gs_network_packet, 
                            @sid, 
                            rand(@mean_latency) + LATENCY_DEV,
                            GSNetworkPacket.new(id, src, receiver, packet)) 
      end

      def handle_gs_network_packet(packet)
        if @nodes[packet.dest].alive?
          @sim.schedule_event(packet.id, packet.dest, 0, packet.data)
        else
          @sim.schedule_event(:handle_failed_packet, packet.src, 0, 
                              FailedPacket.new(packet.dest, packet.data))
        end
      end
    end

    class RPCInvalidMethodError < Exception; end

    class Peer
      def initialize(local_node, remote_node)
        @local_node = local_node
        @remote_node = remote_node
      end

      def method_missing(method, *args)
        raise RPCInvalidMethodError unless @node.respond_to?(method)

        @topo.send_rpc_packet(@local_node.addr, @remote_node.addr, args) 
      end
    end

    class Node < Entity
      attr_reader :addr, :neighbor_ids

      def initialize()
        super()
        @addr = @sid
        @topo = Topology.instance
        @neighbor_ids = []
        @alive = true

        @topo.register_node(self)
      end

      def link(neighbors)
        if neighbors.respond_to?(:to_ary)
          @neighbor_ids += neighbors 
        else
          @neighbor_ids << neighbors 
        end
      end

      def handle_liveness_packet(pkt)
        @alive = pkt.alive
      end

      def alive?
        @alive
      end

      def alive=(status)
        @alive = status
      end

      def send_packet(receivers, pkt)
        @topo.send_packet(id, @sid, receivers, pkt)
      end

      # Override this in your subclass to do custom demuxing.
      def recv_packet(pkt)
      end

      def rpc_connect(addr)

      end

      # Implement this method to do something specific for your application.
      def handle_failed_packet(pkt)
        puts "Got a failed packet! (#{pkt.data.class})"
      end

    end
  end # module Net
end # module GoSim
