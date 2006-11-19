module GoSim
  module Net
    MEDIAN_LATENCY = 5

    GSNetworkPacket = Struct.new(:src, :dest, :data)
    FailedPacket = Struct.new(:dest, :data)
    LivenessPacket = Struct.new(:alive)

    ERROR_NODE_FAILURE = 0

    class Topology < Entity
      include Singleton

      def initialize(median_latency = MEDIAN_LATENCY)
        super()
        @median_latency = median_latency
        @node_status = {}
      end

      def node_alive(nid, status)
        @node_status[nid] = status
      end

      def send_packet(src, receivers, packet)
        [*receivers].each do |receiver| 
          @sim.schedule_event(@sid, @median_latency, GSNetworkPacket.new(src, receiver, packet)) 
        end
      end

      private

      def handle_gs_network_packet(packet)
        if @node_status[packet.dest]
          @sim.schedule_event(packet.dest, 0, packet.data)
        else
          @sim.schedule_event(packet.src, 0, FailedPacket.new(packet.dest, packet.data))
        end
      end
    end

    class Node < Entity
      attr_reader :nid, :neighbor_ids

      def initialize(nid = nil)
        super()
        @nid = nid || @sid
        @topo = Topology.instance
        @neighbor_ids = []
        @alive = true
        @topo.node_alive(@nid, @alive)
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
        @topo.node_alive(@nid, @alive)
      end

      def alive?
        @alive
      end

      def alive=(status)
        @alive = status
        @topo.node_alive(@nid, @alive)
      end
      alias alive alive=

      def send_packet(receivers, pkt)
        @topo.send_packet(@sid, receivers, pkt)
      end

      # Implement this method to do something specific for your application.
      def handle_failed_packet(pkt)
        puts "Got a failed packet! (#{pkt.data.class})"
      end

    end
  end # module Net
end # module GoSim
