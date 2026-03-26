# frozen_string_literal: true

require 'rainbow'
require_relative '../configuration'
require_relative '../fetcher'
require_relative '../filter'
require_relative '../presenter'
require_relative '../state_repo'
require_relative '../rotation'

module PrismReviews
  module Commands
    class List < Dry::CLI::Command
      desc 'List open PRs requiring review'

      option :config, type: :string, desc: 'Path to config file'
      option :no_color, type: :boolean, default: false, desc: 'Disable colorized output'

      def call(**options)
        Rainbow.enabled = false if options[:no_color]

        config = load_config(options)
        result = fetch_and_filter(config)
        state = load_state(config)
        suggestions = compute_suggestions(result, config, state)

        Presenter.call(result, suggestions)
      rescue PrismReviews::ConfigNotFoundError, PrismReviews::ConfigValidationError,
             PrismReviews::GhNotFoundError, PrismReviews::GhAuthError => e
        warn "Error: #{e.message}"
        exit 1
      end

      private

      def load_config(options)
        path = options[:config] || Configuration::DEFAULT_PATH
        Configuration.load(path:)
      end

      def fetch_and_filter(config)
        current_user = Fetcher.current_user
        prs = Fetcher.call(config:)
        Filter.call(pull_requests: prs, config:, current_user:)
      end

      def load_state(config)
        return RotationState.new if config.state_repo.nil?

        StateRepo.sync_and_read(repo_url: state_repo_url(config))
      rescue StateRepoError => e
        warn "Warning: #{e.message}"
        RotationState.new
      end

      def state_repo_url(config)
        "https://github.com/#{config.state_repo}.git"
      end

      def compute_suggestions(result, config, state)
        suggestions = {}
        %i[team expertise maintainer].each do |queue|
          result.send(queue).each do |pull_request|
            name = Rotation.suggest(pull_request:, config:, state:)
            suggestions[pull_request.number] = name if name
          end
        end
        suggestions
      end
    end
  end
end
