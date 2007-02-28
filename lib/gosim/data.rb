module GoSim
  class DataSet
    @@sets = {}
    @@handlers = {}

    class << self
      def flush_all
        @@sets.values.each {|s| s.flush }
      end

      def add_handler(key, &block)
        @@handlers[key] ||= []
        @@handlers[key] << block
      end

      def [](set)
        @@sets[set]
      end
    end

    def initialize(name, location='./')
      @sim = Simulation.instance
      @name = name.to_sym
      @@sets[@name] = self

      @location = location
      @data_file = File.open(File.join(location, name.to_s), "w")
    end

    # TODO: Maybe we want to log while also visualizing?
    def log(*args)
      if @@handlers[@name]
        @@handlers[@name].each {|h| h.call(*args) }
      elsif @data_file
        @data_file.write(@sim.time.to_s + ': ' + args.join(', ') + "\n")
      end
    end

    def flush
      @data_file.flush
    end
  end
end

