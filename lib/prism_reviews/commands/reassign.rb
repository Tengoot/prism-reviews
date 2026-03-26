# frozen_string_literal: true

require_relative '../configuration'
require_relative '../fetcher'
require_relative '../rotation'
require_relative '../state_repo'

module PrismReviews
  module Commands
    class Reassign < Dry::CLI::Command
      desc 'Reassign a PR to a specific reviewer'

      argument :repo, required: true, desc: 'Repository short name (e.g. api-service)'
      argument :pr_number, required: true, desc: 'Pull request number'
      argument :person, required: true, desc: 'Reviewer name to assign'
      option :config, type: :string, desc: 'Path to config file'

      def call(repo:, pr_number:, person:, **options)
        config = load_config(options)
        require_state_repo!(config)
        validate_reviewer!(person, config)
        full_repo = "#{config.github_org}/#{repo}"
        tags = resolve_tags(repo, config)

        reassign_and_push(config, full_repo, pr_number, person, tags)
        puts "Reassigned #{full_repo}##{pr_number} to #{person} — rotation updated for tags: #{tags.join(', ')}"
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

      def reassign_and_push(config, full_repo, pr_number, person, tags)
        Fetcher.fetch_pr(repo: full_repo, number: pr_number.to_i)
        StateRepo.sync_write_and_push(
          repo_url: state_repo_url(config),
          message: "reassign: #{full_repo}##{pr_number} to #{person}"
        ) { |state| state.with_last_assigned(tags, person) }
      end

      def validate_reviewer!(person, config)
        raise Error, "Unknown reviewer: #{person}" unless config.reviewer_by_name(person)
      end

      def resolve_tags(repo_short, config)
        tags = Rotation.tags_for_repo(repo_short, config)
        raise Error, "No expertise tags match repo '#{repo_short}'" if tags.empty?

        tags
      end
    end
  end
end
