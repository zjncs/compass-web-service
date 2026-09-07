# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OpenAPI v3 metric search period filter', type: :request do
  before do
    ENV['PRIMARY_DOMAINS'] = 'www.example.com'
    allow(Openapi::SharedParams::RateLimiter).to receive(:check_token!)
    # User#expire_cache writes to the Riak KV store on save.
    allow(CompassRiak).to receive(:delete)
  end

  let(:user) { create(:user) }
  let!(:access_token) { AccessToken.create!(user:) }
  let(:label) { 'https://github.com/example/repo' }

  after { ENV['PRIMARY_DOMAINS'] = '' }

  # The metrics model writes one document per period into the same index
  # (base_metrics_model_v2.py metrics_model_enrich), so the period requested
  # by the API caller has to become a query filter, like the v2 model search
  # helper already does (extract_search_model_params!).
  let(:quarter_source) do
    {
      'uuid' => 'metric-uuid-quarter', 'level' => 'repo', 'type' => nil,
      'label' => label, 'model_name' => 'Community Popularity', 'period' => 'quarter',
      'stars_added' => 5, 'stars_total' => 100, 'score' => 1.0,
      'grimoire_creation_date' => '2026-08-01', 'metadata__enriched_on' => '2026-09-01'
    }
  end

  def stub_indexer_with_quarter_document
    allow(CommunityPopularityMetric).to receive(:terms_by_metric_repo_urls).and_return(
      { 'hits' => { 'hits' => [{ '_id' => 'metric-uuid-quarter', '_source' => quarter_source }] } }
    )
    allow(CommunityPopularityMetric).to receive(:count_by_metric_repo_urls).and_return(1)
  end

  def request_stars_with_period(period)
    post '/api/v3/community_popularity/stars', params: {
      access_token: access_token.token,
      label:,
      period:
    }
  end

  it 'applies the requested period as a filter on the metric query' do
    stub_indexer_with_quarter_document

    request_stars_with_period('quarter')

    expect(response).to have_http_status(:created)
    expect(CommunityPopularityMetric).to have_received(:terms_by_metric_repo_urls)
      .with(anything, anything, anything, hash_including(
                                       filter_opts: [having_attributes(type: 'period', values: %w[quarter])]
                                     ))
  end

  it 'applies the requested period as a filter on the count query' do
    stub_indexer_with_quarter_document

    request_stars_with_period('quarter')

    expect(response).to have_http_status(:created)
    expect(CommunityPopularityMetric).to have_received(:count_by_metric_repo_urls)
      .with(anything, anything, anything, hash_including(
                                       filter_opts: [having_attributes(type: 'period', values: %w[quarter])]
                                     ))
  end

  it 'returns the documents of the requested period' do
    stub_indexer_with_quarter_document

    request_stars_with_period('quarter')

    expect(response).to have_http_status(:created)
    item = JSON.parse(response.body)['items'].first
    expect(item['period']).to eq('quarter')
    expect(item['stars_added']).to eq(5)
  end
end
