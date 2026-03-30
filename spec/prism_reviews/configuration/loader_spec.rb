# frozen_string_literal: true

require 'prism_reviews/configuration'
require 'tempfile'

RSpec.describe PrismReviews::Configuration::Loader do
  let(:valid_config_path) { File.expand_path('../../fixtures/valid_config.yml', __dir__) }
  let(:minimal_config_path) { File.expand_path('../../fixtures/minimal_config.yml', __dir__) }

  def write_temp_config(yaml_string)
    file = Tempfile.new(['config', '.yml'])
    file.write(yaml_string)
    file.close
    file
  end

  describe '.call' do
    context 'with a valid full config' do
      subject(:config) { described_class.call(path: valid_config_path) }

      it 'loads expertise_tags as a Hash' do
        expect(config.expertise_tags).to be_a(Hash)
        expect(config.expertise_tags.keys).to contain_exactly('backend', 'frontend', 'flink', 'test')
      end

      it 'loads reviewers as Reviewer objects' do
        expect(config.reviewers).to all(be_a(PrismReviews::Configuration::Reviewer))
        expect(config.reviewers.size).to eq(5)
        expect(config.reviewers.map(&:name)).to contain_exactly('alice', 'bob', 'carol', 'dave', 'eve')
      end

      it 'loads reviewer details correctly' do
        alice = config.reviewers.find { |r| r.name == 'alice' }
        expect(alice.github).to eq('alice-gh')
        expect(alice.tags).to eq(%w[backend flink])
        expect(alice.maintainer).to eq([])
      end

      it 'defaults maintainer to empty array when omitted' do
        bob = config.reviewers.find { |r| r.name == 'bob' }
        expect(bob.maintainer).to eq([])
      end

      it 'loads exclusion rules' do
        expect(config.exclude).to all(be_a(PrismReviews::Configuration::ExclusionRule))
        expect(config.exclude.size).to eq(2)
        expect(config.exclude.first.pattern).to eq('dependabot/*')
        expect(config.exclude.first.scope).to eq('expertise')
      end

      it 'loads notifications' do
        expect(config.notifications).to be_a(PrismReviews::Configuration::Notifications)
        expect(config.notifications.enabled).to be true
        expect(config.notifications.notify_method).to eq('terminal-notifier')
        expect(config.notifications.poll_interval_minutes).to eq(15)
      end

      it 'loads working hours' do
        wh = config.notifications.working_hours
        expect(wh).to be_a(PrismReviews::Configuration::WorkingHours)
        expect(wh.start_time).to eq('09:00')
        expect(wh.end_time).to eq('18:00')
        expect(wh.days).to eq(%w[mon tue wed thu fri])
      end

      it 'loads state_repo' do
        expect(config.state_repo).to eq('acme/prism-state')
      end

      it 'loads github_org' do
        expect(config.github_org).to eq('acme')
      end
    end

    context 'with a minimal config' do
      subject(:config) { described_class.call(path: minimal_config_path) }

      it 'loads with only required fields' do
        expect(config.expertise_tags.keys).to eq(['backend'])
        expect(config.reviewers.size).to eq(1)
      end

      it 'defaults exclude to empty array' do
        expect(config.exclude).to eq([])
      end

      it 'defaults notifications to nil' do
        expect(config.notifications).to be_nil
      end

      it 'defaults state_repo to nil' do
        expect(config.state_repo).to be_nil
      end
    end

    context 'when config file is missing' do
      it 'raises ConfigNotFoundError with path in message' do
        expect { described_class.call(path: '/nonexistent/config.yml') }
          .to raise_error(PrismReviews::ConfigNotFoundError, %r{/nonexistent/config\.yml})
      end
    end

    context 'with missing required fields' do
      it 'raises when expertise_tags is missing' do
        file = write_temp_config("reviewers:\n  alice:\n    github: alice-gh\n    tags: [backend]\n")
        expect { described_class.call(path: file.path) }
          .to raise_error(PrismReviews::ConfigValidationError, /expertise_tags/)
      ensure
        file.unlink
      end

      it 'raises when reviewers is missing' do
        file = write_temp_config("expertise_tags:\n  backend: [api-service]\n")
        expect { described_class.call(path: file.path) }
          .to raise_error(PrismReviews::ConfigValidationError, /reviewers/)
      ensure
        file.unlink
      end

      it 'collects multiple errors' do
        file = write_temp_config("---\n")
        expect { described_class.call(path: file.path) }
          .to raise_error(PrismReviews::ConfigValidationError, /expertise_tags.*reviewers/m)
      ensure
        file.unlink
      end
    end

    context 'with invalid expertise_tags' do
      it 'raises when expertise_tags is not a Hash' do
        yaml = "github_org: test\nexpertise_tags: [backend]\nreviewers:\n  a:\n    github: a\n    tags: [x]\n"
        file = write_temp_config(yaml)
        expect { described_class.call(path: file.path) }
          .to raise_error(PrismReviews::ConfigValidationError, /expertise_tags/)
      ensure
        file.unlink
      end

      it 'raises when expertise_tags is empty' do
        yaml = "github_org: test\nexpertise_tags: {}\nreviewers:\n  a:\n    github: a\n    tags: [x]\n"
        file = write_temp_config(yaml)
        expect { described_class.call(path: file.path) }
          .to raise_error(PrismReviews::ConfigValidationError, /expertise_tags must be filled/)
      ensure
        file.unlink
      end

      it 'raises when a tag value is not an array' do
        yaml = <<~YAML
          github_org: test
          expertise_tags:
            backend: not-an-array
          reviewers:
            a:
              github: a
              tags: [backend]
        YAML
        file = write_temp_config(yaml)
        expect { described_class.call(path: file.path) }
          .to raise_error(PrismReviews::ConfigValidationError, /expertise_tags\.backend/)
      ensure
        file.unlink
      end
    end

    context 'with invalid reviewers' do
      it 'raises when reviewer is missing github' do
        yaml = "github_org: test\nexpertise_tags:\n  backend: [repo]\nreviewers:\n  alice:\n    tags: [backend]\n"
        file = write_temp_config(yaml)
        expect { described_class.call(path: file.path) }
          .to raise_error(PrismReviews::ConfigValidationError, /alice.*github/m)
      ensure
        file.unlink
      end

      it 'raises when reviewer is missing tags' do
        yaml = "github_org: test\nexpertise_tags:\n  backend: [repo]\nreviewers:\n  alice:\n    github: alice-gh\n"
        file = write_temp_config(yaml)
        expect { described_class.call(path: file.path) }
          .to raise_error(PrismReviews::ConfigValidationError, /alice.*tags/m)
      ensure
        file.unlink
      end
    end

    context 'with unknown reviewer tags' do
      it 'warns but does not raise' do
        yaml = <<~YAML
          github_org: test
          expertise_tags:
            backend: [repo]
          reviewers:
            alice:
              github: alice-gh
              tags: [backend, unknown_tag]
        YAML
        file = write_temp_config(yaml)
        expect { described_class.call(path: file.path) }
          .to output(/unknown tag 'unknown_tag'/).to_stderr
      ensure
        file.unlink
      end
    end

    context 'with invalid exclude entries' do
      it 'raises when entry is missing pattern' do
        yaml = <<~YAML
          github_org: test
          expertise_tags:
            backend: [repo]
          reviewers:
            alice:
              github: alice-gh
              tags: [backend]
          exclude:
            - scope: expertise
        YAML
        file = write_temp_config(yaml)
        expect { described_class.call(path: file.path) }
          .to raise_error(PrismReviews::ConfigValidationError, /exclude.*pattern/m)
      ensure
        file.unlink
      end

      it 'raises when scope is invalid' do
        yaml = <<~YAML
          github_org: test
          expertise_tags:
            backend: [repo]
          reviewers:
            alice:
              github: alice-gh
              tags: [backend]
          exclude:
            - pattern: "dependabot/*"
              scope: invalid
        YAML
        file = write_temp_config(yaml)
        expect { described_class.call(path: file.path) }
          .to raise_error(PrismReviews::ConfigValidationError, /scope must be one of/)
      ensure
        file.unlink
      end

      it 'loads repos field on exclusion rules' do
        yaml = <<~YAML
          github_org: test
          expertise_tags:
            backend: [repo]
          reviewers:
            alice:
              github: alice-gh
              tags: [backend]
          exclude:
            - pattern: "dependabot/*"
              scope: all
              repos: [api-service]
        YAML
        file = write_temp_config(yaml)
        config = described_class.call(path: file.path)
        expect(config.exclude.first.repos).to eq(%w[api-service])
      ensure
        file.unlink
      end

      it 'defaults repos to empty array when omitted' do
        yaml = <<~YAML
          github_org: test
          expertise_tags:
            backend: [repo]
          reviewers:
            alice:
              github: alice-gh
              tags: [backend]
          exclude:
            - pattern: "dependabot/*"
              scope: expertise
        YAML
        file = write_temp_config(yaml)
        config = described_class.call(path: file.path)
        expect(config.exclude.first.repos).to eq([])
      ensure
        file.unlink
      end

      it 'raises when entry is missing scope' do
        yaml = <<~YAML
          github_org: test
          expertise_tags:
            backend: [repo]
          reviewers:
            alice:
              github: alice-gh
              tags: [backend]
          exclude:
            - pattern: "dependabot/*"
        YAML
        file = write_temp_config(yaml)
        expect { described_class.call(path: file.path) }
          .to raise_error(PrismReviews::ConfigValidationError, /exclude.*scope/m)
      ensure
        file.unlink
      end
    end
  end
end
