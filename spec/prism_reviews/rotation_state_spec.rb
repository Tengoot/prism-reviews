# frozen_string_literal: true

require 'prism_reviews'

RSpec.describe PrismReviews::RotationState do
  describe '#with_last_assigned' do
    it 'returns a new state with updated last_assigned for given tags' do
      state = described_class.new(last_assigned: { 'backend' => 'alice' })

      new_state = state.with_last_assigned(%w[backend frontend], 'bob')

      expect(new_state.last_assigned).to eq({ 'backend' => 'bob', 'frontend' => 'bob' })
      expect(state.last_assigned).to eq({ 'backend' => 'alice' })
    end

    it 'preserves existing tags not in the update' do
      state = described_class.new(last_assigned: { 'ops' => 'carol' })

      new_state = state.with_last_assigned(%w[backend], 'alice')

      expect(new_state.last_assigned).to eq({ 'ops' => 'carol', 'backend' => 'alice' })
    end

    it 'preserves skip_until' do
      state = described_class.new(skip_until: { 'dave' => '2099-12-31' })

      new_state = state.with_last_assigned(%w[backend], 'alice')

      expect(new_state.skip_until).to eq({ 'dave' => '2099-12-31' })
    end
  end

  describe '#with_skip_until' do
    it 'returns a new state with the person added to skip_until' do
      state = described_class.new

      new_state = state.with_skip_until('alice', '2026-04-15')

      expect(new_state.skip_until).to eq({ 'alice' => '2026-04-15' })
      expect(state.skip_until).to eq({})
    end

    it 'overwrites an existing skip for the same person' do
      state = described_class.new(skip_until: { 'alice' => '2026-04-01' })

      new_state = state.with_skip_until('alice', '2026-05-01')

      expect(new_state.skip_until).to eq({ 'alice' => '2026-05-01' })
    end

    it 'preserves last_assigned' do
      state = described_class.new(last_assigned: { 'backend' => 'bob' })

      new_state = state.with_skip_until('alice', '2026-04-15')

      expect(new_state.last_assigned).to eq({ 'backend' => 'bob' })
    end
  end

  describe '#to_h' do
    it 'serializes to a hash with string keys' do
      state = described_class.new(
        last_assigned: { 'backend' => 'alice' },
        skip_until: { 'bob' => '2026-04-01' }
      )

      expect(state.to_h).to eq({
                                 'last_assigned' => { 'backend' => 'alice' },
                                 'skip_until' => { 'bob' => '2026-04-01' }
                               })
    end

    it 'returns empty hashes for empty state' do
      state = described_class.new

      expect(state.to_h).to eq({ 'last_assigned' => {}, 'skip_until' => {} })
    end
  end
end
