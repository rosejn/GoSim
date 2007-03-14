module GoSim
  class Entity 
    include Base

    attr_reader :sid

    @@sid_counter = 0
    
    # Used internally by Entity objects that require a unique simulation ID.
    def Entity.next_sid
      @@sid_counter += 1
      @@sid_counter - 1
    end

    # Reset the entity ID counter, mostly here for easy unit testability.
    def Entity.reset
      @@sid_counter = 0
    end

    # Create a new simulation Entity.  This will typically be run when super()
    # is called from a child class.
    def initialize
      @sim = Simulation.instance
      reset
    end

    # Reset an Entity so that it gets a new simulation ID and
    # re-registers itself.  Typically just for unit testing.
    def reset
      @sid = Entity.next_sid
      @sim.register_entity(@sid, self)
      self
    end

    # Set a block of code to run after wait_time units of time.  If the
    # is_periodic flag is set it will continue to run every wait_time units.
    def set_timeout(wait_time, is_periodic = false, &block)
      SimTimeout.new(wait_time, is_periodic, block)
    end

    # Override the default inspect so entities with lots of state don't fill
    # the screen during debug.  Implement your own inspect method to print
    # useful information about your Entity.
    def inspect
      "<GoSim::Entity sid=#{@sid}>"
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
      @sim.schedule_event(:handle_timeout, @sid, @time, self)
    end
    alias start reset

    def cancel
      @active = false
    end
    alias stop cancel

    def start
      @active = true
      setup_timer
    end

    def handle_timeout(timeout)
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

    attr_reader :trace, :time, :running

    class << self
      def run(end_time = 999999999)
        Simulation.instance.run(end_time)
      end

      def reset
        GoSim::Data::DataSetWriter.instance.close
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
      #GC.disable

      reset
    end

    def reset
      @time = 0
      @end_time = 1000
      @running = false
      
      reset_event_queue

      @entities = {}
      @handlers = {}

      Entity.reset

      changed
      log "notifying #{count_observers} observers"
      notify_observers()

      self
    end

    if not method_defined?(:reset_event_queue)
      def reset_event_queue
        @event_queue = PQueue.new(proc {|x,y| x.time < y.time})
      end

      def queue_size
        @event_queue.size
      end
    end

    def register_entity(sid, entity)
      @entities[sid] = entity
      @handlers[sid] = {}
    end

    def add_handler(sid, event_id, &block)
      @handlers[sid][event_id] = block
    end

    def num_entities
      @entities.size
    end

    def inspect
      "<GoSim::Simulation - time=#{@time} entities.size=#{@entities.size}>"
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
    if not method_defined?(:schedule_event)
      def schedule_event(event_id, dest_sid, time, data)
        @event_queue.push(Event.new(event_id, dest_sid, @time + time, data))
      end
    end

    if not method_defined?(:run_main_loop)
      def run_main_loop(end_time)
        while(@running and (cur_event = @event_queue.top) and (cur_event.time <= end_time))
          @event_queue.pop
          @time = last_time = cur_event.time
          @entities[cur_event.dest_id].send(cur_event.event_id, cur_event.data) 
        end
      end
    end

    def run(end_time = 2**30) 
      return if @running   # Disallow after starting once
      @running = true

      #log ("Running simulation until: #{end_time}")
      begin
        run_main_loop(end_time)
      rescue Exception => e
        error "GoSim error occurred in main event loop!"
        puts "Generated Exception: #{e}"
        puts e.backtrace.join("\n")
        stop
      end

      @running = false
      
      # Do this so we are at the correct time even if no events fired.
      @time = end_time if @time < end_time

      # Make sure to write out all the data files when simulation finishes.
      GoSim::Data::DataSetWriter.instance.flush_all
    end

    def stop
      @running = false
    end

  end

end

