# frozen_string_literal: true

module PrismReviews
  class Configuration
    module Builder
      def self.call(data)
        Configuration.new(
          github_org: data['github_org'],
          expertise_tags: data['expertise_tags'],
          reviewers: build_reviewers(data['reviewers']),
          exclude: build_exclude(data['exclude']),
          notifications: build_notifications(data['notifications']),
          state_repo: data['state_repo']
        )
      end

      def self.build_reviewers(reviewers)
        reviewers.map do |name, config|
          Reviewer.new(name:, github: config['github'], tags: config['tags'],
                       maintainer: config.fetch('maintainer', []))
        end
      end

      def self.build_exclude(exclude)
        (exclude || []).map do |rule|
          ExclusionRule.new(pattern: rule['pattern'], scope: rule['scope'], repos: rule.fetch('repos', []))
        end
      end

      def self.build_notifications(data)
        return nil if data.nil?

        Notifications.new(
          enabled: data.fetch('enabled', true),
          notify_method: data.fetch('method', 'terminal-notifier'),
          poll_interval_minutes: data.fetch('poll_interval_minutes', 15),
          working_hours: build_working_hours(data['working_hours'])
        )
      end

      def self.build_working_hours(data)
        default_days = %w[mon tue wed thu fri]
        return WorkingHours.new(start_time: '09:00', end_time: '18:00', days: default_days) if data.nil?

        WorkingHours.new(
          start_time: data.fetch('start', '09:00'),
          end_time: data.fetch('end', '18:00'),
          days: data.fetch('days', default_days)
        )
      end
    end
  end
end
