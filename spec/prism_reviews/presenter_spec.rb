# frozen_string_literal: true

require 'prism_reviews'

RSpec.describe PrismReviews::Presenter do
  before { Rainbow.enabled = false }

  let(:direct_pr) do
    PrismReviews::PullRequest.new(
      number: 1, repo: 'acme/api-service', title: 'Fix auth',
      author: 'outsider', requested_reviewers: ['alice-gh'], labels: [], head_ref: 'fix/auth'
    )
  end

  let(:team_pr) do
    PrismReviews::PullRequest.new(
      number: 2, repo: 'acme/web-app', title: 'Add button',
      author: 'bob-gh', requested_reviewers: [], labels: [], head_ref: 'feature/button'
    )
  end

  let(:expertise_pr) do
    PrismReviews::PullRequest.new(
      number: 3, repo: 'acme/admin-portal', title: 'Update styles',
      author: 'outsider', requested_reviewers: [], labels: [], head_ref: 'feature/styles'
    )
  end

  describe '.call' do
    it 'prints queue headers with PR counts' do
      result = PrismReviews::Filter::Result.new(direct: [direct_pr], team: [], expertise: [], maintainer: [])

      expect { described_class.call(result, {}) }
        .to output(/Direct Requests \(1\)/).to_stdout
    end

    it 'prints PR number, repo, and title' do
      result = PrismReviews::Filter::Result.new(direct: [direct_pr], team: [], expertise: [], maintainer: [])

      expect { described_class.call(result, {}) }
        .to output(%r{#1.*acme/api-service.*Fix auth}m).to_stdout
    end

    it 'prints author and branch metadata' do
      result = PrismReviews::Filter::Result.new(direct: [direct_pr], team: [], expertise: [], maintainer: [])

      expect { described_class.call(result, {}) }
        .to output(%r{author: outsider \| branch: fix/auth}).to_stdout
    end

    it 'prints suggested reviewer when present' do
      result = PrismReviews::Filter::Result.new(direct: [], team: [team_pr], expertise: [], maintainer: [])
      suggestions = { 2 => 'alice' }

      expect { described_class.call(result, suggestions) }
        .to output(/suggested: alice/).to_stdout
    end

    it 'omits suggested reviewer when absent' do
      result = PrismReviews::Filter::Result.new(direct: [direct_pr], team: [], expertise: [], maintainer: [])

      expect { described_class.call(result, {}) }
        .not_to output(/suggested:/).to_stdout
    end

    it 'skips empty queues' do
      result = PrismReviews::Filter::Result.new(direct: [], team: [team_pr], expertise: [], maintainer: [])

      output = capture_output { described_class.call(result, {}) }

      expect(output).not_to include('Direct Requests')
      expect(output).not_to include('Expertise')
      expect(output).to include('Team (1)')
    end

    it 'prints multiple queues in order' do
      result = PrismReviews::Filter::Result.new(
        direct: [direct_pr], team: [team_pr], expertise: [expertise_pr], maintainer: []
      )

      output = capture_output { described_class.call(result, {}) }

      direct_pos = output.index('Direct Requests')
      team_pos = output.index('Team')
      expertise_pos = output.index('Expertise')
      expect(direct_pos).to be < team_pos
      expect(team_pos).to be < expertise_pos
    end
  end

  def capture_output(&)
    output = StringIO.new
    $stdout = output
    yield
    output.string
  ensure
    $stdout = STDOUT
  end
end
