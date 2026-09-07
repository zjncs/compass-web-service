# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OpenAPI v3 code review quality dependency reachable', type: :request do
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

  # Stub the metric search with documents that contain exactly the fields the
  # metrics model writes to the metrics_v2_code_review_quality index
  # (supply_chain_security_metrics_v2.py):
  # - with dependency-reachable-checker data: _calc_dependency_reachable writes
  #   "dependency_reachable_detail"
  # - without data: the early return writes "detail"
  def stub_indexer_with_documents(sources)
    allow(CodeReviewQualityMetric).to receive(:terms_by_metric_repo_urls).and_return(
      { 'hits' => { 'hits' => sources.map { |s| { '_id' => s['uuid'], '_source' => s } } } }
    )
    allow(CodeReviewQualityMetric).to receive(:count_by_metric_repo_urls).and_return(sources.size)
  end

  def with_data_source
    {
      'uuid' => 'metric-uuid', 'level' => 'repo', 'type' => nil,
      'label' => label, 'model_name' => 'Code Review Quality', 'period' => 'month',
      'dependency_reachable_ok' => false,
      'dependency_unreachable_list' => ['example/unreachable-dep', 'example/other-dep'],
      'dependency_reachable_detail' => '{"unreachable_count":2,"sample":["example/unreachable-dep","example/other-dep"]}',
      'compliance_snippet_reference' => 10,
      'patent_risk_level' => 'low',
      'ecology_test_coverage' => 6.5,
      'score' => 0.9,
      'grimoire_creation_date' => '2026-08-01',
      'metadata__enriched_on' => '2026-09-01'
    }
  end

  def no_data_source
    with_data_source.merge(
      'dependency_reachable_ok' => nil,
      'dependency_unreachable_list' => [],
      'dependency_reachable_detail' => nil,
      'detail' => 'no dependency-reachable-checker data'
    )
  end

  def request_endpoint(path)
    post path, params: {
      access_token: access_token.token,
      label:,
      period: 'month'
    }
  end

  it 'returns the dependency reachable detail on the dependency_reachable endpoint' do
    stub_indexer_with_documents([with_data_source])

    request_endpoint('/api/v3/code_review_quality/dependency_reachable')

    expect(response).to have_http_status(:created)
    item = JSON.parse(response.body)['items'].first
    expect(item['dependency_reachable_ok']).to eq(false)
    expect(item['dependency_reachable_detail']).to eq('{"unreachable_count":2,"sample":["example/unreachable-dep","example/other-dep"]}')
  end

  it 'returns the dependency reachable detail on the model_data endpoint' do
    stub_indexer_with_documents([with_data_source])

    request_endpoint('/api/v3/code_review_quality/model_data')

    expect(response).to have_http_status(:created)
    item = JSON.parse(response.body)['items'].first
    expect(item['dependency_reachable_detail']).to eq('{"unreachable_count":2,"sample":["example/unreachable-dep","example/other-dep"]}')
    expect(item['score']).to eq(0.9)
  end

  it 'still returns the detail message when the dependency checker produced no data' do
    stub_indexer_with_documents([no_data_source])

    request_endpoint('/api/v3/code_review_quality/dependency_reachable')

    expect(response).to have_http_status(:created)
    item = JSON.parse(response.body)['items'].first
    expect(item['dependency_reachable_ok']).to be_nil
    expect(item['detail']).to eq('no dependency-reachable-checker data')
  end
end
