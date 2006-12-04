module GoSim
  module Net
    MEAN_LATENCY = 5

    GSNetworkPacket = Struct.new(:id, :src, :dest, :data)
    FailedPacket = Struct.new(:dest, :data)
    LivenessPacket = Struct.new(:alive)

    ERROR_NODE_FAILURE = 0

    class Topology < Entity
      include Singleton

      def initialize(mean_latency = MEAN_LATENCY)
        super()
        @mean_latency = mean_latency
        @node_status = {}

        GSL::Rng.env_setup
        @rand_gen = GSL::Rng.alloc("mt19937")

        @sim.add_observer(self)
      end

      # Called by simulation when a reset occurs
      def update
        log "Resetting topology..."
        reset
        log "topology now has sid=#{sid}"
      end

      def node_alive(addr, status)
        @node_status[addr] = status
      end

      def send_packet(id, src, receivers, packet)
        [*receivers].each do |receiver| 
          @sim.schedule_event(:gs_network_packet, 
                              @sid, 
                              @rand_gen.poisson(@mean_latency), 
                              GSNetworkPacket.new(id, src, receiver, packet)) 
        end
      end

      def handle_gs_network_packet(packet)
        if @node_status[packet.dest]
          @sim.schedule_event(packet.id, packet.dest, 0, packet.data)
        else
          @sim.schedule_event(:failed_packet, packet.src, 0, 
                              FailedPacket.new(packet.dest, packet.data))
        end
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
        @topo.node_alive(@addr, @alive)
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
        @topo.node_alive(@addr, @alive)
      end

      def alive?
        @alive
      end

      def alive=(status)
        @alive = status
        @topo.node_alive(@addr, @alive)
      end
      alias alive alive=

      def send_packet(id, receivers, pkt)
        @topo.send_packet(id, @sid, receivers, pkt)
      end

      # Implement this method to do something specific for your application.
      def handle_failed_packet(pkt)
        puts "Got a failed packet! (#{pkt.data.class})"
      end

    end
  end # module Net
end # module GoSim
