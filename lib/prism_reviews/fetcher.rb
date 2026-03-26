# frozen_string_literal: true

require 'json'
require 'open3'
require_relative 'pull_request'

module PrismReviews
  class Fetcher
    GH_JSON_FIELDS = 'number,title,author,reviewRequests,labels,headRefName'

    def self.call(config:)
      new(config).call
    end

    def self.current_user
      stdout, stderr, status = Open3.capture3('gh', 'api', 'user', '--jq', '.login')
      raise GhAuthError, "Failed to get current user: #{stderr.strip}" unless status.success?

      stdout.strip
    end

    def self.fetch_pr(repo:, number:)
      stdout, stderr, status = Open3.capture3(
        'gh', 'pr', 'view', number.to_s, '--repo', repo, '--json', GH_JSON_FIELDS
      )
      raise FetchError, "Failed to fetch PR ##{number} from #{repo}: #{stderr.strip}" unless status.success?

      new(nil).send(:build_pull_request, repo, JSON.parse(stdout))
    end

    def initialize(config)
      @config = config
      @org = config.github_org
    end

    def call
      verify_gh_available!
      verify_gh_authenticated!

      unique_repos.flat_map { |repo| fetch_repo(repo) }
    end

    private

    def unique_repos
      @config.expertise_tags.values.flatten.uniq
    end

    def fetch_repo(repo)
      full_repo = "#{@org}/#{repo}"
      stdout, stderr, status = run_gh_pr_list(full_repo)

      unless status.success?
        warn "Warning: Failed to fetch PRs for #{full_repo}: #{stderr.strip}"
        return []
      end

      parse_prs(full_repo, stdout)
    end

    def run_gh_pr_list(full_repo)
      Open3.capture3('gh', 'pr', 'list', '--repo', full_repo, '--json', GH_JSON_FIELDS, '--state', 'open')
    end

    def parse_prs(full_repo, json_string)
      JSON.parse(json_string).map { |data| build_pull_request(full_repo, data) }
    end

    def build_pull_request(full_repo, data)
      PullRequest.new(
        number: data['number'],
        repo: full_repo,
        title: data['title'],
        author: data.dig('author', 'login'),
        requested_reviewers: extract_reviewers(data['reviewRequests']),
        labels: data.fetch('labels', []).map { |l| l['name'] },
        head_ref: data['headRefName']
      )
    end

    def extract_reviewers(review_requests)
      (review_requests || []).map { |rr| rr['login'] || rr['name'] }
    end

    def verify_gh_available!
      _, _, status = Open3.capture3('gh', '--version')
      raise GhNotFoundError, 'gh CLI not found. Install it from https://cli.github.com' unless status.success?
    end

    def verify_gh_authenticated!
      _, stderr, status = Open3.capture3('gh', 'auth', 'status')
      raise GhAuthError, "gh CLI not authenticated. Run 'gh auth login' first.\n#{stderr.strip}" unless status.success?
    end
  end
end
