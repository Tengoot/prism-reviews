# frozen_string_literal: true

require 'yaml'
require 'dry/validation'
require_relative 'builder'

module PrismReviews
  class Configuration
    class Loader
      class ConfigContract < Dry::Validation::Contract
        params do
          required(:github_org).filled(:string)
          required(:expertise_tags).filled(:hash)
          required(:reviewers).filled(:hash)

          optional(:exclude).array(:hash) do
            required(:pattern).filled(:string)
            required(:scope).filled(:string)
            optional(:repos).array(:string)
          end

          optional(:notifications).hash do
            optional(:enabled).filled(:bool)
            optional(:method).filled(:string)
            optional(:poll_interval_minutes).filled(:integer)
            optional(:working_hours).hash do
              optional(:start).filled(:string)
              optional(:end).filled(:string)
              optional(:days).array(:string)
            end
          end

          optional(:state_repo).filled(:string)
        end

        rule(:expertise_tags) do
          next unless value.is_a?(Hash)

          value.each do |name, repos|
            key([:expertise_tags, name]).failure('must be an array of repository names') unless repos.is_a?(Array)
          end
        end

        rule(:reviewers) do
          next unless value.is_a?(Hash)

          reviewer_schema = Dry::Schema.Params do
            required(:github).filled(:string)
            required(:tags).value(:array, min_size?: 1)
            optional(:maintainer).array(:string)
          end

          value.each do |name, config|
            unless config.is_a?(Hash)
              key([:reviewers, name]).failure('must be a mapping with github and tags fields')
              next
            end

            reviewer_schema.call(config).errors.to_h.each do |field, messages|
              key([:reviewers, name]).failure("#{field} #{messages.join(', ')}")
            end
          end
        end

        rule(:exclude).each do
          key.failure('scope must be one of: expertise, maintainer, all') unless
            %w[expertise maintainer all].include?(value[:scope])
        end
      end

      def self.call(path:)
        new(path).call
      end

      def initialize(path)
        @path = path
      end

      def call
        raise ConfigNotFoundError, "Config file not found at #{@path}" unless File.exist?(@path)

        data = YAML.safe_load_file(@path) || {}
        result = ConfigContract.new.call(data)

        if result.failure?
          messages = result.errors.map { |e| "#{e.path.join('.')} #{e.text}" }
          raise ConfigValidationError, messages.join("\n")
        end

        warn_unknown_tags(data)
        Builder.call(data)
      end

      private

      def warn_unknown_tags(data)
        known_tags = data['expertise_tags'].keys

        data['reviewers'].each do |name, config|
          next unless config.is_a?(Hash) && config['tags'].is_a?(Array)

          (config['tags'] - known_tags).each do |tag|
            warn "Warning: Reviewer '#{name}' references unknown tag '#{tag}'"
          end
        end
      end
    end
  end
end
