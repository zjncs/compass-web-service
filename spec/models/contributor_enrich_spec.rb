# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContributorEnrich do
  describe '.fetch_contributors_list cache key' do
    let(:repo_urls) { ['https://github.com/oss-compass/compass-web-service'] }
    let(:begin_date) { Date.new(2026, 1, 1) }
    let(:end_date) { Date.new(2026, 6, 30) }

    def collected_keys(calls)
      keys = []
      allow(Rails.cache).to receive(:fetch) { |*args| keys << args.first }
      calls.each do |label, level|
        GithubContributorEnrich.fetch_contributors_list(
          repo_urls, begin_date, end_date, label: label, level: level
        )
      end
      keys
    end

    it 'varies the cache key when label or level differ' do
      # same repos + window, as produced by the repo detail page, a community
      # page over the same repos, and a community page filtered to the repo
      keys =
        collected_keys(
          [
            ['https://github.com/oss-compass/compass-web-service', 'repo'],
            ['oss-compass-community', 'community'],
            ['https://github.com/oss-compass/compass-web-service', 'community']
          ]
        )

      expect(keys.uniq.length).to eq(3)
    end

    it 'keeps the cache key stable for identical label and level' do
      keys =
        collected_keys(
          [
            ['oss-compass-community', 'community'],
            ['oss-compass-community', 'community']
          ]
        )

      expect(keys.uniq.length).to eq(1)
    end
  end
end
