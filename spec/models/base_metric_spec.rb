# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BaseMetric, type: :model do
  describe '.aggs_repo_by_date' do
    let(:repo_url) { 'https://github.com/oss-compass/compass-web-service' }
    let(:begin_date) { Date.new(2026, 1, 1) }
    let(:end_date) { Date.new(2026, 6, 30) }
    let(:avg_score_aggs) do
      { avg_score: { avg: { field: 'score' } } }
    end
    let(:interval_aggs) do
      { aggsWithDate: { date_histogram: { field: 'grimoire_creation_date', calendar_interval: '1M' } } }
    end

    def fetched_keys
      keys = []
      allow(Rails.cache).to receive(:fetch) { |*args, &block| keys << args.first }
      keys
    end

    it 'caches different aggregations on the same repo window under different keys' do
      keys = fetched_keys

      ActivityMetric.aggs_repo_by_date(repo_url, begin_date, end_date, avg_score_aggs, type: nil)
      ActivityMetric.aggs_repo_by_date(repo_url, begin_date, end_date, interval_aggs, type: nil)

      expect(keys.length).to eq(2)
      expect(keys.first).not_to eq(keys.second)
    end

    it 'reuses one key for identical aggregation requests' do
      keys = fetched_keys

      ActivityMetric.aggs_repo_by_date(repo_url, begin_date, end_date, avg_score_aggs, type: nil)
      ActivityMetric.aggs_repo_by_date(repo_url, begin_date, end_date, avg_score_aggs, type: nil)

      expect(keys.length).to eq(2)
      expect(keys.first).to eq(keys.second)
    end
  end

  describe 'GroupActivityMetric.aggs_repo_by_date' do
    let(:repo_url) { 'https://github.com/oss-compass/compass-web-service' }
    let(:begin_date) { Date.new(2026, 1, 1) }
    let(:end_date) { Date.new(2026, 6, 30) }
    let(:aggs) do
      { aggsWithDate: { date_histogram: { field: 'grimoire_creation_date', calendar_interval: '1M' } } }
    end

    def fetched_keys
      keys = []
      allow(Rails.cache).to receive(:fetch) { |*args, &block| keys << args.first }
      keys
    end

    it 'separates different types and aggregations in the cache key' do
      keys = fetched_keys

      GroupActivityMetric.aggs_repo_by_date(repo_url, begin_date, end_date, aggs, type: nil)
      GroupActivityMetric.aggs_repo_by_date(repo_url, begin_date, end_date, aggs, type: 'software-artifact')
      GroupActivityMetric.aggs_repo_by_date(repo_url, begin_date, end_date, { avg_score: { avg: { field: 'score' } } }, type: nil)

      expect(keys.length).to eq(3)
      expect(keys.uniq.length).to eq(3)
    end
  end
end
