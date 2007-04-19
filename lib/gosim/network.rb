module GoSim
  module Net
    LATENCY_MEAN = 150
    LATENCY_BASE = 30

    GSNetworkPacket = Struct.new(:id, :src, :dest, :data)
    FailedPacket = Struct.new(:dest, :data)

    ERROR_NODE_FAILURE = 0

    class Topology < Entity
      include Singleton

        attr_reader :latency_mean, :latency_base

      def initialize()
        super()

        @sim.add_observer(self)
        @nodes = {}
#        @rpc_deferreds = {}
        set_latency()
      end

      def set_latency(latency_mean = LATENCY_MEAN, latency_base = LATENCY_BASE)
        @latency_mean = latency_mean
        @latency_base = latency_base
      end

      # Called by simulation when a reset occurs
      def update
        log {"Resetting Topology..."}
        reset
        @nodes = {}
        log {"Topology now has sid #{sid}"}
      end

      def register_node(node)
        @nodes[node.addr] = node
      end

      def get_node(addr)
        @nodes[addr]
      end
#      private :get_node

      # Simple send packet that is always handled by Node#recv_packet
      def send_packet(src, receivers, packet)
        [*receivers].each do |receiver| 
          @sim.schedule_event(:handle_packet, 
                              @sid, 
                              rand(@latency_mean) + @latency_base,
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
    end

    class Peer
      attr_reader :addr

      def initialize(local_node, remote_addr)
        @topo = Topology.instance

        @local_node = local_node
        @remote_node = @topo.get_node(remote_addr)
        if @remote_node
          @addr = @remote_node.addr
        else
          @addr = nil
        end

        @default_cb = nil
        @default_eb = nil
      end

      def method_missing(method, *args)
        raise RPC::RPCInvalidMethodError.new("#{method} not available on target node!") unless @remote_node.respond_to?(method)

        deferred = @local_node.rpc_request(@local_node.addr, @remote_node.addr, method, args) 
        deferred.default_callback(@default_cb) if @default_cb
        deferred.default_errback(@default_eb) if @default_eb

        return deferred
      end

      def add_default_callback(callback = nil, &block)
        @default_cb = callback || block
      end

      def add_default_errback(errback = nil, &block)
        @default_eb = errback || block
      end
    end

    class Node < Entity
      attr_reader :addr 

      def initialize
        super
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

      def alive(status)
        @alive = status
      end

      def send_packet(receivers, pkt)
        @topo.send_packet(id, @sid, receivers, pkt)
      end

      # Override this in your subclass to do custom demuxing.
      def recv_packet(pkt)
        log {"default recv_packet handler..."}
      end

      # Implement this method to do something specific for your application.
      def handle_failed_packet(pkt)
        log {"Got a failed packet! (#{pkt.data.class})"}
      end

    end
  end # module Net
end # module GoSim
