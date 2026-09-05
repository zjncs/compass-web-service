# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BaseSummary, type: :model do
  describe '.aggs_by_date' do
    let(:begin_date) { Date.new(2026, 1, 1) }
    let(:end_date) { Date.new(2026, 6, 30) }
    let(:month_aggs) do
      { aggsWithDate: { date_histogram: { field: 'grimoire_creation_date', calendar_interval: '1M' } } }
    end
    let(:quarter_aggs) do
      { aggsWithDate: { date_histogram: { field: 'grimoire_creation_date', calendar_interval: '1q' } } }
    end

    def fetched_keys
      keys = []
      allow(Rails.cache).to receive(:fetch) { |*args, &block| keys << args.first }
      keys
    end

    it 'caches different aggregations on the same date range under different keys' do
      keys = fetched_keys

      ActivitySummary.aggs_by_date(begin_date, end_date, month_aggs)
      ActivitySummary.aggs_by_date(begin_date, end_date, quarter_aggs)

      expect(keys.length).to eq(2)
      expect(keys.first).not_to eq(keys.second)
    end

    it 'reuses one key for identical aggregation requests' do
      keys = fetched_keys

      ActivitySummary.aggs_by_date(begin_date, end_date, month_aggs)
      ActivitySummary.aggs_by_date(begin_date, end_date, month_aggs)

      expect(keys.length).to eq(2)
      expect(keys.first).to eq(keys.second)
    end
  end
end
