# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require_relative 'rotation_state'

module PrismReviews
  class StateRepo
    STATE_FILE = 'rotation-state.json'
    DEFAULT_LOCAL_PATH = File.join(Dir.home, '.cache', 'prism', 'state').freeze

    def self.sync_and_read(repo_url:, local_path: DEFAULT_LOCAL_PATH)
      new(repo_url, local_path).sync_and_read
    end

    def self.sync_write_and_push(repo_url:, message:, local_path: DEFAULT_LOCAL_PATH, &)
      new(repo_url, local_path).sync_write_and_push(message, &)
    end

    def initialize(repo_url, local_path)
      @repo_url = repo_url
      @local_path = local_path
    end

    def sync_and_read
      clone_or_pull
      read_state
    end

    def sync_write_and_push(message)
      clone_or_pull
      new_state = yield read_state
      write_and_push(new_state, message)
      new_state
    rescue StatePushConflictError
      git_pull
      new_state = yield read_state
      write_and_push(new_state, message)
      new_state
    end

    private

    def clone_or_pull
      if git_repo?
        git_pull
      else
        git_clone
      end
    end

    def git_repo?
      File.directory?(File.join(@local_path, '.git'))
    end

    def git_clone
      FileUtils.mkdir_p(File.dirname(@local_path))
      _, stderr, status = Open3.capture3('git', 'clone', @repo_url, @local_path)
      raise StateRepoError, "Failed to clone state repo: #{stderr.strip}" unless status.success?
    end

    def git_pull
      _, stderr, status = Open3.capture3('git', '-C', @local_path, 'pull', '--ff-only')
      raise StateRepoError, "Failed to pull state repo: #{stderr.strip}" unless status.success?
    end

    def read_state
      state_path = File.join(@local_path, STATE_FILE)
      return RotationState.new unless File.exist?(state_path)

      data = JSON.parse(File.read(state_path))
      RotationState.new(
        last_assigned: data.fetch('last_assigned', {}),
        skip_until: data.fetch('skip_until', {})
      )
    end

    def write_and_push(state, message)
      write_state(state)
      return unless changes_staged?

      git_commit(message)
      git_push
    end

    def write_state(state)
      state_path = File.join(@local_path, STATE_FILE)
      File.write(state_path, "#{JSON.pretty_generate(state.to_h)}\n")
      git_add
    end

    def changes_staged?
      _, _, status = Open3.capture3('git', '-C', @local_path, 'diff', '--cached', '--quiet')
      !status.success?
    end

    def git_add
      _, stderr, status = Open3.capture3('git', '-C', @local_path, 'add', STATE_FILE)
      raise StateRepoError, "Failed to stage state file: #{stderr.strip}" unless status.success?
    end

    def git_commit(message)
      _, stderr, status = Open3.capture3('git', '-C', @local_path, 'commit', '-m', message)
      raise StateRepoError, "Failed to commit: #{stderr.strip}" unless status.success?
    end

    def git_push
      _, stderr, status = Open3.capture3('git', '-C', @local_path, 'push')
      if !status.success? && stderr.include?('rejected')
        raise StatePushConflictError,
              "Push rejected — retry with: #{stderr.strip}"
      end
      raise StateRepoError, "Failed to push: #{stderr.strip}" unless status.success?
    end
  end
end
