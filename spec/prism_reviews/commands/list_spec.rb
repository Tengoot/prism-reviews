# frozen_string_literal: true

require 'prism_reviews'
require 'dry/cli'
require 'prism_reviews/commands/list'
require 'open3'

RSpec.describe PrismReviews::Commands::List do
  let(:valid_config) { File.expand_path('../../fixtures/valid_config.yml', __dir__) }

  describe 'with a valid config and PRs' do
    let(:sample_prs) do
      [
        PrismReviews::PullRequest.new(
          number: 123, repo: 'acme/api-service', title: 'Add endpoint',
          author: 'outsider', requested_reviewers: %w[alice-gh], labels: [], head_ref: 'feature/x'
        ),
        PrismReviews::PullRequest.new(
          number: 456, repo: 'acme/api-service', title: 'Fix bug',
          author: 'bob-gh', requested_reviewers: [], labels: [], head_ref: 'fix/y'
        )
      ]
    end

    before do
      Rainbow.enabled = false
      allow(PrismReviews::Fetcher).to receive(:call).and_return(sample_prs)
      allow(PrismReviews::Fetcher).to receive(:current_user).and_return('alice-gh')
      allow(PrismReviews::StateRepo).to receive(:sync_and_read).and_return(PrismReviews::RotationState.new)
    end

    it 'prints queued PRs grouped by queue' do
      expect { described_class.new.call(config: valid_config) }
        .to output(/Direct Requests.*#123.*Team.*#456/m).to_stdout
    end

    it 'shows rotation suggestions when state repo is configured' do
      state = PrismReviews::RotationState.new(last_assigned: { 'backend' => 'alice' })
      allow(PrismReviews::StateRepo).to receive(:sync_and_read).and_return(state)

      expect { described_class.new.call(config: valid_config) }
        .to output(/suggested:/).to_stdout
    end

    it 'handles state repo errors gracefully' do
      allow(PrismReviews::StateRepo).to receive(:sync_and_read)
        .and_raise(PrismReviews::StateRepoError, 'connection failed')

      expect { described_class.new.call(config: valid_config) }
        .to output(/Warning: connection failed/).to_stderr
    end
  end

  describe 'with a missing config' do
    it 'prints error to stderr and exits non-zero' do
      _stdout, stderr, status = Open3.capture3('bundle', 'exec', 'ruby', 'bin/prism', 'list',
                                               '--config', '/nonexistent/config.yml')
      expect(status).not_to be_success
      expect(stderr).to include('Error: Config file not found')
    end
  end

  describe 'when gh is not authenticated' do
    before do
      allow(PrismReviews::Fetcher).to receive(:current_user)
        .and_raise(PrismReviews::GhAuthError, 'gh CLI not authenticated')
    end

    it 'prints error to stderr and exits non-zero' do
      expect { described_class.new.call(config: valid_config) }
        .to output(/Error: gh CLI not authenticated/).to_stderr
        .and raise_error(SystemExit)
    end
  end
end
