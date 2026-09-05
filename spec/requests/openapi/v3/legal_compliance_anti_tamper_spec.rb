# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OpenAPI v3 legal compliance anti-tamper', type: :request do
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

  # Stub the metric search with a document that contains exactly the fields
  # the metrics model writes to the index for the anti-tamper check
  # (supply_chain_security_metrics_v2.py, _calc_compliance_copyright_anti_tamper).
  def stub_indexer_with_anti_tamper_document
    source = {
      'uuid' => 'metric-uuid', 'level' => 'repo', 'type' => nil,
      'label' => label, 'model_name' => 'Legal Compliance', 'period' => 'month',
      'compliance_copyright_statement_anti_tamper' => 10,
      'compliance_copyright_anti_tamper' => 10,
      'compliance_copyright_anti_tamper_detail' => '{"total_count":0,"sample_files":[]}',
      'tampering_risk' => false,
      'score' => 1.0,
      'grimoire_creation_date' => '2026-08-01',
      'metadata__enriched_on' => '2026-09-01'
    }
    allow(LegalComplianceMetric).to receive(:terms_by_metric_repo_urls).and_return(
      { 'hits' => { 'hits' => [{ '_id' => 'metric-uuid', '_source' => source }] } }
    )
    allow(LegalComplianceMetric).to receive(:count_by_metric_repo_urls).and_return(1)
  end

  def request_endpoint(path)
    post path, params: {
      access_token: access_token.token,
      label:,
      period: 'month'
    }
  end

  it 'returns the anti-tamper detail on the metric endpoint' do
    stub_indexer_with_anti_tamper_document

    request_endpoint('/api/v3/legal_compliance/compliance_copyright_anti_tamper')

    expect(response).to have_http_status(:created)
    item = JSON.parse(response.body)['items'].first
    expect(item['compliance_copyright_statement_anti_tamper']).to eq(10)
    expect(item['compliance_copyright_anti_tamper_detail']).to eq('{"total_count":0,"sample_files":[]}')
  end

  it 'returns the anti-tamper detail on the model_data endpoint' do
    stub_indexer_with_anti_tamper_document

    request_endpoint('/api/v3/legal_compliance/model_data')

    expect(response).to have_http_status(:created)
    item = JSON.parse(response.body)['items'].first
    expect(item['compliance_copyright_statement_anti_tamper']).to eq(10)
    expect(item['compliance_copyright_anti_tamper_detail']).to eq('{"total_count":0,"sample_files":[]}')
    expect(item['score']).to eq(1.0)
  end
end
