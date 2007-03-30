module GoSim
module Data

  class EventCast
    include Singleton

    def initialize
      @event_handlers = {}
    end

    def publish(type, *args)
      if @event_handlers.has_key?(type)
        @event_handlers[type].each { |e| e.call(*args) } 
      end
    end

    def add_handler(type, method = nil, &block)
      method = method || block

      return if method.nil?

      @event_handlers[type] ||= []
      @event_handlers[type] << method
    end
  end

end
end

