#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'openssl'
require 'pry'

class MissingRequiredEnvironmentVariable < StandardError; end

class TurbulenceClient
    def initialize(username, password)
        self.username = username
        self.password = password
    end

    def do_request(request)
        request.add_field('Accept', 'application/json')
        request.basic_auth(username, password)

        Net::HTTP.start(
            request.uri.hostname,
            request.uri.port,
            use_ssl: true,
            verify_mode: OpenSSL::SSL::VERIFY_NONE
        ) do |http|
            http.request(request)
        end
    end

    private

    attr_accessor :username, :password
end

vars_file_path = ENV['VARS_FILE_PATH']
if vars_file_path.nil?
    raise MissingRequiredEnvironmentVariable.new('VARS_FILE_PATH')
end

base_url = ENV['TURBULENCE_API_URL']
if base_url.nil?
    raise MissingRequiredEnvironmentVariable.new('TURBULENCE_API_URL')
end

network_timeout = ENV['TURBULENCE_NETWORK_TIMEOUT']
if network_timeout.nil?
   network_timeout = '10m'
end

network_delay = ENV['TURBULENCE_NETWORK_DELAY']
if network_delay.nil?
   network_delay = '10ms'
end

network_loss = ENV['TURBULENCE_NETWORK_LOSS']
if network_loss.nil?
   network_loss = '5%'
end

network_schedule = ENV['TURBULENCE_NETWORK_SCHEDULE']
if network_schedule.nil?
   network_schedule = '@daily'
end

username = 'turbulence'
password = `bosh int #{vars_file_path} --path=/turbulence_api_password`.chomp

client = TurbulenceClient.new(username, password)

puts('Getting all scheduled incidents')
resp = client.do_request(
    Net::HTTP::Get.new(URI("#{base_url}/api/v1/scheduled_incidents"))
)
response = JSON.parse(resp.body)

# TODO: Check response status code


puts("Deleting #{response.length} scheduled incidents")
response.each do |schedule|
    uri = URI("#{base_url}/api/v1/scheduled_incidents/#{schedule['ID']}")
    client.do_request(
        Net::HTTP::Delete.new(uri)
    )
    # TODO: Check response status codes
end

request_body = JSON.pretty_generate({
    "Schedule" => network_schedule,
    "Incident" => {
        "Tasks" => [{
            "Type" => "control-net",
            "Timeout" => network_timeout,
            "Delay" => network_delay,
            "Loss" => network_loss,
        }],
    }
})

puts('Creating control network scheduled incident with:')
puts(request_body)

uri = URI("#{base_url}/api/v1/scheduled_incidents")
req = Net::HTTP::Post.new(uri)
req.body = request_body
req.content_type = 'application/json'
resp = client.do_request(req)

if !resp.kind_of?(Net::HTTPSuccess)
    puts("Failed to create control network scheduled incident: #{resp.inspect}")
    puts(resp.body)
    raise
end

# TODO: Check response status code
puts('Created control network scheduled incident')
puts('Done.')
