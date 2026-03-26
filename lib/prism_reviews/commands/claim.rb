# frozen_string_literal: true

require_relative '../configuration'
require_relative '../fetcher'
require_relative '../rotation'
require_relative '../state_repo'

module PrismReviews
  module Commands
    class Claim < Dry::CLI::Command
      desc 'Claim a PR and advance the rotation pointer'

      argument :repo, required: true, desc: 'Repository short name (e.g. api-service)'
      argument :pr_number, required: true, desc: 'Pull request number'
      option :config, type: :string, desc: 'Path to config file'

      def call(repo:, pr_number:, **options)
        config = load_config(options)
        require_state_repo!(config)
        reviewer = resolve_current_reviewer(config)
        full_repo = "#{config.github_org}/#{repo}"
        tags = resolve_tags(repo, config)

        claim_and_push(config, reviewer, full_repo, pr_number, tags)
        puts "Claimed #{full_repo}##{pr_number} — rotation advanced for tags: #{tags.join(', ')}"
      rescue PrismReviews::Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      private

      def load_config(options)
        path = options[:config] || Configuration::DEFAULT_PATH
        Configuration.load(path:)
      end

      def require_state_repo!(config)
        raise Error, 'No state_repo configured' if config.state_repo.nil?
      end

      def state_repo_url(config)
        "https://github.com/#{config.state_repo}.git"
      end

      def resolve_current_reviewer(config)
        login = Fetcher.current_user
        reviewer = config.reviewer_by_github(login)
        raise Error, "You (#{login}) are not in the reviewers list" unless reviewer

        reviewer
      end

      def claim_and_push(config, reviewer, full_repo, pr_number, tags)
        Fetcher.fetch_pr(repo: full_repo, number: pr_number.to_i)
        StateRepo.sync_write_and_push(
          repo_url: state_repo_url(config),
          message: "claim: #{reviewer.name} claims #{full_repo}##{pr_number}"
        ) { |state| state.with_last_assigned(tags, reviewer.name) }
      end

      def resolve_tags(repo_short, config)
        tags = Rotation.tags_for_repo(repo_short, config)
        raise Error, "No expertise tags match repo '#{repo_short}'" if tags.empty?

        tags
      end
    end
  end
end
