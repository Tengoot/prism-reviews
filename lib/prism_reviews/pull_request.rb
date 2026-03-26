# frozen_string_literal: true

module PrismReviews
  PullRequest = Data.define(:number, :repo, :title, :author, :requested_reviewers, :labels, :head_ref)
end
