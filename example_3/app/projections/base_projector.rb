module Projections
  class BaseProjector
    class << self
      def subscribes_to(event_types = nil)
        if event_types
          @subscribed_events = Array(event_types)
        else
          @subscribed_events || []
        end
      end

      def subscribed_events
        subscribes_to
      end

      def on(event_type, &block)
        event_handlers[event_type.to_s] = block
      end

      def event_handlers
        @event_handlers ||= {}
      end

      def projector_name
        name.demodulize.underscore
      end
    end

    def project(event)
      handler = self.class.event_handlers[event.class.to_s]
      return unless handler

      instance_exec(event, &handler)
    rescue StandardError => e
      handle_error(event, e)
      raise
    end

    def subscribes_to?(event_type)
      subscribed = self.class.subscribed_events
      return true if subscribed.empty? # subscribe to all if not specified

      subscribed.any? { |type| event_type <= type || event_type == type }
    end

    private

    def handle_error(event, error)
      # Error will be handled by ProjectionManager
      Rails.logger.error("[#{self.class.projector_name}] Failed to project #{event.class}: #{error.message}")
    end
  end
end
