class CompetitorPricingApiClient
  def self.fetch_prices
    new.fetch_prices
  end

  def fetch_prices
    uri = URI("#{api_base_url}/prices")
    uri.query = URI.encode_www_form(api_key: api_key)

    response = Net::HTTP.get_response(uri)
    return nil unless response.code == "200"

    JSON.parse(response.body)
  rescue => e
    Rails.logger.error "Failed to fetch competitor data: #{e.message}"
    nil
  end

  private

  def api_base_url
    ENV.fetch("COMPETITOR_API_BASE_URL")
  end

  def api_key
    ENV.fetch("COMPETITOR_API_KEY")
  end
end
