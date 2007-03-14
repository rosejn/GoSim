module GoSim
  module Data

    VIEW_MOD = :view_module
    TIME_MOD = :time

    class DataSetReader < GoSim::Entity
      def initialize(trace)
        super()
        @tracefile = trace
        reopen()
        @sim = Simulation::instance
        @sim.add_observer(self)
        @requires_done = false
      end

      def update
        reset
        reopen
      end

      def reopen
        @trace = EventReader.new(@tracefile)
        e = @trace.next
        while e[0] == VIEW_MOD
          if !@requires_done
            begin
              require "#{e[1]}"
            rescue LoadError => e
              view = GoSim::View.instance
              view.show_error("Could not find view module - please select a " +
                              "view\nmodule that is compatable with the data set.")
              file = view.get_file_dialog
              load file
            end
          end
          e = @trace.next
        end

        @requires_done = true

        if e[0] == TIME_MOD
          @time = e[1]  
        else
          raise Exception.new("InvalidTrace")
        end
      end

      def queue_to(time)
        while time > @time
          event = @trace.next
          break if event.nil?

          puts "Event read #{event.inspect}"

          if event[0] == TIME_MOD
            @time = event[1]
            puts "Set time to #{@time}"
          else
            @sim.schedule_event(:data_set_add, @sid, @time - @sim.time, event)
          end
        end

        return @time
      end

      def handle_data_set_add(event)
        if !DataSet[event[0]].nil?
          puts "#{event.inspect}"
          DataSet[event[0]].log(event[1]) #.each { | h | h.call(*event[1]) }
        end
      end
    end #DataSetReader

    class DataSetWriter
      include Singleton

      def initialize
        @running = false
        @last_time = -1
        @file = nil
        @sim = Simulation::instance
        @sim.add_observer(self)
      end

      def update
        @file.close
        rewind
      end

      def rewind
        @file = Zlib::GzipWriter.open(@output_file)
      end

      def set_output_file(file = './output/trace.gz')
        if !@running
          @output_file = file
          rewind 
        end
      end

      def add_view_mod(name)
        @file.write([VIEW_MOD, name].to_yaml)  if @file && @sim.time == 0
      end

      def flush_all
        @file.flush  if !@file.nil?
      end

      def log(sym, args)
        if(!@file.nil?)
          if(@sim.time > @last_time)
            @last_time = @sim.time
            @file.write([TIME_MOD, @sim.time].to_yaml)
          end

          @file.write([sym, args].to_yaml)
        end
      end  #DataSetWriter

      def close
        flush_all
        @file.close  if !@file.nil?
      end
    end

    class DataSet
      @@sets = {}
      @@handlers = {}

      class << self

        def add_handler(key, &block)
          if !@@handlers.has_key?(key)
            DataSet.new(key)
          end

          @@handlers[key] ||= []
          @@handlers[key] << block
        end

        def [](set)
          @@sets[set]
        end
      end

      def initialize(name)
        @name = name.to_sym
        @@sets[@name] = self
      end

      # TODO: Maybe we want to log while also visualizing?
      # DataSet::flush_all
      def log(*args)
        if @@handlers[@name]
          @@handlers[@name].each {|h| h.call(*args) }
        end

        # Always log for now.
        DataSetWriter::instance.log(@name, args)
      end
    end #DataSet

  end  #Data
end

