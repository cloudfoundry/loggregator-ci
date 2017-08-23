#!/usr/bin/env ruby

require 'json'

setting_names = %w{
  API_VERSION
  CLIENT_ID
  DIEGO_CELL_INSTANCE_COUNT
  DOPPLER_INSTANCE_COUNT
  EVENT_COUNTER_COUNT
  INSTANCES_PER_APP
  LOGS_PER_SECOND
  LOG_API_INSTANCE_COUNT
  LOG_BYTES
  METRICS_PER_SECOND
  METRIC_EMITTER_COUNT
  NUMBER_OF_APPS
  ORG
  ROUTER_COUNT
  SPACE
  SYSTEM_DOMAIN
}

settings = ENV.select { |k, _| setting_names.include?(k) }
settings.each do |k, v|
  if v.to_i != 0
    settings[k] = v.to_i
  end
end

# Ensure all environment settings are given. This will raise an error if the
# key is not found.
setting_names.each { |name| settings.fetch(name) }

File.open('deployment-settings/settings.json', 'w') do |f|
  f.write(JSON.pretty_generate(settings))
end
