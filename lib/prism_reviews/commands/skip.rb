# frozen_string_literal: true

require 'date'
require_relative '../configuration'
require_relative '../state_repo'

module PrismReviews
  module Commands
    class Skip < Dry::CLI::Command
      desc 'Skip a person in the rotation'

      argument :person, required: true, desc: 'Reviewer name'
      option :until, type: :string, desc: 'Skip until date (YYYY-MM-DD), default: indefinite'
      option :config, type: :string, desc: 'Path to config file'

      def call(person:, **options)
        config = load_config(options)
        require_state_repo!(config)
        validate_reviewer!(person, config)
        date_str = parse_date(options)

        skip_and_push(config, person, date_str)
        puts "#{person} will be skipped until #{date_str}"
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

      def parse_date(options)
        date_str = options[:until] || '2099-12-31'
        Date.parse(date_str)
        date_str
      rescue Date::Error => e
        raise Error, "Invalid date format: #{e.message}"
      end

      def skip_and_push(config, person, date_str)
        StateRepo.sync_write_and_push(
          repo_url: state_repo_url(config),
          message: "skip: #{person} until #{date_str}"
        ) { |state| state.with_skip_until(person, date_str) }
      end

      def validate_reviewer!(person, config)
        raise Error, "Unknown reviewer: #{person}" unless config.reviewer_by_name(person)
      end
    end
  end
end
