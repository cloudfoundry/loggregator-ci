#! /usr/bin/env ruby

require 'yaml'
require 'json'
require 'fileutils'

def sanitize(input)
  input.gsub(/{{(.*)}}/, '"((\1))"')
end

def set_version(resources, hash)
  if hash.kind_of?(Hash)
    if hash.has_key?('get')
      if resources.has_key?(hash['get'])
        hash['version'] = resources[hash['get']]['version']
      end
    else
      hash.keys.each do |key|
        set_version(resources, hash[key])
      end
    end
  elsif hash.kind_of?(Array)
    hash.each do |i| set_version(resources,i) end
  end
end

def strip_key(hash, key)
  if hash.kind_of?(Hash)
    hash.delete(key)
    hash.each do |_, v| strip_key(v, key) end
  elsif hash.kind_of?(Array)
    hash.each do |h| strip_key(h, key) end
  end
end

def strip_item_by_key(hash, key)
  if hash.kind_of?(Hash)
    hash.each do |_, v| strip_item_by_key(v, key) end
  elsif hash.kind_of?(Array)
    hash.reject! do |it|
      it.kind_of?(Hash) ? it.has_key?(key) : false
    end
    hash.each do |h| strip_item_by_key(h, key) end
  end
end

def replace_strings(replacements, pipeline)
  replacements.reduce(pipeline.to_yaml) {|str, (from, to)| str.gsub(from, to)}
end

if ARGV.length < 2
  puts 'Usage: ./scripts/create_snapshot.rb <pipeline name> <snapshot unique identifier>'
  exit 1
end

pipeline_name = ARGV[0]
snapshot_id = ARGV[1]

snapshot_dir = "snapshots/#{pipeline_name}/#{snapshot_id}"
FileUtils.mkdir_p "#{snapshot_dir}/resources"

filename = "pipelines/#{pipeline_name}.yml"
pipeline_str = sanitize(File.read(filename))

pipeline = YAML.load(pipeline_str)
strip_item_by_key(pipeline, 'put')

included_jobs = %w(cf-deploy cfar-lats cats)
pipeline['jobs'].select!{ |job| included_jobs.include?(job['name']) }

excluded_resources = [
    'deployments-loggregator'
]
resource_names = Array.new
pipeline['jobs'].each do |job|
  job_name = job['name']

  resources = JSON.load(`./scripts/get_gets.sh #{pipeline_name} #{job_name}`)
  resource_names << resources.keys

  git_resources = resources.select{|k, v| v['type'] == 'git' && !excluded_resources.include?(v['resource']) }
  versions = git_resources.map {|k, v| [k, v['version']] }.to_h

  File.open("#{snapshot_dir}/resources/#{job_name}.json", 'w') {|f| f.write versions.to_json }

  set_version(git_resources, job['plan'])
end

cf_deploy = pipeline['jobs'].detect {|job| job['name'] == 'cf-deploy' }
strip_key(cf_deploy, 'passed')
strip_key(cf_deploy, 'trigger')

cats = pipeline['jobs'].detect {|job| job['name'] == 'cats'}
deployments_loggregator = cats['plan'][0]['aggregate'].detect {|resource| resource['get'] == 'deployments-loggregator'}
deployments_loggregator['passed'] = ['cf-deploy']

cfar_lats = pipeline['jobs'].detect {|job| job['name'] == 'cfar-lats'}

log_stream_cli = cfar_lats['plan'][0]['aggregate'].detect {|resource| resource['get'] == 'log-stream-cli'}
log_stream_cli.delete('passed')
cfar_lats['plan'][0]['aggregate'].push({'get' => 'deployments-loggregator', 'passed' => ['cf-deploy']})

pipeline['resources'].select! { |r| resource_names.flatten.include?(r['name']) }
pipeline.delete('groups')

new_subdomain = 'snapshot.loggr.'
new_env_dir = 'gcp/ci-pool/snapshot'
replacements = {
'coconut.' => new_subdomain,
'gcp/coconut-bbl' => new_env_dir,
}
File.open("#{snapshot_dir}/pipeline.yml", 'w') {|f| f.write replace_strings(replacements, pipeline) }