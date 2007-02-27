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
        @nodes[addr]
      end

      # Simple send packet that is always handled by Node#recv_packet
      def send_packet(src, receivers, packet)
        [*receivers].each do |receiver| 
          @sim.schedule_event(:handle_packet, 
                              @sid, 
                              rand(@mean_latency) + LATENCY_DEV,
                              GSNetworkPacket.new(id, src, receiver, packet)) 
        end
      end

      def recv_packet(packet)
        if @nodes[packet.dest].alive?
          @sim.schedule_event(packet.id, packet.dest, 0, packet.data)
        else
          @sim.schedule_event(:handle_failed_packet, packet.src, 0, 
                              FailedPacket.new(packet.dest, packet.data))
        end
      end

      # An rpc send that gets handled by a specific method on the receiver
      def send_rpc_packet(id, src, dest, args)
        @sim.schedule_event(:recv_rpc_packet, 
                            @sid, 
                            rand(@mean_latency) + LATENCY_DEV,
                            GSNetworkPacket.new(id, src, dest, args)) 
      end

      def recv_rpc_packet(packet)
        if @nodes[packet.dest].alive?
          @nodes[packet.dest].send(packet.id, *packet.data)
        else
          @nodes[packet.src].send(:handle_failed_rpc, packet.id, packet.data)
        end
      end

    end

    class RPCInvalidMethodError < Exception; end

    class Peer
      def initialize(local_node, remote_node)
        @local_node = local_node
        @remote_node = remote_node

        @topo = Topology.instance
      end

      def addr
        @remote_node.addr
      end

      def method_missing(method, *args)
        raise RPCInvalidMethodError.new("#{method} not available on target node!") unless @remote_node.respond_to?(method)

        @topo.send_rpc_packet(method, @local_node.addr, @remote_node.addr, args) 
      end
    end

    class Node < Entity
      attr_reader :addr 

      def initialize()
        super()
        @addr = @sid
        @topo = Topology.instance
        @alive = true

        @topo.register_node(self)
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
        log "default recv_packet handler..."
      end

      def get_peer(addr)
        Peer.new(self, @topo.get_node(addr))
      end

      # Implement this method to do something specific for your application.
      def handle_failed_packet(pkt)
        log "Got a failed packet! (#{pkt.data.class})"
      end

      def handle_failed_rpc(method, data)
        log "Got a failed rpc call: #{method}(#{data.join(', ')})"
      end
    end
  end # module Net
end # module GoSim
