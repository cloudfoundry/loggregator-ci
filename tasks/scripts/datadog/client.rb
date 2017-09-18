require 'net/http'
require 'json'

# Usage:
#   require_relative 'loggregator-ci/tasks/scripts/datadog/client.rb'
#
#   client = DataDog::Client.new('api-key')
#
#   client.send_gauge_metrics(
#     {metric_one: 23, metric_two: 43},
#     'https://some-domain.example',
#     {tag_one: 'some-value', tag_two: 'another-value'}
#   )
#
#   client.create_event('Event Title', 'Event Body')
module DataDog
  class Client
    API_URL = 'https://app.datadoghq.com/api/v1'.freeze

    def initialize(api_key, debug: false)
      self.api_key = api_key
      self.debug = debug
    end

    def send_gauge_metrics(metrics, host, tags={})
      body = {
        series: build_gauge_metrics(metrics, host, tags),
      }

      if debug
        puts "send_gauge_metrics body: #{JSON.dump(body)}"
      end

      post_request("#{API_URL}/series?api_key=#{api_key}", body)
    end

    def create_event(title, text, tags={})
      body = {
        title: title,
        text: text,
        tags: convert_tags(tags),
      }

      post_request("#{API_URL}/events?api_key=#{api_key}", body)
    end

    private

    attr_accessor :api_key, :debug

    def post_request(url, body)
      request = Net::HTTP::Post.new(URI(url))
      request.body = JSON.dump(body)
      request.content_type = 'application/json'

      do_request(request)
    end

    def do_request(request)
      resp = Net::HTTP.start(
        request.uri.hostname,
        request.uri.port,
        use_ssl: request.uri.scheme == 'https'
      ) do |http|
        http.request(request)
      end

      if debug
        puts "Response status code: #{resp.code}"
        puts "Response body: #{resp.body}"
      end

      resp
    end

    def convert_tags(tags={})
      tags.map { |k, v| "#{k}:#{v}" }
    end

    def build_gauge_metrics(metrics, host, tags={})
      ts = Time.now.to_i
      metrics.map do |name, value|
        {
          metric: name,
          points: [[ts, value]],
          type: "gauge",
          host: host,
          tags: convert_tags(tags),
        }
      end
    end
  end
end
