# frozen_string_literal: true

require 'prism_reviews'
require 'dry/cli'
require 'prism_reviews/commands/claim'

RSpec.describe PrismReviews::Commands::Claim do
  let(:valid_config) { File.expand_path('../../fixtures/valid_config.yml', __dir__) }
  let(:sample_pr) do
    PrismReviews::PullRequest.new(
      number: 42, repo: 'acme/api-service', title: 'Fix bug',
      author: 'outsider', requested_reviewers: [], labels: [], head_ref: 'fix/y'
    )
  end
  let(:empty_state) { PrismReviews::RotationState.new }

  before do
    allow(PrismReviews::Fetcher).to receive(:current_user).and_return('alice-gh')
    allow(PrismReviews::Fetcher).to receive(:fetch_pr).and_return(sample_pr)
    allow(PrismReviews::StateRepo).to receive(:sync_write_and_push) do |**_kwargs, &block|
      block.call(empty_state)
    end
  end

  it 'claims a PR and advances rotation' do
    expect { described_class.new.call(repo: 'api-service', pr_number: '42', config: valid_config) }
      .to output(%r{Claimed acme/api-service#42}).to_stdout
  end

  it 'updates last_assigned for matching tags' do
    described_class.new.call(repo: 'api-service', pr_number: '42', config: valid_config)

    expect(PrismReviews::StateRepo).to have_received(:sync_write_and_push) do |**kwargs, &block|
      new_state = block.call(empty_state)
      expect(new_state.last_assigned['backend']).to eq('alice')
      expect(kwargs[:message]).to include('alice')
    end
  end

  it 'raises when current user is not in reviewers' do
    allow(PrismReviews::Fetcher).to receive(:current_user).and_return('unknown-gh')

    expect { described_class.new.call(repo: 'api-service', pr_number: '42', config: valid_config) }
      .to output(/not in the reviewers list/).to_stderr
      .and raise_error(SystemExit)
  end

  it 'raises when repo has no matching tags' do
    expect { described_class.new.call(repo: 'unknown-repo', pr_number: '42', config: valid_config) }
      .to output(/No expertise tags match/).to_stderr
      .and raise_error(SystemExit)
  end
end
