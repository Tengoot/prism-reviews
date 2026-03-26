# frozen_string_literal: true

require_relative 'lib/prism_reviews/version'

Gem::Specification.new do |spec|
  spec.name = 'prism_reviews'
  spec.version = PrismReviews::VERSION
  spec.authors = ['Bartosz Kowalski']
  spec.summary = 'Expertise-based PR review routing and round-robin rotation'

  spec.required_ruby_version = '>= 4.0'

  spec.files = Dir['lib/**/*', 'bin/*']
  spec.bindir = 'bin'
  spec.executables = ['prism']

  spec.add_dependency 'dry-cli', '~> 1.4'
  spec.add_dependency 'dry-validation', '~> 1.0'
  spec.add_dependency 'rainbow', '~> 3.1'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
