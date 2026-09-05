class BaseSummary < BaseIndex
  def self.query_by_date(begin_date, end_date, page: 1, per: 60)
    Rails.cache.fetch(
      "#{self.name}-#{__method__}-#{begin_date}-#{end_date}-#{page}-#{per}",
      expires_in: CacheTTL
    ) do
    self
      .page(page)
      .per(per)
      .range(:grimoire_creation_date, gte: begin_date, lte: end_date)
      .sort(grimoire_creation_date: :asc)
      .execute
      .raw_response
    end
  end

  def self.aggs_by_date(begin_date, end_date, aggs)
    # aggs must be part of the key: the summary chart queries aggregate the
    # same summary index with date histograms whose interval follows the
    # caller's interval argument, and one cached response must never be
    # served for another
    Rails.cache.fetch(
      "#{self.name}-#{__method__}-#{begin_date}-#{end_date}-#{Digest::MD5.hexdigest(aggs.to_json)}",
      expires_in: CacheTTL
    ) do
    self
      .page(1)
      .per(1)
      .range(:grimoire_creation_date, gte: begin_date, lte: end_date)
      .sort(grimoire_creation_date: :asc)
      .aggregate(aggs)
      .execute
      .raw_response
    end
  end
end
