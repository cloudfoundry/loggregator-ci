#!/usr/bin/env ruby

require 'json'
require "#{Dir.pwd}/loggregator-ci/tasks/scripts/datadog/client.rb"

def underscore(camel_cased_word)
  return camel_cased_word unless camel_cased_word =~ /[A-Z-]|::/
  word = camel_cased_word.to_s.gsub(/::/, '/')
  word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
  word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
  word.tr!("-", "_")
  word.downcase!
  word
end

def exec(env, cmd, dir=nil, silent: false)
  output = ""
  process = nil

  popen = lambda do
    IO.popen(env, cmd, err: [:child, :out]) do |io|
      io.each_line do |l|
        output << l

        if !silent
          puts l
        end
      end
    end
    process = $?
  end

  if dir
    Dir.chdir(dir) { popen.call }
  else
    popen.call
  end

  if !process.success?
    raise "Failed to execute command: #{cmd.join(' ')}"
  end

  output.chomp
end

def datadog_api_key
  dir = ENV['BBL_STATE_DIR']
  cmd = ['bosh', 'int', 'datadog-vars.yml', '--path', '/datadog_key']

  @datadog_api_key ||= exec(bosh_env, cmd, dir, silent: true)
end

def bosh_env
  if @bosh_env
    return @bosh_env
  end

  dir = ENV['BBL_STATE_DIR']

  director_creds = {
    'BOSH_CLIENT' => exec(ENV.to_h, ['bbl', 'director-username'], dir, silent: true),
    'BOSH_CLIENT_SECRET' => exec(ENV.to_h, ['bbl', 'director-password'], dir, silent: true),
    'BOSH_CA_CERT' => exec(ENV.to_h, ['bbl', 'director-ca-cert'], dir, silent: true),
    'BOSH_ENVIRONMENT' => exec(ENV.to_h, ['bbl', 'director-address'], dir, silent: true),
    'GOPATH' => "#{Dir.pwd}/loggregator-capacity-planning-release"
  }

  @bosh_env = ENV.to_h.merge(director_creds)
end

cmd = [
  'bosh', '-d', 'loggregator-bench',
  'run-errand', 'loggregator-bench',
]

lines = []
IO.popen(bosh_env, cmd, err: [:child, :out]) do |io|
  io.each_line do |l|
    lines << l

    puts l
  end
end

process = $?
if !process.success?
  raise "Failed to execute command: #{cmd.join(' ')}"
end

results = []
lines.each do |l|
  begin
    results << JSON.parse(l.strip)
  rescue
  end
end

ignore = ["Name", "Measured", "Ord"]
metrics = results.flatten.each_with_object({}) do |obj, res|
  raw_name = underscore(obj["Name"])
  name_chunks = raw_name.split("_")
  base_name = "benchmark.#{name_chunks[1..-1].join("_")}"

  sub_hash = obj.each_with_object({}) do |(key, value), results|
    if !ignore.include?(key)
      results["#{base_name}.#{underscore(key)}"] = value
    end
  end

  res.merge!(sub_hash)
end

client = DataDog::Client.new(datadog_api_key)

puts "Posting metrics to datadog: #{JSON.pretty_generate(metrics)}"
resp = client.send_gauge_metrics(metrics, "")
if !resp.kind_of?(Net::HTTPSuccess)
  raise "Failed to post metrics to Datadog: status_code: #{resp.code}, body: #{resp.body}"
end

output_dir = 'updated-loggregator-bench-results'
exec(ENV, ['rsync', '-ac', 'loggregator-bench-results/', output_dir])
puts "Writing results to results repo"
loggregator_sha = exec(ENV, ['git', 'rev-parse', 'HEAD'], 'loggregator-develop')
File.open("updated-loggregator-bench-results/#{loggregator_sha}.json", 'w') do |f|
  f.write(JSON.pretty_generate(metrics))
end


exec(bosh_env, ['git', 'config', 'user.email', 'cf-loggregator@pivotal.io'], output_dir)
exec(bosh_env, ['git', 'config', 'user.name', 'Loggregator CI'], output_dir)
exec(bosh_env, ['git', 'add', '.'], output_dir)
exec(bosh_env, ['git', 'commit', '-m', 'Add benchmark result'], output_dir)

puts "Done."
