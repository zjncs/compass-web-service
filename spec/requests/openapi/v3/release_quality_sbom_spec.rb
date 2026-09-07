# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OpenAPI v3 release quality sbom', type: :request do
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
  # metrics model writes to the metrics_v2_release_quality index
  # (supply_chain_security_metrics_v2.py):
  # - with release-checker data: _calc_sbom_in_release writes "sbom_detail"
  # - without release-checker data: the early return writes "detail"
  def stub_indexer_with_documents(sources)
    allow(ReleaseQualityMetric).to receive(:terms_by_metric_repo_urls).and_return(
      { 'hits' => { 'hits' => sources.map { |s| { '_id' => s['uuid'], '_source' => s } } } }
    )
    allow(ReleaseQualityMetric).to receive(:count_by_metric_repo_urls).and_return(sources.size)
  end

  def with_data_source
    {
      'uuid' => 'metric-uuid', 'level' => 'repo', 'type' => nil,
      'label' => label, 'model_name' => 'Release Quality', 'period' => 'month',
      'sbom_in_release' => true,
      'sbom_detail' => '[{"release":"v1.0.0","content_files":["sbom.cdx.json"]}]',
      'security_binary_artifact' => 10,
      'security_package_sig' => 10,
      'lifecycle_release_note' => 10,
      'score' => 1.0,
      'grimoire_creation_date' => '2026-08-01',
      'metadata__enriched_on' => '2026-09-01'
    }
  end

  def no_data_source
    with_data_source.merge(
      'sbom_in_release' => 10,
      'sbom_detail' => nil,
      'detail' => 'no release-checker data'
    )
  end

  def request_endpoint(path)
    post path, params: {
      access_token: access_token.token,
      label:,
      period: 'month'
    }
  end

  it 'returns the SBOM detail on the sbom_in_release endpoint' do
    stub_indexer_with_documents([with_data_source])

    request_endpoint('/api/v3/release_quality/sbom_in_release')

    expect(response).to have_http_status(:created)
    item = JSON.parse(response.body)['items'].first
    expect(item['sbom_in_release']).to eq(true)
    expect(item['sbom_detail']).to eq('[{"release":"v1.0.0","content_files":["sbom.cdx.json"]}]')
  end

  it 'returns the SBOM detail on the model_data endpoint' do
    stub_indexer_with_documents([with_data_source])

    request_endpoint('/api/v3/release_quality/model_data')

    expect(response).to have_http_status(:created)
    item = JSON.parse(response.body)['items'].first
    expect(item['sbom_in_release']).to eq(true)
    expect(item['sbom_detail']).to eq('[{"release":"v1.0.0","content_files":["sbom.cdx.json"]}]')
    expect(item['score']).to eq(1.0)
  end

  it 'still returns the detail message when the release checker produced no data' do
    stub_indexer_with_documents([no_data_source])

    request_endpoint('/api/v3/release_quality/sbom_in_release')

    expect(response).to have_http_status(:created)
    item = JSON.parse(response.body)['items'].first
    expect(item['sbom_in_release']).to eq(10)
    expect(item['detail']).to eq('no release-checker data')
  end
end
