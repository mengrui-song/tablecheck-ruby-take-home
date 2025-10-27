require 'rails_helper'

RSpec.describe CompetitorPricingApiClient, type: :service do
  let(:api_base_url) { 'https://api.competitor.com' }
  let(:api_key) { 'test_api_key_123' }
  let(:client) { CompetitorPricingApiClient.new }

  before do
    ENV['COMPETITOR_API_BASE_URL'] = api_base_url
    ENV['COMPETITOR_API_KEY'] = api_key
  end

  after do
    ENV.delete('COMPETITOR_API_BASE_URL')
    ENV.delete('COMPETITOR_API_KEY')
  end

  describe '.fetch_prices' do
    it 'delegates to instance method' do
      allow(CompetitorPricingApiClient).to receive(:new).and_return(instance_double(CompetitorPricingApiClient, fetch_prices: []))
      result = CompetitorPricingApiClient.fetch_prices
      expect(result).to eq([])
    end
  end

  describe '#fetch_prices' do
    let(:successful_response_body) do
      [
        { "name" => "MC Hammer Pants", "price" => 2500 },
        { "name" => "Air Jordans", "price" => 15000 }
      ].to_json
    end

    context 'when API request is successful' do
      before do
        stub_request(:get, "#{api_base_url}/prices?api_key=#{api_key}")
          .to_return(status: 200, body: successful_response_body, headers: {})
      end

      it 'returns parsed JSON data' do
        result = client.fetch_prices
        expect(result).to eq([
          { "name" => "MC Hammer Pants", "price" => 2500 },
          { "name" => "Air Jordans", "price" => 15000 }
        ])
      end

      it 'makes GET request to correct URL with API key' do
        client.fetch_prices
        expect(WebMock).to have_requested(:get, "#{api_base_url}/prices?api_key=#{api_key}")
      end
    end

    context 'when API returns non-200 status' do
      before do
        stub_request(:get, "#{api_base_url}/prices?api_key=#{api_key}")
          .to_return(status: 404, body: 'Not Found')
      end

      it 'returns nil' do
        result = client.fetch_prices
        expect(result).to be_nil
      end
    end

    context 'when API returns invalid JSON' do
      before do
        stub_request(:get, "#{api_base_url}/prices?api_key=#{api_key}")
          .to_return(status: 200, body: 'invalid json')
      end

      it 'returns nil and logs error' do
        expect(Rails.logger).to receive(:error).with(/Failed to fetch competitor data/)
        result = client.fetch_prices
        expect(result).to be_nil
      end
    end

    context 'when network error occurs' do
      before do
        stub_request(:get, "#{api_base_url}/prices?api_key=#{api_key}")
          .to_raise(StandardError.new('Network timeout'))
      end

      it 'returns nil and logs error' do
        expect(Rails.logger).to receive(:error).with('Failed to fetch competitor data: Network timeout')
        result = client.fetch_prices
        expect(result).to be_nil
      end
    end

    context 'when API returns empty response' do
      before do
        stub_request(:get, "#{api_base_url}/prices?api_key=#{api_key}")
          .to_return(status: 200, body: '[]')
      end

      it 'returns empty array' do
        result = client.fetch_prices
        expect(result).to eq([])
      end
    end

    context 'when API returns 500 error' do
      before do
        stub_request(:get, "#{api_base_url}/prices?api_key=#{api_key}")
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'returns nil' do
        result = client.fetch_prices
        expect(result).to be_nil
      end
    end
  end

  describe 'private methods' do
    describe '#api_base_url' do
      it 'returns value from environment variable' do
        expect(client.send(:api_base_url)).to eq(api_base_url)
      end

      context 'when environment variable is not set' do
        before { ENV.delete('COMPETITOR_API_BASE_URL') }

        it 'raises KeyError' do
          expect { client.send(:api_base_url) }.to raise_error(KeyError)
        end
      end
    end

    describe '#api_key' do
      it 'returns value from environment variable' do
        expect(client.send(:api_key)).to eq(api_key)
      end

      context 'when environment variable is not set' do
        before { ENV.delete('COMPETITOR_API_KEY') }

        it 'raises KeyError' do
          expect { client.send(:api_key) }.to raise_error(KeyError)
        end
      end
    end
  end
end
