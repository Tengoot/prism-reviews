# frozen_string_literal: true

module PrismReviews
  class Filter
    QUEUES = %i[direct team expertise maintainer].freeze

    Result = Data.define(:direct, :team, :expertise, :maintainer)

    def self.call(pull_requests:, config:, current_user:)
      new(pull_requests, config, current_user).call
    end

    def initialize(pull_requests, config, current_user)
      @pull_requests = pull_requests
      @config = config
      @current_user = current_user
      @team_logins = config.reviewers.map(&:github)
      @reviewer = config.reviewers.find { |r| r.github == current_user }
    end

    def call
      seen = Set.new
      direct = assign_queue(:direct, seen)
      team = assign_queue(:team, seen)
      expertise = assign_queue(:expertise, seen)
      maintainer = assign_queue(:maintainer, seen)

      Result.new(direct:, team:, expertise:, maintainer:)
    end

    private

    def assign_queue(queue, seen)
      matches = @pull_requests.select { |pr| belongs_to?(queue, pr) && !seen.include?(pr.number) }
      matches.each { |pr| seen.add(pr.number) }
      matches
    end

    def belongs_to?(queue, pull_request)
      case queue
      when :direct then direct?(pull_request)
      when :team then team?(pull_request)
      when :expertise then expertise?(pull_request)
      when :maintainer then maintainer?(pull_request)
      end
    end

    def direct?(pull_request)
      pull_request.requested_reviewers.include?(@current_user)
    end

    def team?(pull_request)
      @team_logins.include?(pull_request.author)
    end

    def expertise?(pull_request)
      return false if @reviewer.nil?
      return false if @team_logins.include?(pull_request.author)
      return false if excluded?(pull_request)

      my_repos.include?(repo_short_name(pull_request.repo))
    end

    def maintainer?(pull_request)
      return false if @reviewer.nil?

      my_maintainer_repos.include?(repo_short_name(pull_request.repo))
    end

    def excluded?(pull_request)
      @config.exclude.any? { |rule| matches_exclusion?(rule, pull_request) }
    end

    def matches_exclusion?(rule, pull_request)
      File.fnmatch(rule.pattern, pull_request.head_ref)
    end

    def my_repos
      @my_repos ||= @reviewer.tags.flat_map { |tag| @config.expertise_tags.fetch(tag, []) }.uniq
    end

    def my_maintainer_repos
      @my_maintainer_repos ||= @reviewer.maintainer
    end

    def repo_short_name(full_repo)
      full_repo.split('/').last
    end
  end
end
