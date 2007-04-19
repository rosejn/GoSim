module GoSim
  module Net

    class NotCallableError < Exception; end
    class NotFailureError < Exception; end

    class Failure
      attr_accessor :result

      def initialize(result)
        @result = result
      end
    end

    # A callback which will be called at some later point.
    class Deferred
      PASSTHRU = lambda {|result| return result}

      attr_reader :callbacks, :errbacks

      def initialize
        @called = false
        @paused = 0
        @callbacks = []
        @errbacks = []
      end

      def add_callbacks(callback, errback = nil)
        raise NotCallableError unless is_callable?(callback)
        @callbacks << callback

        if errback
          raise NotCallableError unless is_callable?(errback)
          @errbacks << errback
        else
          @errbacks << PASSTHRU
        end

        run_callbacks if @called
      end

      def add_callback(callback = nil, &block)
        if callback
          add_callbacks(callback)
        elsif block
          add_callbacks(block)
        end
      end

      def add_errback(errback = nil, &block)
        if errback
          add_callbacks(PASSTHRU, errback)
        elsif block
          add_callbacks(PASSTHRU, block)
        end
      end

      # Stop processing on this Deferred until unpause is called.
      def pause
        @paused += 1
      end

      # Resume processing if any callbacks were added since pause was called.
      def unpause
        @paused -= 1

        if @paused > 0
          return
        else
          run_callbacks if @called
        end
      end

      def callback(result)
        @called = true
        @result = result
        run_callbacks
      end

      def errback(result)
        raise NotFailureError unless is_failure?(result)

        callback(result)
      end

      def has_callbacks?
        @callbacks.any? { | cb | cb != PASSTHRU }
      end

      def has_errbacks?
        @errbacks.any? { | eb | eb != PASSTHRU }
      end

      # Execute the callbacks in sequence, passing the result of each callback to
      # the next one until all have been called.  If an exception is raised or a
      # Failure is returned than processing shifts to the errbacks, and likewise if
      # an errback returns a non Failure result it shifts to the callbacks.
      def run_callbacks
        return if @paused > 0

        # Transverse chains
        while @callbacks.any?
          begin
            cb = @callbacks.shift
            eb = @errbacks.shift

            if is_failure?(@result)
              @result = eb.call(@result)
            else
              @result = cb.call(@result)
            end
          rescue Exception => exc
            @result = Failure.new(exc)
          end
        end
      end

      def is_callable?(obj)
        obj.respond_to?(:call)
      end

      def is_failure?(obj)
        obj.is_a?(Net::Failure) || obj.nil?
      end
    end
  end
end
