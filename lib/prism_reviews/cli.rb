# frozen_string_literal: true

require 'dry/cli'
require_relative 'commands/version'
require_relative 'commands/list'
require_relative 'commands/claim'
require_relative 'commands/skip'
require_relative 'commands/reassign'

module PrismReviews
  module CLI
    extend Dry::CLI::Registry

    register 'version', Commands::Version
    register 'list', Commands::List
    register 'claim', Commands::Claim
    register 'skip', Commands::Skip
    register 'reassign', Commands::Reassign
  end
end
