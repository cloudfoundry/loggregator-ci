#! /usr/bin/env ruby

require 'yaml'
require 'json'
require 'fileutils'

def sanitize(input)
  input.gsub(/{{(.*)}}/, '"((\1))"')
end

def set_version(gets, hash)
  if hash.kind_of?(Hash)
    if hash.has_key?('get')
      if gets.has_key?(hash['get'])
        hash['version'] = gets[hash['get']]['version']
      end
    else
      hash.keys.each do |key|
        set_version(gets, hash[key])
      end
    end
  elsif hash.kind_of?(Array)
    hash.each do |i| set_version(gets,i) end
  end
end

def strip_puts(hash)
  if hash.kind_of?(Hash)
    hash.each do |_, v| strip_puts(v) end
  elsif hash.kind_of?(Array)
    hash.reject! do |it|
      it.kind_of?(Hash) ? it.has_key?('put') : false
    end
    hash.each do |h| strip_puts(h) end
  end
end

if ARGV.length < 2
  puts 'Usage: ./scripts/create_snapshot.rb <pipeline_name> <snapshot_suffix>'
  exit 1
end

pipeline_name = ARGV[0]
pipeline_suffix = ARGV[1]
snapshot_name = "#{pipeline_name}-#{pipeline_suffix}"
FileUtils.mkdir_p "snapshots/#{snapshot_name}/resources"

filename = "pipelines/#{pipeline_name}.yml"
pipeline_str = sanitize(File.read(filename))

pipeline = YAML.load(pipeline_str)
strip_puts(pipeline)
pipeline['jobs'].each do |job|
  job_name = job['name']
  gets = JSON.load(`./scripts/get_gets.sh #{pipeline_name} #{job_name}`)

  versions = gets.map {|k, v| [k, v['version']] }.to_h

  File.open("snapshots/#{snapshot_name}/resources/#{job_name}.json", 'w') {|f| f.write versions.to_json }

  set_version(gets, job['plan'])
end

File.open("snapshots/#{snapshot_name}/pipeline.yml", 'w') {|f| f.write pipeline.to_yaml }
