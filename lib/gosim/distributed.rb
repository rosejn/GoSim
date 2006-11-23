require 'drb'
require 'thread'
require 'monitor'

require 'semaphore'

module GoSim
  module Distributer
    def schedule_event
      event_id = ("handle_" + event_id.to_s).to_sym

    end

    def register_entity(sid, entity)

    end

    def run(end_time = MAX_INT)  

    end
  end

  class Server
    include Base
    include DRbUndumped

    def initialize num_clients, port
      @sim = Simulation.instance
      if @sim.num_entities > 0
        raise "Must start server before creating simulation entities!" 
      end

      @client_count = 0
      @num_clients = num_clients

      @client_queues = Array.new(num_clients)
      @client_queues.extend(MonitorMixin)
      @clients_ready = @client_queues.new_cond

      @port = port
      @tick_count = 0

      # extend to make the main simulation instance distributed.
      @sim.extend(MonitorMixin)
      @sim.extend(Distributer)

      #@thread = Thread.new { start_serving }
      DRb.start_service("druby://localhost:#{@port}", self)

      # Wait until all clients have registered before continuing with
      # simulation code.
      @client_queues.synchronize do
        @clients_ready.wait_until { @client_count == @num_clients }
      end
    end

    def register_client client
      @client_queues.synchronize do
        log "Registering a new client!"
        client = @client_count
        @client_count += 1

        @client_queues[client] = Queue.new

        @clients_ready.signal
      end
    end

    def tick_complete
      @tick_count += 1
    end

    def get_events(n)

    end

    def schedule_event(src, event)

    end
  end

  class Client
    def initialize(host, port)
      @host = host
      @port = port

      print "Connecting to server...\t"
      DRb.start_service()
      @server = DRbObject.new(nil, "druby://#{host}:#{port}")
      puts "connected..."
      
      print "Registering client...\t"
      @id = @server.register_client
      puts "registered, id = #{@id}"

    end
  end
end


