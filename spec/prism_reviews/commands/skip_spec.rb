# frozen_string_literal: true

require 'prism_reviews'
require 'dry/cli'
require 'prism_reviews/commands/skip'

RSpec.describe PrismReviews::Commands::Skip do
  let(:valid_config) { File.expand_path('../../fixtures/valid_config.yml', __dir__) }
  let(:empty_state) { PrismReviews::RotationState.new }

  before do
    allow(PrismReviews::StateRepo).to receive(:sync_write_and_push) do |**_kwargs, &block|
      block.call(empty_state)
    end
  end

  it 'skips a reviewer with a date' do
    expect { described_class.new.call(person: 'alice', until: '2026-04-15', config: valid_config) }
      .to output(/alice will be skipped until 2026-04-15/).to_stdout
  end

  it 'updates skip_until in state' do
    described_class.new.call(person: 'alice', until: '2026-04-15', config: valid_config)

    expect(PrismReviews::StateRepo).to have_received(:sync_write_and_push) do |**_kwargs, &block|
      new_state = block.call(empty_state)
      expect(new_state.skip_until['alice']).to eq('2026-04-15')
    end
  end

  it 'defaults to indefinite skip when no date given' do
    described_class.new.call(person: 'alice', config: valid_config)

    expect(PrismReviews::StateRepo).to have_received(:sync_write_and_push) do |**_kwargs, &block|
      new_state = block.call(empty_state)
      expect(new_state.skip_until['alice']).to eq('2099-12-31')
    end
  end

  it 'raises for unknown reviewer' do
    expect { described_class.new.call(person: 'unknown', config: valid_config) }
      .to output(/Unknown reviewer: unknown/).to_stderr
      .and raise_error(SystemExit)
  end

  it 'raises for invalid date' do
    expect { described_class.new.call(person: 'alice', until: 'not-a-date', config: valid_config) }
      .to output(/Invalid date format/).to_stderr
      .and raise_error(SystemExit)
  end
end
