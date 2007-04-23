module GoSim
  module RPC

    class RPCInvalidMethodError < Exception; end

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

      def initialize(uid, result = nil)
        @uid = uid
        @result = result
      end
    end

    class RPCErrorResponse < RPCResponse; end

    class RPCDeferred < Net::Deferred
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

  end  # RPC

  module Net
    class RPCNode < Net::Node
      def initialize 
        super

        @topo = Topology::instance
        @rpc_deferreds = {}

        @receive_aspects = []
        @send_aspects = []
      end

      def insert_receive_aspect(method = nil, &block)
        aspect = method || block
        @receive_aspects << aspect
      end

      def insert_send_aspect(method = nil, &block)
        aspect = method || block
        @send_aspects << aspect
      end

      def remove_deferred(uid)
        @rpc_deferreds.delete(uid)
      end

      # Send an rpc request that gets handled by a specific method on the receiver
      def rpc_request(src, dest, method, args)
        request = RPC::RPCRequest.new(src, dest, method, args) 

        deferred = RPC::RPCDeferred.new(request.uid)
        @rpc_deferreds[request.uid] = deferred

        request = @send_aspects.inject(request) do | x, aspect | 
          x = aspect.call(method, x) 
        end

        @sim.schedule_event(:handle_rpc_request, 
                            dest, 
                            rand(@topo.latency_mean) + @topo.latency_base,
                            [method, request])

        return deferred
      end

      # Dispatches an RPC request to a specific method, and return a result
      # unless the method returns nil.
      def handle_rpc_request(request)
        method = request[0]
        request = request[1]

        #puts "top of request"
        if alive?
          #puts "1 request...#{request.inspect}"
          #
          request = @receive_aspects.inject(request) do | x, aspect | 
            x = aspect.call(method, x) 
          end

          # If there is no response delete the deferred.
          # TODO: Maybe we want to signal something to the deferred here also?
          result = send(request.method, *request.args)

          response = RPC::RPCResponse.new(request.uid, result)
          response = @send_aspects.inject(response) do | x, aspect |
            x = aspect.call(method, x) 
          end

          @sim.schedule_event(:handle_rpc_response,
                              request.src, 
                              rand(@topo.latency_mean) + @topo.latency_base,
                              [method, response]) 
        else
          #puts "2 request..."
          response = RPC::RPCErrorResponse.new(request.uid, Failure.new(request))
          @sim.schedule_event(:handle_rpc_response,
                              request.src, 
                              rand(@topo.latency_mean) + @topo.latency_base,
                              [method, response]) 
        end
      end

      def handle_rpc_response(response)
        method = response[0]
        response = response[1]

        response = @receive_aspects.inject(response) do | x, aspect | 
          x = aspect.call(method, x) 
        end

        #puts "response...#{response}"
        if @rpc_deferreds.has_key?(response.uid)
          if response.class == RPC::RPCErrorResponse
            @rpc_deferreds[response.uid].errback(response.result)
          else
            @rpc_deferreds[response.uid].callback(response.result)
          end
          remove_deferred(response.uid)
        end
      end

      def handle_failed_rpc(method, data)
        log {"Got a failed rpc call: #{method}(#{data.join(', ')})"}
      end
    end # RPCNode

  end # Net
end # GoSim
