module GoSim
  class Entity 
    include Base

    attr_reader :sid

    @@sid_counter = 0
    
    def Entity.next_sid
      @@sid_counter += 1
      @@sid_counter - 1
    end

    def Entity.reset
      @@sid_counter = 0
    end

    def initialize
      @sim = Simulation.instance
      reset
    end

    def reset
      @sid = Entity.next_sid
      @sim.register_entity(@sid, self)
      self
    end

    def set_timeout(time, is_periodic = false, &block)
      SimTimeout.new(time, is_periodic, block)
      #log "#{@sid}: Timeout set for #{time}"
    end

    private

    def handle_sim_timeout(t)
      t.run 
    end
  end

  class SimTimeout < Entity
    include Base

    attr_reader :time, :is_periodic, :active

    def initialize(time, is_periodic, block)
      super()

      @time = time
      @is_periodic = is_periodic
      @block = block
      @active = true

      setup_timer
    end

    def setup_timer
      @active = true
      @sim.schedule_event(:timeout, @sid, @time, self)
      #log "Timeout started for #{@sid} in #{@time} units"
    end
    alias start reset

    def cancel
      @active = false
      #log "Timeout stopped for #{@sid}"
    end
    alias stop cancel

    def handle_timeout(timeout)
      #log "sid -> #{@sid} running timeout"
      # Test twice in case the timeout was canceled in the block.
      @block.call(self) if @active
      setup_timer if @active and @is_periodic
    end

    def inspect
      sprintf("#<GoSim::SimTimeout: @time=%d, @is_periodic=%s, @active=%s>",
            @time, @is_periodic, @active)
    end
  end

  Event = Struct.new(:event_id, :dest_id, :time, :data)

  class Simulation
    include Base
    include Singleton
    include Observable

    PORT_NUMBER = 8765

    attr_reader :trace, :time

    class << self
      def run(end_time = 999999999)
        Simulation.instance.run(end_time)
      end

      def reset
        Simulation.instance.reset
      end

      def start_server(num_clients, port = PORT_NUMBER)
        require 'gosim/distributed'

        Server.new(num_clients, port)
      end

      def start_client(ip, port = PORT_NUMBER)
        require 'gosim/distributed'

        Client.new(ip, port)
      end
    end

    def initialize
      @trace = Logger.new(STDOUT)

      reset
    end

    def reset
      @time = 0
      @end_time = 1000
      @running = false
      @event_queue = PQueue.new(proc {|x,y| x.time < y.time})
      @entities = {}
      @handlers = {}

      Entity.reset

      changed
      log "notifying #{count_observers} observers"
      notify_observers()

      self
    end

    def register_entity(sid, entity)
      @entities[sid] = entity
      @handlers[sid] = {}
    end

    def add_handler(sid, event_id, &block)
      @handlers[sid][event_id] = block
    end

    def queue_size
      @event_queue.size
    end

    def num_entities
      @entities.size
    end

    def trace_log(device)
      begin
        @trace = Logger.new(device)
      rescue Exception => exp
        @@log.error "Must pass a filename (String) or IO object as the trace device:\n  " + exp 
        raise
      end
    end
    alias trace_log= trace_log

    # Schedule a new event by putting it into the event queue
    def schedule_event(event_id, dest_id, time, data)
      #log "#{dest_id} is scheduling #{event_id} for #{@time + time}"
      event_id = ("handle_" + event_id.to_s).to_sym
      @event_queue.push(Event.new(event_id, dest_id, @time + time, data))
    end

    def run(end_time = MAX_INT) 
      return if @running   # Disallow after starting once
      @running = true

      #log ("Running simulation until: #{end_time}")
      begin
      while(@running and (cur_event = @event_queue.pop) and (cur_event.time <= end_time))
        #log ("Handling %s event at %d\n" % [cur_event.data.class, cur_event.time])

        @time = last_time = cur_event.time

        @entities[cur_event.dest_id].send(cur_event.event_id, cur_event.data) 
      end
      rescue Exception => e
        error "error occurred sending:\n#{cur_event.data.inspect}\nto destination: #{cur_event.dest_id}.#{cur_event.event_id}"
        puts e
        print e.backtrace.join("\n")
        stop
      end

      @running = false
      @time = last_time || end_time # Do this so we are at the correct time even if no events fired.

      # Make sure to write out all the data files when simulation finishes.
      DataSet.flush_all
    end

    def stop
      @running = false
    end

  end

end

