module Projections
  class ProjectorRunner
    def initialize(projectors)
      @projectors = projectors
    end

    def call(event)
      @projectors.each { |projector| projector.project(event) }
    end
  end
end
