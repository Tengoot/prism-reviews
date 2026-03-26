# frozen_string_literal: true

require 'prism_reviews'
require 'open3'

RSpec.describe PrismReviews::Fetcher do
  let(:config) do
    PrismReviews::Configuration.new(
      github_org: 'acme',
      expertise_tags: {
        'backend' => %w[api-service admin-portal],
        'frontend' => %w[web-app]
      },
      reviewers: []
    )
  end

  let(:fixture_json) { File.read(File.expand_path('../fixtures/gh_pr_list_response.json', __dir__)) }
  let(:success_status) { instance_double(Process::Status, success?: true) }
  let(:failure_status) { instance_double(Process::Status, success?: false) }

  before do
    allow(Open3).to receive(:capture3).with('gh', '--version').and_return(['', '', success_status])
    allow(Open3).to receive(:capture3).with('gh', 'auth', 'status').and_return(['', '', success_status])
  end

  describe '.call' do
    context 'with successful fetches' do
      before do
        allow(Open3).to receive(:capture3)
          .with('gh', 'pr', 'list', '--repo', anything, '--json', anything, '--state', 'open')
          .and_return([fixture_json, '', success_status])
      end

      it 'returns PullRequest objects for each repo' do
        prs = described_class.call(config:)

        expect(prs).to all(be_a(PrismReviews::PullRequest))
        expect(prs.size).to eq(6) # 2 PRs x 3 unique repos
      end

      it 'parses PR fields correctly' do
        prs = described_class.call(config:)
        pr = prs.first

        expect(pr.number).to eq(123)
        expect(pr.title).to eq('Add new API endpoint')
        expect(pr.author).to eq('alice')
        expect(pr.head_ref).to eq('feature/new-endpoint')
        expect(pr.labels).to eq(%w[enhancement backend])
      end

      it 'extracts both user and team reviewers' do
        prs = described_class.call(config:)
        pr = prs.first

        expect(pr.requested_reviewers).to eq(%w[bob platform-team])
      end

      it 'sets the full repo name' do
        prs = described_class.call(config:)

        repos = prs.map(&:repo).uniq
        expect(repos).to contain_exactly('acme/api-service', 'acme/admin-portal', 'acme/web-app')
      end
    end

    context 'with duplicate repos across tags' do
      let(:config) do
        PrismReviews::Configuration.new(
          github_org: 'acme',
          expertise_tags: {
            'backend' => %w[api-service],
            'ruby' => %w[api-service]
          },
          reviewers: []
        )
      end

      it 'fetches each repo only once' do
        allow(Open3).to receive(:capture3)
          .with('gh', 'pr', 'list', '--repo', 'acme/api-service', '--json', anything, '--state', 'open')
          .and_return(['[]', '', success_status])

        described_class.call(config:)

        expect(Open3).to have_received(:capture3)
          .with('gh', 'pr', 'list', '--repo', 'acme/api-service', '--json', anything, '--state', 'open')
          .once
      end
    end

    context 'when a single repo fails' do
      before do
        allow(Open3).to receive(:capture3)
          .with('gh', 'pr', 'list', '--repo', 'acme/api-service', '--json', anything, '--state', 'open')
          .and_return([fixture_json, '', success_status])
        allow(Open3).to receive(:capture3)
          .with('gh', 'pr', 'list', '--repo', 'acme/admin-portal', '--json', anything, '--state', 'open')
          .and_return(['', 'not found', failure_status])
        allow(Open3).to receive(:capture3)
          .with('gh', 'pr', 'list', '--repo', 'acme/web-app', '--json', anything, '--state', 'open')
          .and_return(['[]', '', success_status])
      end

      it 'returns PRs from successful repos' do
        prs = described_class.call(config:)

        expect(prs.size).to eq(2) # only from api-service
        expect(prs.map(&:repo).uniq).to eq(['acme/api-service'])
      end

      it 'warns about the failed repo' do
        expect { described_class.call(config:) }
          .to output(%r{Failed to fetch PRs for acme/admin-portal}).to_stderr
      end
    end

    context 'when a repo returns no PRs' do
      before do
        allow(Open3).to receive(:capture3)
          .with('gh', 'pr', 'list', '--repo', anything, '--json', anything, '--state', 'open')
          .and_return(['[]', '', success_status])
      end

      it 'returns an empty array' do
        prs = described_class.call(config:)

        expect(prs).to eq([])
      end
    end

    context 'when gh is not installed' do
      before do
        allow(Open3).to receive(:capture3).with('gh', '--version').and_return(['', '', failure_status])
      end

      it 'raises GhNotFoundError' do
        expect { described_class.call(config:) }
          .to raise_error(PrismReviews::GhNotFoundError, /gh CLI not found/)
      end
    end

    context 'when gh is not authenticated' do
      before do
        allow(Open3).to receive(:capture3).with('gh', 'auth', 'status')
                                          .and_return(['', 'not logged in', failure_status])
      end

      it 'raises GhAuthError' do
        expect { described_class.call(config:) }
          .to raise_error(PrismReviews::GhAuthError, /not authenticated/)
      end
    end
  end
end
