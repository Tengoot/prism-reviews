# frozen_string_literal: true

require 'prism_reviews'
require 'open3'

RSpec.describe PrismReviews::StateRepo do
  let(:repo_url) { 'https://github.com/acme/prism-state.git' }
  let(:local_path) { '/tmp/prism-test-state' }
  let(:success_status) { instance_double(Process::Status, success?: true) }
  let(:failure_status) { instance_double(Process::Status, success?: false) }
  let(:fixture_json) { File.read(File.expand_path('../fixtures/rotation_state.json', __dir__)) }

  describe '.sync_and_read' do
    context 'when the repo is not yet cloned' do
      before do
        allow(File).to receive(:directory?).and_call_original
        allow(File).to receive(:directory?).with("#{local_path}/.git").and_return(false)
        allow(FileUtils).to receive(:mkdir_p)
        allow(Open3).to receive(:capture3)
          .with('git', 'clone', repo_url, local_path)
          .and_return(['', '', success_status])
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with("#{local_path}/rotation-state.json").and_return(true)
        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:read).with("#{local_path}/rotation-state.json").and_return(fixture_json)
      end

      it 'clones the repo and reads state' do
        state = described_class.sync_and_read(repo_url:, local_path:)

        expect(Open3).to have_received(:capture3).with('git', 'clone', repo_url, local_path)
        expect(state.last_assigned).to eq({ 'backend' => 'bob', 'frontend' => 'carol' })
        expect(state.skip_until).to eq({ 'dave' => '2099-12-31' })
      end
    end

    context 'when the repo is already cloned' do
      before do
        allow(File).to receive(:directory?).and_call_original
        allow(File).to receive(:directory?).with("#{local_path}/.git").and_return(true)
        allow(Open3).to receive(:capture3)
          .with('git', '-C', local_path, 'pull', '--ff-only')
          .and_return(['', '', success_status])
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with("#{local_path}/rotation-state.json").and_return(true)
        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:read).with("#{local_path}/rotation-state.json").and_return(fixture_json)
      end

      it 'pulls instead of cloning' do
        described_class.sync_and_read(repo_url:, local_path:)

        expect(Open3).to have_received(:capture3).with('git', '-C', local_path, 'pull', '--ff-only')
      end
    end

    context 'when the state file does not exist' do
      before do
        allow(File).to receive(:directory?).and_call_original
        allow(File).to receive(:directory?).with("#{local_path}/.git").and_return(true)
        allow(Open3).to receive(:capture3)
          .with('git', '-C', local_path, 'pull', '--ff-only')
          .and_return(['', '', success_status])
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with("#{local_path}/rotation-state.json").and_return(false)
      end

      it 'returns an empty RotationState' do
        state = described_class.sync_and_read(repo_url:, local_path:)

        expect(state.last_assigned).to eq({})
        expect(state.skip_until).to eq({})
      end
    end

    context 'when git clone fails' do
      before do
        allow(File).to receive(:directory?).and_call_original
        allow(File).to receive(:directory?).with("#{local_path}/.git").and_return(false)
        allow(FileUtils).to receive(:mkdir_p)
        allow(Open3).to receive(:capture3)
          .with('git', 'clone', repo_url, local_path)
          .and_return(['', 'permission denied', failure_status])
      end

      it 'raises StateRepoError' do
        expect { described_class.sync_and_read(repo_url:, local_path:) }
          .to raise_error(PrismReviews::StateRepoError, /Failed to clone/)
      end
    end

    context 'when git pull fails' do
      before do
        allow(File).to receive(:directory?).and_call_original
        allow(File).to receive(:directory?).with("#{local_path}/.git").and_return(true)
        allow(Open3).to receive(:capture3)
          .with('git', '-C', local_path, 'pull', '--ff-only')
          .and_return(['', 'conflict', failure_status])
      end

      it 'raises StateRepoError' do
        expect { described_class.sync_and_read(repo_url:, local_path:) }
          .to raise_error(PrismReviews::StateRepoError, /Failed to pull/)
      end
    end
  end

  describe '.sync_write_and_push' do
    let(:state_file_path) { "#{local_path}/rotation-state.json" }

    before do
      allow(File).to receive(:directory?).and_call_original
      allow(File).to receive(:directory?).with("#{local_path}/.git").and_return(true)
      allow(Open3).to receive(:capture3)
        .with('git', '-C', local_path, 'pull', '--ff-only')
        .and_return(['', '', success_status])
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(state_file_path).and_return(true)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(state_file_path).and_return(fixture_json)
      allow(File).to receive(:write).and_call_original
      allow(File).to receive(:write).with(state_file_path, anything)
      allow(Open3).to receive(:capture3)
        .with('git', '-C', local_path, 'add', 'rotation-state.json')
        .and_return(['', '', success_status])
      allow(Open3).to receive(:capture3)
        .with('git', '-C', local_path, 'diff', '--cached', '--quiet')
        .and_return(['', '', failure_status]) # failure = there are changes
      allow(Open3).to receive(:capture3)
        .with('git', '-C', local_path, 'commit', '-m', anything)
        .and_return(['', '', success_status])
      allow(Open3).to receive(:capture3)
        .with('git', '-C', local_path, 'push')
        .and_return(['', '', success_status])
    end

    it 'writes state, commits, and pushes' do
      described_class.sync_write_and_push(repo_url:, local_path:, message: 'test') do |state|
        state.with_last_assigned(%w[backend], 'alice')
      end

      expect(File).to have_received(:write).with(state_file_path, anything)
      expect(Open3).to have_received(:capture3).with('git', '-C', local_path, 'commit', '-m', 'test')
      expect(Open3).to have_received(:capture3).with('git', '-C', local_path, 'push')
    end

    it 'returns the new state' do
      result = described_class.sync_write_and_push(repo_url:, local_path:, message: 'test') do |state|
        state.with_last_assigned(%w[backend], 'alice')
      end

      expect(result.last_assigned['backend']).to eq('alice')
    end

    context 'when push is rejected (conflict) and retry succeeds' do
      before do
        push_count = 0
        allow(Open3).to receive(:capture3).with('git', '-C', local_path, 'push') do
          push_count += 1
          if push_count == 1
            ['', 'rejected', failure_status]
          else
            ['', '', success_status]
          end
        end
      end

      it 'retries after pulling fresh state' do
        described_class.sync_write_and_push(repo_url:, local_path:, message: 'test') do |state|
          state.with_last_assigned(%w[backend], 'alice')
        end

        expect(Open3).to have_received(:capture3)
          .with('git', '-C', local_path, 'pull', '--ff-only').twice
        expect(Open3).to have_received(:capture3)
          .with('git', '-C', local_path, 'push').twice
      end
    end

    context 'when push is rejected twice' do
      before do
        allow(Open3).to receive(:capture3)
          .with('git', '-C', local_path, 'push')
          .and_return(['', 'rejected', failure_status])
      end

      it 'raises StatePushConflictError' do
        expect do
          described_class.sync_write_and_push(repo_url:, local_path:, message: 'test') do |state|
            state.with_last_assigned(%w[backend], 'alice')
          end
        end.to raise_error(PrismReviews::StatePushConflictError)
      end
    end

    context 'when there are no changes to commit' do
      before do
        allow(Open3).to receive(:capture3)
          .with('git', '-C', local_path, 'diff', '--cached', '--quiet')
          .and_return(['', '', success_status]) # success = no changes
      end

      it 'skips commit and push' do
        described_class.sync_write_and_push(repo_url:, local_path:, message: 'test') do |state|
          state
        end

        expect(Open3).not_to have_received(:capture3).with('git', '-C', local_path, 'commit', '-m', anything)
        expect(Open3).not_to have_received(:capture3).with('git', '-C', local_path, 'push')
      end
    end
  end
end
