# frozen_string_literal: true

require 'prism_reviews'

RSpec.describe PrismReviews::Filter do
  let(:config) do
    PrismReviews::Configuration.new(
      github_org: 'acme',
      expertise_tags: {
        'backend' => %w[api-service admin-portal],
        'frontend' => %w[web-app]
      },
      reviewers: [
        PrismReviews::Configuration::Reviewer.new(name: 'alice', github: 'alice-gh', tags: %w[backend],
                                                  maintainer: %w[api-service]),
        PrismReviews::Configuration::Reviewer.new(name: 'bob', github: 'bob-gh', tags: %w[frontend], maintainer: []),
        PrismReviews::Configuration::Reviewer.new(name: 'carol', github: 'carol-gh', tags: %w[backend frontend],
                                                  maintainer: [])
      ],
      include_rules: [
        PrismReviews::Configuration::FilterRule.new(pattern: 'feature/*', scope: 'expertise', repos: [])
      ]
    )
  end

  let(:current_user) { 'alice-gh' }

  def make_pr(overrides = {})
    PrismReviews::PullRequest.new(
      number: overrides.fetch(:number, 1),
      repo: overrides.fetch(:repo, 'acme/api-service'),
      title: overrides.fetch(:title, 'Some change'),
      author: overrides.fetch(:author, 'outsider'),
      requested_reviewers: overrides.fetch(:requested_reviewers, []),
      labels: overrides.fetch(:labels, []),
      head_ref: overrides.fetch(:head_ref, 'feature/something')
    )
  end

  describe '.call' do
    context 'direct queue' do
      it 'includes PRs where current user is a requested reviewer' do
        pr = make_pr(number: 1, requested_reviewers: ['alice-gh'])
        result = described_class.call(pull_requests: [pr], config:, current_user:)

        expect(result.direct).to eq([pr])
      end

      it 'excludes PRs where current user is not requested' do
        pr = make_pr(number: 1, requested_reviewers: ['bob-gh'])
        result = described_class.call(pull_requests: [pr], config:, current_user:)

        expect(result.direct).to be_empty
      end
    end

    context 'team queue' do
      it 'includes PRs authored by team members' do
        pr = make_pr(number: 2, author: 'bob-gh')
        result = described_class.call(pull_requests: [pr], config:, current_user:)

        expect(result.team).to eq([pr])
      end

      it 'excludes PRs authored by non-team members' do
        pr = make_pr(number: 2, author: 'outsider')
        result = described_class.call(pull_requests: [pr], config:, current_user:)

        expect(result.team).to be_empty
      end
    end

    context 'expertise queue' do
      it 'includes PRs in repos matching user expertise tags from non-team authors' do
        pr = make_pr(number: 3, repo: 'acme/api-service', author: 'outsider')
        result = described_class.call(pull_requests: [pr], config:, current_user:)

        expect(result.expertise).to eq([pr])
      end

      it 'excludes PRs from team members' do
        pr = make_pr(number: 3, repo: 'acme/api-service', author: 'bob-gh')
        result = described_class.call(pull_requests: [pr], config:, current_user:)

        expect(result.expertise).to be_empty
      end

      it 'excludes PRs in repos not matching user expertise tags' do
        pr = make_pr(number: 3, repo: 'acme/web-app', author: 'outsider')
        result = described_class.call(pull_requests: [pr], config:, current_user:)

        expect(result.expertise).to be_empty
      end

      it 'excludes PRs not matching include patterns' do
        pr = make_pr(number: 3, repo: 'acme/api-service', author: 'outsider', head_ref: 'dependabot/npm/lodash')
        result = described_class.call(pull_requests: [pr], config:, current_user:)

        expect(result.expertise).to be_empty
      end

      it 'includes PRs matching include patterns' do
        pr = make_pr(number: 3, repo: 'acme/api-service', author: 'outsider', head_ref: 'feature/new-thing')
        result = described_class.call(pull_requests: [pr], config:, current_user:)

        expect(result.expertise).to eq([pr])
      end
    end

    context 'maintainer queue' do
      it 'includes PRs in repos the user maintains' do
        pr = make_pr(number: 4, repo: 'acme/api-service', author: 'outsider')
        result = described_class.call(pull_requests: [pr], config:, current_user:)

        expect(result.maintainer).to be_empty # deduplicated to expertise
      end

      it 'includes maintainer PRs not matching expertise include patterns' do
        pr = make_pr(number: 4, repo: 'acme/api-service', author: 'outsider', head_ref: 'dependabot/npm/lodash')
        result = described_class.call(pull_requests: [pr], config:, current_user:)

        expect(result.maintainer).to eq([pr])
      end

      it 'excludes PRs in repos the user does not maintain' do
        pr = make_pr(number: 4, repo: 'acme/admin-portal', author: 'outsider')
        result = described_class.call(pull_requests: [pr], config:, current_user:)

        expect(result.maintainer).to be_empty
      end
    end

    context 'scope-aware inclusion' do
      it 'scope=all includes in both expertise and maintainer' do
        config_with_all = PrismReviews::Configuration.new(
          github_org: 'acme',
          expertise_tags: { 'backend' => %w[api-service] },
          reviewers: [
            PrismReviews::Configuration::Reviewer.new(name: 'alice', github: 'alice-gh', tags: %w[backend],
                                                      maintainer: %w[api-service])
          ],
          include_rules: [
            PrismReviews::Configuration::FilterRule.new(pattern: 'feature/*', scope: 'all', repos: [])
          ]
        )
        included_pr = make_pr(number: 7, repo: 'acme/api-service', author: 'outsider', head_ref: 'feature/thing')
        excluded_pr = make_pr(number: 8, repo: 'acme/api-service', author: 'outsider', head_ref: 'dependabot/lodash')
        result = described_class.call(pull_requests: [included_pr, excluded_pr], config: config_with_all,
                                      current_user:)

        expect(result.expertise).to eq([included_pr])
        expect(result.maintainer).to be_empty # deduplicated to expertise
      end

      it 'scope=maintainer filters maintainer only, expertise passes all' do
        config_with_maint = PrismReviews::Configuration.new(
          github_org: 'acme',
          expertise_tags: { 'backend' => %w[api-service] },
          reviewers: [
            PrismReviews::Configuration::Reviewer.new(name: 'alice', github: 'alice-gh', tags: %w[backend],
                                                      maintainer: %w[api-service])
          ],
          include_rules: [
            PrismReviews::Configuration::FilterRule.new(pattern: 'dependabot/*', scope: 'maintainer', repos: [])
          ]
        )
        dep_pr = make_pr(number: 8, repo: 'acme/api-service', author: 'outsider', head_ref: 'dependabot/lodash')
        result = described_class.call(pull_requests: [dep_pr], config: config_with_maint, current_user:)

        expect(result.expertise).to eq([dep_pr])
        expect(result.maintainer).to be_empty # deduplicated to expertise
      end

      it 'repos field limits inclusion to named repos' do
        config_with_repos = PrismReviews::Configuration.new(
          github_org: 'acme',
          expertise_tags: { 'backend' => %w[api-service admin-portal] },
          reviewers: [
            PrismReviews::Configuration::Reviewer.new(name: 'alice', github: 'alice-gh', tags: %w[backend],
                                                      maintainer: %w[api-service admin-portal])
          ],
          include_rules: [
            PrismReviews::Configuration::FilterRule.new(pattern: 'feature/*', scope: 'expertise',
                                                        repos: %w[api-service])
          ]
        )

        pr_included = make_pr(number: 9, repo: 'acme/api-service', author: 'outsider', head_ref: 'feature/thing')
        pr_excluded = make_pr(number: 10, repo: 'acme/admin-portal', author: 'outsider', head_ref: 'feature/other')

        result = described_class.call(pull_requests: [pr_included, pr_excluded], config: config_with_repos,
                                      current_user:)

        expect(result.expertise).to eq([pr_included])
      end

      it 'passes all PRs when no include rules exist for a queue' do
        config_no_rules = PrismReviews::Configuration.new(
          github_org: 'acme',
          expertise_tags: { 'backend' => %w[api-service] },
          reviewers: [
            PrismReviews::Configuration::Reviewer.new(name: 'alice', github: 'alice-gh', tags: %w[backend],
                                                      maintainer: %w[api-service])
          ]
        )
        pr = make_pr(number: 11, repo: 'acme/api-service', author: 'outsider', head_ref: 'anything/at-all')
        result = described_class.call(pull_requests: [pr], config: config_no_rules, current_user:)

        expect(result.expertise).to eq([pr])
      end
    end

    context 'deduplication' do
      it 'shows PR in highest priority queue only (direct > team > expertise > maintainer)' do
        pr = make_pr(number: 5, repo: 'acme/api-service', author: 'bob-gh', requested_reviewers: ['alice-gh'])
        result = described_class.call(pull_requests: [pr], config:, current_user:)

        expect(result.direct).to eq([pr])
        expect(result.team).to be_empty
        expect(result.expertise).to be_empty
        expect(result.maintainer).to be_empty
      end

      it 'deduplicates team over expertise' do
        pr = make_pr(number: 6, repo: 'acme/api-service', author: 'carol-gh')
        result = described_class.call(pull_requests: [pr], config:, current_user:)

        expect(result.team).to eq([pr])
        expect(result.expertise).to be_empty
      end
    end

    context 'with multiple PRs' do
      it 'distributes PRs across queues correctly' do
        direct_pr = make_pr(number: 1, repo: 'acme/unknown-repo', author: 'outsider', requested_reviewers: ['alice-gh'])
        team_pr = make_pr(number: 2, repo: 'acme/web-app', author: 'bob-gh')
        expertise_pr = make_pr(number: 3, repo: 'acme/admin-portal', author: 'outsider',
                               head_ref: 'feature/new-thing')
        maintainer_pr = make_pr(number: 4, repo: 'acme/api-service', author: 'outsider',
                                head_ref: 'dependabot/npm/lodash')
        unrelated_pr = make_pr(number: 5, repo: 'acme/other-repo', author: 'outsider')

        prs = [direct_pr, team_pr, expertise_pr, maintainer_pr, unrelated_pr]
        result = described_class.call(pull_requests: prs, config:, current_user:)

        expect(result.direct).to eq([direct_pr])
        expect(result.team).to eq([team_pr])
        expect(result.expertise).to eq([expertise_pr])
        expect(result.maintainer).to eq([maintainer_pr])
      end
    end
  end
end
