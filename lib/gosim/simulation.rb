#require 'rubygems'
#require 'breakpoint'

module GoSim
  class SimTimeout
    attr_reader :time, :is_periodic, :active

    def initialize(sid, time, is_periodic, block)
      @sim = GoSim::Simulation.instance
      @sid = sid
      @time = time
      @is_periodic = is_periodic
      @block = block
      @active = true
      reset
    end

    def reset 
      @active = true
      @sim.schedule_event(@sid, @time, self)
      @sim.log.debug "Timeout started for #{@sid} in #{@time} units"
    end
    alias start reset

    def cancel
      @active = false
      @sim.log.debug "Timeout stopped for #{@sid}"
    end
    alias stop cancel

    def run
      puts "#{@sid}: running timeout"
      # Test twice in case the timeout was canceled in the block.
      ret = @block.call(self) if @active
      reset if @active and @is_periodic and ret
    end
  end

  class Entity 
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
      SimTimeout.new(@sid, time, is_periodic, block)
      puts "#{@sid}: Timeout set for #{time}"
    end

    private

    def handle_sim_timeout(t)
      t.run 
    end
  end

  Event = Struct.new(:dest_id, :time, :data)

  class Simulation
    include Singleton

    attr_reader :trace, :time, :log

    class << self
      def run(end_time = 999999999)
        Simulation.instance.run(end_time)
      end

      def reset
        Simulation.instance.reset
      end
    end

    def initialize
      @log = Logger.new(STDERR)
      @trace = Logger.new(STDOUT)
      @log.level = Logger::ERROR

      reset
    end

    def reset
      @time = 0
      @end_time = 1000
      @running = false
      @event_queue = PQueue.new(proc {|x,y| x.time < y.time})
      @entities = {}

      Entity.reset

      self
    end

    def register_entity(sid, entity)
      @entities[sid] = entity
    end

    def queue_size
      @event_queue.size
    end

    def trace_log(device)
      begin
        @trace = Logger.new(device)
      rescue Exception => exp
        @log.error "Must pass a filename (String) or IO object as the trace device:\n  " + exp 
        raise
      end
    end
    alias trace_log= trace_log

    # Schedule a new event by putting it into the event queue
    def schedule_event(dest_id, time, data)
      @log.debug "Scheduling new #{data.class} event: #{@time + time}"
      @event_queue.push(Event.new(dest_id, @time + time, data))
    end

    def run(end_time = 999999999) 
      return if @running   # Disallow after starting once
      @running = true

      @log.debug("Running simulation until: #{end_time}")
      
      while(@running and (cur_event = @event_queue.pop) and (cur_event.time <= end_time))
        @log.debug("Handling %s event at %d\n" % [cur_event.data.class, cur_event.time])

        @time = last_time = cur_event.time

        # Figure out the method name
        class_reg = /[::]?(\w*)$/
        class_name = class_reg.match(cur_event.data.class.to_s)[1]
        method = 'handle_' + class_name.reverse.
          scan(%r/[A-Z]+|[^A-Z]*[A-Z]+?/).reverse.
          map{|word| word.reverse.downcase }.join('_')

        @entities[cur_event.dest_id].send(method.to_sym, cur_event.data) 
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

