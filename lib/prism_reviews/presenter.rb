# frozen_string_literal: true

require 'rainbow'

module PrismReviews
  class Presenter
    QUEUE_LABELS = {
      direct: 'Direct Requests',
      team: 'Team',
      expertise: 'Expertise',
      maintainer: 'Maintainer'
    }.freeze

    def self.call(result, suggestions)
      new(result, suggestions).call
    end

    def initialize(result, suggestions)
      @result = result
      @suggestions = suggestions
    end

    def call
      Filter::QUEUES.each { |queue| print_queue(queue) }
    end

    private

    def print_queue(queue)
      prs = @result.send(queue)
      return if prs.empty?

      puts Rainbow("#{QUEUE_LABELS[queue]} (#{prs.size})").bold
      prs.each { |pull_request| print_pull_request(pull_request) }
      puts
    end

    def print_pull_request(pull_request)
      number = Rainbow("##{pull_request.number}").cyan
      repo = Rainbow("[#{pull_request.repo}]").faint
      puts "  #{number} #{repo} #{pull_request.title}"
      puts "    #{metadata_line(pull_request)}"
    end

    def metadata_line(pull_request)
      parts = ["author: #{pull_request.author}", "branch: #{pull_request.head_ref}"]
      suggested = @suggestions[pull_request.number]
      parts << "suggested: #{Rainbow(suggested).green.bold}" if suggested
      parts.join(' | ')
    end
  end
end
