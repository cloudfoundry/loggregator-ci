#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'openssl'

class MissingRequiredEnvironmentVariable < StandardError; end

class TurbulenceConfig
  attr_accessor :vars_file_path, :base_url, :network_timeout, :network_delay,
    :network_loss, :username, :password

  def initialize
    self.vars_file_path = load_or_raise('VARS_FILE_PATH')
    self.base_url = load_or_raise('TURBULENCE_API_URL')

    self.network_timeout = load_or_default('TURBULENCE_NETWORK_TIMEOUT', '60m')
    self.network_delay = load_or_default('TURBULENCE_NETWORK_DELAY', '10ms')
    self.network_loss = load_or_default('TURBULENCE_NETWORK_LOSS', '5%')

    self.username = 'turbulence'
    self.password = `bosh int vars-store/#{vars_file_path} --path=/turbulence_api_password`.chomp
  end

  private

  def load_or_raise(name)
    value = ENV[name]
    if value.nil?
      raise MissingRequiredEnvironmentVariable.new(name)
    end

    value
  end

  def load_or_default(name, default)
    ENV[name].nil? ? default : ENV[name]
  end
end

class TurbulenceClient
  def initialize(config)
    self.username = config.username
    self.password = config.password
    self.base_url = config.base_url
  end

  def create_incidents(incidents)
    incidents.each { |i| create_incident(i) }
  end

  def create_incident(incident)
    request_body = JSON.pretty_generate(incident)
    uri = URI("#{base_url}/api/v1/incidents")
    req = Net::HTTP::Post.new(uri)
    req.body = request_body
    req.content_type = 'application/json'
    resp = do_request(req)

    if !resp.kind_of?(Net::HTTPSuccess)
      puts("Failed to create incident: #{resp.inspect}")
      puts(resp.body)
      raise
    end
  end

  private

  attr_accessor :username, :password, :base_url

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
end

def network_control_incident(config, deployment, group)
  {
    "Tasks" => [{
      "Type" => "control-net",
      "Timeout" => config.network_timeout,
      "Delay" => config.network_delay,
      "Loss" => config.network_loss,
    }],
    "Selector" => {
      "Deployment" => {"Name" => deployment},
      "Group" => {"Name" => group},
    }
  }
end

puts("Loading config")
config = TurbulenceConfig.new
client = TurbulenceClient.new(config)

puts("Creating control network incidents")
client.create_incidents([
  network_control_incident(config, "cf", "doppler"),
  network_control_incident(config, "cf", "log-api"),
  network_control_incident(config, "cf", "diego-cell"),
  network_control_incident(config, "scalablesyslog", "*"),
])

puts('Done.')
