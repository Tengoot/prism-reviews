# frozen_string_literal: true

require_relative '../version'

module PrismReviews
  module Commands
    class Version < Dry::CLI::Command
      desc 'Print PRism Reviews version'

      def call(*)
        puts "prism_reviews #{PrismReviews::VERSION}"
      end
    end
  end
end
