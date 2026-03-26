# frozen_string_literal: true

module PrismReviews
  class Error < StandardError; end
  class ConfigNotFoundError < Error; end
  class ConfigValidationError < Error; end
  class GhNotFoundError < Error; end
  class GhAuthError < Error; end
  class FetchError < Error; end
  class StateRepoError < Error; end
  class StatePushConflictError < StateRepoError; end
end
