# frozen_string_literal: true

require 'prism_reviews/cli'
require 'open3'

RSpec.describe 'CLI' do
  describe 'prism version' do
    it 'prints the version' do
      stdout, _stderr, status = Open3.capture3('bundle', 'exec', 'ruby', 'bin/prism', 'version')
      expect(status).to be_success
      expect(stdout.strip).to eq("prism_reviews #{PrismReviews::VERSION}")
    end
  end
end
