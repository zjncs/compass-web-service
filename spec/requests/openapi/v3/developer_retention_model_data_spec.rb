# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OpenAPI v3 developer retention model_data', type: :request do
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

  # Stub the metric search so the endpoint works against a document that
  # contains exactly the fields the metrics model writes to the index.
  def stub_indexer(indexer, metric_fields)
    source = {
      'uuid' => 'metric-uuid', 'level' => 'repo', 'type' => nil,
      'label' => label, 'model_name' => 'Model', 'period' => 'month',
      'grimoire_creation_date' => '2026-08-01',
      'metadata__enriched_on' => '2026-09-01'
    }.merge(metric_fields)

    allow(indexer).to receive(:terms_by_metric_repo_urls).and_return(
      { 'hits' => { 'hits' => [{ '_id' => 'metric-uuid', '_source' => source }] } }
    )
    allow(indexer).to receive(:count_by_metric_repo_urls).and_return(1)
  end

  def request_model_data(path)
    post path, params: {
      access_token: access_token.token,
      label:,
      period: 'month'
    }
  end

  it 'returns the core retention metric fields stored by the metrics model' do
    stub_indexer(CoreRetentionMetric, {
                   'org_code_core_retention' => 0.9,
                   'org_issue_core_retention' => 0.8,
                   'individual_code_core_retention' => 0.7,
                   'individual_issue_core_retention' => 0.6,
                   'score' => 0.75
                 })

    request_model_data('/api/v3/core_retention/model_data')

    expect(response).to have_http_status(:created)
    item = JSON.parse(response.body)['items'].first
    expect(item['org_code_core_retention']).to eq(0.9)
    expect(item['org_issue_core_retention']).to eq(0.8)
    expect(item['individual_code_core_retention']).to eq(0.7)
    expect(item['individual_issue_core_retention']).to eq(0.6)
    expect(item['score']).to eq(0.75)
  end

  it 'returns the core loss metric fields stored by the metrics model' do
    stub_indexer(CoreLossMetric, {
                   'org_code_core_loss' => 3,
                   'org_issue_core_loss' => 2,
                   'individual_code_core_loss' => 1,
                   'individual_issue_core_loss' => 0,
                   'score' => 0.5
                 })

    request_model_data('/api/v3/core_loss/model_data')

    expect(response).to have_http_status(:created)
    item = JSON.parse(response.body)['items'].first
    expect(item['org_code_core_loss']).to eq(3)
    expect(item['org_issue_core_loss']).to eq(2)
    expect(item['individual_code_core_loss']).to eq(1)
    expect(item['individual_issue_core_loss']).to eq(0)
    expect(item['score']).to eq(0.5)
  end

  it 'returns the core churn metric fields stored by the metrics model' do
    stub_indexer(CoreChurnMetric, {
                   'org_code_core_churn' => 0.1,
                   'org_issue_core_churn' => 0.2,
                   'individual_code_core_churn' => 0.3,
                   'individual_issue_core_churn' => 0.4,
                   'score' => 0.6
                 })

    request_model_data('/api/v3/core_churn/model_data')

    expect(response).to have_http_status(:created)
    item = JSON.parse(response.body)['items'].first
    expect(item['org_code_core_churn']).to eq(0.1)
    expect(item['org_issue_core_churn']).to eq(0.2)
    expect(item['individual_code_core_churn']).to eq(0.3)
    expect(item['individual_issue_core_churn']).to eq(0.4)
    expect(item['score']).to eq(0.6)
  end
end
