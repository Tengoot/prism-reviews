# frozen_string_literal: true

require_relative 'errors'
require_relative 'configuration/loader'

module PrismReviews
  class Configuration
    DEFAULT_PATH = File.join(Dir.home, '.config', 'prism', 'config.yml').freeze

    Reviewer = Data.define(:name, :github, :tags, :maintainer)
    FilterRule = Data.define(:pattern, :scope, :repos)
    WorkingHours = Data.define(:start_time, :end_time, :days)
    Notifications = Data.define(:enabled, :notify_method, :poll_interval_minutes, :working_hours)

    attr_reader :github_org, :expertise_tags, :reviewers, :include_rules, :notifications, :state_repo

    def self.load(path: DEFAULT_PATH)
      Loader.call(path:)
    end

    def initialize(github_org:, expertise_tags:, reviewers:, include_rules: [], notifications: nil, state_repo: nil)
      @github_org = github_org
      @expertise_tags = expertise_tags
      @reviewers = reviewers
      @include_rules = include_rules
      @notifications = notifications
      @state_repo = state_repo
    end

    def reviewer_by_github(login)
      reviewers.find { |r| r.github == login }
    end

    def reviewer_by_name(name)
      reviewers.find { |r| r.name == name }
    end
  end
end
