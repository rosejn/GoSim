module GoSim
  module Net
    LATENCY_MEAN = 100
    LATENCY_DEV  = 50

    GSNetworkPacket = Struct.new(:id, :src, :dest, :data)
    FailedPacket = Struct.new(:dest, :data)

    ERROR_NODE_FAILURE = 0

    class RPCRequest
      attr_reader :uid, :src, :dest, :method, :args

      @@rpc_counter = 0

      def RPCRequest.next_uid
        @@rpc_counter += 1
      end

      def initialize(src, dest, method, args)
        @src = src
        @dest = dest
        @method = method
        @args = args

        @uid = RPCRequest.next_uid
      end
    end

    class RPCResponse
      attr_reader :uid, :result

      def initialize(uid, result)
        @uid = uid
        @result = result
      end
    end

    # Add a no-return method to Deferred so it can clear state for methods
    # without return values.
    class RPCDeferred < Deferred
      def initialize(uid = nil)
        @uid = uid

        super()
      end

      def default_callback(callback = nil, &block)
        callback = callback || block

        if callback
          raise NotCallableError unless is_callable?(callback)
          @default_cb = callback
        end
      end

      def default_errback(errback = nil, &block)
        errback = errback || block

        if errback
          raise NoterrableError unless is_callable?(errback)
          @default_eb = errback
        end
      end

      def run_callbacks
        # Check for defaults.  Call the appropriate one only if no calls have
        # been provided
        if is_failure?(@result) 
          @default_eb.call(@result) if !has_errbacks? && @default_eb
        elsif !has_callbacks? && @default_cb
          @default_cb.call(@result)
        end

        super()
      end

      def no_return
        Topology.instance.remove_deferred(@uid)
      end
    end

    class Topology < Entity
      include Singleton

      def initialize()
        super()

        @sim.add_observer(self)
        @nodes = {}
        @rpc_deferreds = {}
      end

      def set_latency(latency_mean = LATENCY_MEAN, latency_dev = LATENCY_DEV)
        @latency_mean = latency_mean
        @latency_dev = latency_dev
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

      def remove_deferred(uid)
        @rpc_deferreds.delete(uid)
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

      # Send an rpc request that gets handled by a specific method on the receiver
      def rpc_request(src, dest, method, args)
        request = RPCRequest.new(src, dest, method, args) 
        @sim.schedule_event(:handle_rpc_request, 
                            @sid, 
                            rand(@mean_latency) + LATENCY_DEV,
                            request)

        deferred = RPCDeferred.new(request.uid)
        @rpc_deferreds[request.uid] = deferred

        return deferred
      end

      # Dispatches an RPC request to a specific method, and return a result
      # unless the method returns nil.
      def handle_rpc_request(request)
        #puts "top of request"
        if @nodes[request.dest].alive?
        #puts "1 request...#{request.inspect}"

          # If there is no response delete the deferred.
          # TODO: Maybe we want to signal something to the deferred here also?
          result = @nodes[request.dest].send(request.method, *request.args)

          @sim.schedule_event(:handle_rpc_response,
                              @sid, 
                              rand(@mean_latency) + LATENCY_DEV,
                              RPCResponse.new(request.uid, result)) 
        else
        #puts "2 request..."
          if @rpc_deferreds.has_key?(request.uid)
            @rpc_deferreds[request.uid].errback(Failure.new(request))
          end
        end
      end

      def handle_rpc_response(response)
        #puts "response...#{response}"
        if @rpc_deferreds.has_key?(response.uid)
          @rpc_deferreds[response.uid].callback(response.result)
        end
      end
    end

    class RPCInvalidMethodError < Exception; end

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
        raise RPCInvalidMethodError.new("#{method} not available on target node!") unless @remote_node.respond_to?(method)

        deferred = @topo.rpc_request(@local_node.addr, @remote_node.addr, method, args) 
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

      def handle_failed_rpc(method, data)
        log {"Got a failed rpc call: #{method}(#{data.join(', ')})"}
      end
    end
  end # module Net
end # module GoSim
