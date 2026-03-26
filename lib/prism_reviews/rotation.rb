# frozen_string_literal: true

require 'date'

module PrismReviews
  class Rotation
    def self.suggest(pull_request:, config:, state:)
      new(config, state).suggest(pull_request)
    end

    def self.tags_for_repo(repo_short, config)
      config.expertise_tags.select { |_tag, repos| repos.include?(repo_short) }.keys
    end

    def initialize(config, state)
      @config = config
      @state = state
      @today = Date.today
    end

    def suggest(pull_request)
      repo_short = pull_request.repo.split('/').last
      matching_tags = tags_for_repo(repo_short)
      return nil if matching_tags.empty?

      candidates = reviewers_for_tags(matching_tags)
      return nil if candidates.empty?

      best_candidate(candidates, matching_tags)
    end

    private

    def tags_for_repo(repo)
      self.class.tags_for_repo(repo, @config)
    end

    def reviewers_for_tags(tags)
      @config.reviewers.select { |reviewer| reviewer.tags.intersect?(tags) }
    end

    def best_candidate(candidates, matching_tags)
      grouped = candidates.group_by { |reviewer| (reviewer.tags & matching_tags).size }
      top_coverage = grouped.keys.max
      top_candidates = grouped[top_coverage].sort_by(&:name)

      next_in_rotation(top_candidates, matching_tags)
    end

    def next_in_rotation(candidates, matching_tags)
      available = candidates.reject { |reviewer| skipped?(reviewer.name) }
      return nil if available.empty?

      rotate_after(available, last_assigned_for(matching_tags))
    end

    def rotate_after(available, last_name)
      return available.first.name if last_name.nil?

      idx = available.index { |reviewer| reviewer.name == last_name }
      return available.first.name if idx.nil?

      available[(idx + 1) % available.size].name
    end

    def last_assigned_for(tags)
      tags.filter_map { |tag| @state.last_assigned[tag] }.last
    end

    def skipped?(name)
      date_str = @state.skip_until[name]
      return false if date_str.nil?

      Date.parse(date_str) > @today
    end
  end
end
