# frozen_string_literal: true

module PrismReviews
  RotationState = Data.define(:last_assigned, :skip_until) do
    def initialize(last_assigned: {}, skip_until: {})
      super
    end

    def with_last_assigned(tags, reviewer_name)
      new_assigned = last_assigned.merge(tags.to_h { |tag| [tag, reviewer_name] })
      RotationState.new(last_assigned: new_assigned, skip_until:)
    end

    def with_skip_until(person_name, date_string)
      new_skip = skip_until.merge(person_name => date_string)
      RotationState.new(last_assigned:, skip_until: new_skip)
    end

    def to_h
      { 'last_assigned' => last_assigned, 'skip_until' => skip_until }
    end
  end
end
