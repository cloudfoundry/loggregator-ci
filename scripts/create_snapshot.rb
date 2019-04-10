#! /usr/bin/env ruby

require 'yaml'
require 'json'
require 'fileutils'

def sanitize(input)
  input.gsub(/{{(.*)}}/, '"((\1))"')
end

def set_version(resources, hash)
  excluded_get_versions = %w(bbl-state deployments-loggregator)
  if hash.kind_of?(Hash)
    if hash.has_key?('get')
      resource_alias = hash['get']
      if resources.has_key?(resource_alias) && !excluded_get_versions.include?(resource_alias)
        hash['version'] = resources[resource_alias]['version']
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

if ARGV.length < 1
  puts 'Usage: ./scripts/create_snapshot.rb <snapshot unique identifier>'
  exit 1
end

pipeline_name = 'products'
snapshot_id = ARGV[0]

snapshot_dir = "snapshots/#{pipeline_name}/#{snapshot_id}"
FileUtils.mkdir_p "#{snapshot_dir}/resources"

filename = "pipelines/#{pipeline_name}.yml"
pipeline_str = sanitize(File.read(filename))

pipeline = YAML.load(pipeline_str)
strip_item_by_key(pipeline, 'put')

included_jobs = %w(cf-deploy cfar-lats cats)
pipeline['jobs'].select!{|job| included_jobs.include?(job['name'])}

resource_names = Array.new
pipeline['jobs'].each do |job|
  job_name = job['name']

  resources = JSON.load(`./scripts/get_gets.sh #{pipeline_name} #{job_name}`)
  resource_names << resources.keys

  git_resources = resources.select{|k, v| v['type'] == 'git' }
  versions = git_resources.map {|k, v| [k, v['version']] }.to_h

  File.open("#{snapshot_dir}/resources/#{job_name}.json", 'w') {|f| f.write versions.to_json }

  set_version(git_resources, job['plan'])
end

cf_deploy = pipeline['jobs'].detect {|job| job['name'] == 'cf-deploy' }
strip_key(cf_deploy, 'passed')
strip_key(cf_deploy, 'trigger')
depls = cf_deploy['plan'][0]['aggregate'].select {|a| a['resource'] == 'deployments-loggregator'}
depls.map! {|d| d.merge!({'passed' => ["bbl-create"], 'trigger' => true})}
cf_deploy_resources = JSON.load(File.read("#{snapshot_dir}/resources/cf-deploy.json"))
cf_deploy['plan'][0]['aggregate'].push({
   'get' => 'bbl-state-locked',
   'resource' => 'deployments-loggregator-locked',
   'version' => cf_deploy_resources['bbl-state'],
})
copy_ops_files = cf_deploy['plan'].detect {|step| step['task'] == 'copy-ops-files'}
copy_ops_files['input_mapping'] = {'bbl-state' => 'bbl-state-locked'}

cats = pipeline['jobs'].detect {|job| job['name'] == 'cats'}
deployments_loggregator = cats['plan'][0]['aggregate'].detect {|resource| resource['get'] == 'deployments-loggregator'}
deployments_loggregator.merge!({'passed' => ['cf-deploy'], 'trigger' => true})

cfar_lats = pipeline['jobs'].detect {|job| job['name'] == 'cfar-lats'}
log_stream_cli = cfar_lats['plan'][0]['aggregate'].detect {|resource| resource['get'] == 'log-stream-cli'}
log_stream_cli.delete('passed')
cfar_lats['plan'][0]['aggregate'].push({'get' => 'deployments-loggregator', 'passed' => ['cf-deploy'], 'trigger' => true})

pipeline['resources'].select! {|r| resource_names.flatten.include?(r['name'])}
pipeline.delete('groups')
deployments_loggregator_locked = pipeline['resources'].detect {|r| r['name'] == "deployments-loggregator"}
deployments_loggregator_locked['name'] = "deployments-loggregator-locked"
pipeline['resources'].push(deployments_loggregator_locked)

new_env_name = "#{pipeline_name}-#{snapshot_id}"
create_snapshot_lock = YAML.load <<END_YAML
name: create-snapshot-lock
plan:
- task: create-lock-files
  config:
    platform: linux
    image_resource:
      type: docker-image
      source:
        repository: relintdockerhubpushbot/cf-deployment-concourse-tasks
        tag: v3.19.0
    outputs:
      - name: lock-files
    run:
      path: /bin/bash
      args:
        - "-c"
        - |
          set -e

          echo '#{new_env_name}' > lock-files/name
          echo 'gcp/ci-pool/#{new_env_name}' > lock-files/metadata
- put: create-pool
  params: {add: lock-files}
END_YAML
destroy_snapshot_lock = YAML.load <<END_YAML
name: destroy-snapshot-lock
plan:
- get: deployments-loggregator
  trigger: true
  passed:
  - cats
  - cfar-lats

- task: create-lock-files
  config:
    platform: linux
    image_resource:
      type: docker-image
      source:
        repository: relintdockerhubpushbot/cf-deployment-concourse-tasks
        tag: v3.19.0
    outputs:
      - name: lock-files
    run:
      path: /bin/bash
      args:
        - "-c"
        - |
          set -e

          echo '#{new_env_name}' > lock-files/name
          echo 'gcp/ci-pool/#{new_env_name}' > lock-files/metadata
- put: destroy-pool
  params: {add: lock-files}
END_YAML
pool_envs = YAML.load_file('pipelines/pool-envs.yml')
bbl_create = pool_envs['jobs'].detect {|job| job['name'] == 'bbl-create'}
bbl_destroy = pool_envs['jobs'].detect {|job| job['name'] == 'bbl-destroy'}
pipeline['jobs'].unshift(create_snapshot_lock, bbl_create)
pipeline['jobs'].push(destroy_snapshot_lock, bbl_destroy)
# Merge pool envs resources, taking base pipeline resources over pool envs
pipeline['resources'] = (pipeline['resources'] + pool_envs['resources']).uniq {|r| r['name']}

bbl_create = pipeline['jobs'].detect {|job| job['name'] == 'bbl-create'}
bbl_create['plan'][0]['params'] = {'claim' => new_env_name}
bbl_create['plan'].unshift({'get' => 'create-pool', 'passed' => ['create-snapshot-lock'], 'trigger' => true})

bbl_destroy = pipeline['jobs'].detect {|job| job['name'] == 'bbl-destroy'}
bbl_destroy['plan'][0]['params'] = {'claim' => new_env_name}
bbl_destroy['plan'].unshift({'get' => 'destroy-pool', 'passed' => ['destroy-snapshot-lock'], 'trigger' => true})

new_subdomain = "#{new_env_name}.loggr."
new_env_dir = "gcp/ci-pool/#{new_env_name}"
replacements = {
'coconut.' => new_subdomain,
'BBL_STATE_DIR: gcp/coconut-bbl' => "BBL_STATE_DIR: #{new_env_dir}",
'BBL_ENV_NAME: coconut-bbl' => "BBL_ENV_NAME: #{new_env_name}",
'pushd deployments-loggregator/gcp/coconut-bbl' => "pushd deployments-loggregator/#{new_env_dir}",
'pushd bbl-state/gcp/coconut-bbl' => "pushd bbl-state/#{new_env_dir}",
'bosh-bbl-env-athabasca-2019-03-22t18-23z' => "bosh-#{new_env_name}",
}
File.open("#{snapshot_dir}/pipeline.yml", 'w') {|f| f.write replace_strings(replacements, pipeline) }
