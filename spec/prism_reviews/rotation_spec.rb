# frozen_string_literal: true

require 'prism_reviews'

RSpec.describe PrismReviews::Rotation do
  let(:config) do
    PrismReviews::Configuration.new(
      github_org: 'acme',
      expertise_tags: {
        'backend' => %w[api-service admin-portal],
        'frontend' => %w[web-app dashboard-ui]
      },
      reviewers: [
        PrismReviews::Configuration::Reviewer.new(name: 'alice', github: 'alice-gh', tags: %w[backend], maintainer: []),
        PrismReviews::Configuration::Reviewer.new(name: 'bob', github: 'bob-gh', tags: %w[backend], maintainer: []),
        PrismReviews::Configuration::Reviewer.new(name: 'carol', github: 'carol-gh', tags: %w[frontend], maintainer: [])
      ]
    )
  end

  let(:empty_state) { PrismReviews::RotationState.new }

  def make_pr(repo:)
    PrismReviews::PullRequest.new(
      number: 1, repo: "acme/#{repo}", title: 'Some change',
      author: 'outsider', requested_reviewers: [], labels: [], head_ref: 'feature/x'
    )
  end

  describe '.suggest' do
    context 'basic rotation' do
      it 'returns the first reviewer alphabetically when no prior state' do
        pr = make_pr(repo: 'api-service')

        result = described_class.suggest(pull_request: pr, config:, state: empty_state)

        expect(result).to eq('alice')
      end

      it 'returns the next reviewer after last assigned' do
        state = PrismReviews::RotationState.new(last_assigned: { 'backend' => 'alice' })
        pr = make_pr(repo: 'api-service')

        result = described_class.suggest(pull_request: pr, config:, state:)

        expect(result).to eq('bob')
      end

      it 'wraps around to the first reviewer after the last one' do
        state = PrismReviews::RotationState.new(last_assigned: { 'backend' => 'bob' })
        pr = make_pr(repo: 'api-service')

        result = described_class.suggest(pull_request: pr, config:, state:)

        expect(result).to eq('alice')
      end
    end

    context 'skip logic' do
      it 'skips reviewers whose skip_until date has not passed' do
        state = PrismReviews::RotationState.new(skip_until: { 'alice' => '2099-12-31' })
        pr = make_pr(repo: 'api-service')

        result = described_class.suggest(pull_request: pr, config:, state:)

        expect(result).to eq('bob')
      end

      it 'includes reviewers whose skip_until date has passed' do
        state = PrismReviews::RotationState.new(skip_until: { 'alice' => '2020-01-01' })
        pr = make_pr(repo: 'api-service')

        result = described_class.suggest(pull_request: pr, config:, state:)

        expect(result).to eq('alice')
      end

      it 'returns nil when all candidates are skipped' do
        state = PrismReviews::RotationState.new(
          skip_until: { 'alice' => '2099-12-31', 'bob' => '2099-12-31' }
        )
        pr = make_pr(repo: 'api-service')

        result = described_class.suggest(pull_request: pr, config:, state:)

        expect(result).to be_nil
      end
    end

    context 'no matching tags' do
      it 'returns nil for repos with no expertise tags' do
        pr = make_pr(repo: 'unknown-repo')

        result = described_class.suggest(pull_request: pr, config:, state: empty_state)

        expect(result).to be_nil
      end
    end

    context 'no matching reviewers' do
      it 'returns nil when no reviewers have matching tags' do
        config_no_frontend = PrismReviews::Configuration.new(
          github_org: 'acme',
          expertise_tags: { 'ops' => %w[infra-tools] },
          reviewers: [
            PrismReviews::Configuration::Reviewer.new(name: 'alice', github: 'alice-gh', tags: %w[backend],
                                                      maintainer: [])
          ]
        )
        pr = make_pr(repo: 'infra-tools')

        result = described_class.suggest(pull_request: pr, config: config_no_frontend, state: empty_state)

        expect(result).to be_nil
      end
    end

    context 'multi-expertise' do
      let(:multi_config) do
        PrismReviews::Configuration.new(
          github_org: 'acme',
          expertise_tags: {
            'backend' => %w[api-service],
            'ruby' => %w[api-service]
          },
          reviewers: [
            PrismReviews::Configuration::Reviewer.new(name: 'alice', github: 'alice-gh', tags: %w[backend],
                                                      maintainer: []),
            PrismReviews::Configuration::Reviewer.new(name: 'bob', github: 'bob-gh', tags: %w[backend ruby],
                                                      maintainer: [])
          ]
        )
      end

      it 'prefers the reviewer covering more matching tags' do
        pr = make_pr(repo: 'api-service')

        result = described_class.suggest(pull_request: pr, config: multi_config, state: empty_state)

        expect(result).to eq('bob')
      end

      it 'falls back to rotation within the highest coverage group' do
        state = PrismReviews::RotationState.new(last_assigned: { 'backend' => 'bob', 'ruby' => 'bob' })
        pr = make_pr(repo: 'api-service')

        # bob is the only one with 2-tag coverage, so he wraps around to himself
        result = described_class.suggest(pull_request: pr, config: multi_config, state:)

        expect(result).to eq('bob')
      end
    end

    context 'rotation with unknown last_assigned' do
      it 'starts from the first reviewer when last_assigned name is not in candidates' do
        state = PrismReviews::RotationState.new(last_assigned: { 'backend' => 'unknown-person' })
        pr = make_pr(repo: 'api-service')

        result = described_class.suggest(pull_request: pr, config:, state:)

        expect(result).to eq('alice')
      end
    end
  end
end
