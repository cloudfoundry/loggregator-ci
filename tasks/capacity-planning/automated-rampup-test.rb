#!/usr/bin/env ruby

require 'json'
require 'yaml'
require 'ostruct'
require 'forwardable'
require "#{Dir.pwd}/loggregator-ci/tasks/scripts/datadog/client.rb"

class Settings
  extend Forwardable

  def_delegators :settings, :steps, :test_execution_minutes

  def self.from_file(path)
    self.new(JSON.parse(File.read(path)))
  end

  def initialize(base={})
    self.settings = OpenStruct.new

    base.each do |k, v|
      settings[k.to_s.downcase] = v
    end

    Logger.step("Settings: #{JSON.pretty_generate(settings.to_h)}")
  end

  def for(step)
    copy = OpenStruct.new(settings.to_h)

    copy.requests_per_second = rps(step)
    copy.logs_per_second = calculate_logs_per_second(step)
    copy.metrics_per_second = calculate_metrics_per_second(step)
    copy.step = step

    copy
  end

  def validate!
    required = [
      :adapter_collocated,
      :adapter_count,
      :api_version,
      :client_id,
      :diego_cell_count,
      :doppler_count,
      :end_rps,
      :event_counter_count,
      :log_api_count,
      :log_emitter_count,
      :log_emitter_instance_count,
      :log_size,
      :metric_emitter_count,
      :org,
      :space,
      :start_rps,
      :steps,
      :syslog_counter_count,
      :syslog_service_name,
      :syslog_service_url,
      :system_domain,
    ]

    given_attrs = settings.to_h.keys

    missing = required.select do |attr|
      if !given_attrs.include?(attr)
        missing << attr
      end
    end

    if missing.length > 0
      raise "Missing required settings attribute(s): #{missing.join(', ')}"
    end
  end

  private

  attr_accessor :settings

  def calculate_logs_per_second(step)
    lps = rps(step) / settings.log_emitter_count / settings.log_emitter_instance_count
    lps.floor
  end

  def calculate_metrics_per_second(step)
    mps = rps(step) / settings.metric_emitter_count
    mps.floor
  end

  def rps(step)
    rps = settings.start_rps + ((step - 1) * step_size)
    rps.floor
  end

  def step_size
    (settings.end_rps - settings.start_rps) / ((settings.steps - 1) * 1.0)
  end
end

module Executor
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
end

class Deployer
  include Executor

  def deploy!(settings, new_release: false)
    self.settings = settings


    if new_release
      create_release!
      upload_release!
      cf_login!
      delete_log_emitters!
    end

    build_ops_file!
    bosh_deploy!
    commit!
    delete_log_emitters!
    delete_services!
    create_service!
    push_log_emitters!
    create_datadog_event!
  end

  def commit!
    if !git_clean?
      dir = 'updated-vars-store'

      exec(bosh_env, ['git', 'config', 'user.email', 'cf-loggregator@pivotal.io'], dir)
      exec(bosh_env, ['git', 'config', 'user.name', 'Loggregator CI'], dir)
      exec(bosh_env, ['git', 'add', '.'], dir)
      exec(bosh_env, ['git', 'commit', '-m', 'Updating capacity planning deployment vars'], dir)
    else
      puts 'No changes to commit'
    end

    exec(bosh_env, ['rsync', '-a', 'updated-vars-store/', 'updated-capacity-planning-vars-store'])
  end


  private

  attr_accessor :settings

  def build_ops_file!
    Logger.step('Building ops file')
    ops = [{
      'type' => 'replace',
      'path' => '/instance_groups/name=event_counter/instances?',
      'value' => settings.event_counter_count
    },
    {
      'type' => 'replace',
      'path' => '/instance_groups/name=metric_emitter/instances?',
      'value' => settings.metric_emitter_count
    },
    {
      'type' => 'replace',
      'path' => '/instance_groups/name=syslog_counter/instances?',
      'value' => settings.syslog_counter_count
    },
    {
      'type' => 'replace',
      'path' => '/instance_groups/name=metric_emitter/jobs/name=metric_emitter/properties/metric_emitter/api_version?',
      'value' => settings.api_version
    },
    {
      'type' => 'replace',
      'path' => '/instance_groups/name=metric_emitter/jobs/name=metric_emitter/properties/metric_emitter/metrics_per_second?',
      'value' => settings.metrics_per_second
    }]

    File.open('/tmp/overrides.yml', 'w') { |f| f.write(ops.to_yaml) }
  end

  def client_secret
    dir = 'updated-vars-store/gcp/loggregator-capacity-planning'
    cmd = ['bosh', 'int', 'deployment-vars.yml', '--path', '/capacity_planning_authenticator_secret']

    @client_secret ||= exec(bosh_env, cmd, dir, silent: true)
  end

  def datadog_api_key
    dir = 'updated-vars-store/gcp/loggregator-capacity-planning'
    cmd = ['bosh', 'int', 'datadog-vars.yml', '--path', '/datadog_key']

    @datadog_api_key ||= exec(bosh_env, cmd, dir, silent: true)
  end

  def cf_password
    dir = 'updated-vars-store/gcp/loggregator-capacity-planning'
    cmd = ['bosh', 'int', 'deployment-vars.yml', '--path', '/cf_admin_password']

    @cf_password ||= exec(bosh_env, cmd, dir, silent: true)
  end

  def bosh_env
    if @bosh_env
      return @bosh_env
    end

    dir = 'updated-vars-store/gcp/loggregator-capacity-planning'

    director_creds = {
      'BOSH_CLIENT' => exec(ENV.to_h, ['bbl', 'director-username'], dir, silent: true),
      'BOSH_CLIENT_SECRET' => exec(ENV.to_h, ['bbl', 'director-password'], dir, silent: true),
      'BOSH_CA_CERT' => exec(ENV.to_h, ['bbl', 'director-ca-cert'], dir, silent: true),
      'BOSH_ENVIRONMENT' => exec(ENV.to_h, ['bbl', 'director-address'], dir, silent: true),
      'GOPATH' => "#{Dir.pwd}/loggregator-capacity-planning-release"
    }

    @bosh_env = ENV.to_h.merge(director_creds)
  end

  def create_release!
    Logger.step('Creating release')
    cmd = ['bosh', 'create-release', '--force']
    exec(bosh_env, cmd, 'loggregator-capacity-planning-release', silent: true)
  end

  def upload_release!
    Logger.step('Uploading release')
    cmd = ['bosh', 'upload-release', '--rebase']
    exec(bosh_env, cmd, 'loggregator-capacity-planning-release', silent: true)
  end

  def bosh_deploy!
    Logger.step('Deploying loggregator capacity planning release')
    bbl_dir = "#{Dir.pwd}/updated-vars-store/gcp/loggregator-capacity-planning"
    cmd = [
      'bosh', '-d', 'loggregator_capacity_planning', 'deploy', '-n', 'manifests/loggregator-capacity-planning.yml',
      '-l', "#{bbl_dir}/deployment-vars.yml",
      '-o', '/tmp/overrides.yml',
      '-v', "system_domain=#{settings.system_domain}",
      '-v', "datadog_api_key=#{datadog_api_key}",
      '-v', "client_id=#{settings.client_id}",
      '-v', "client_secret=#{client_secret}",
      '--vars-store', "#{bbl_dir}/capacity-planning-vars.yml"
    ]

    exec(bosh_env, cmd, 'loggregator-capacity-planning-release')
  end

  def cf_login!
    Logger.step('CF Login')
    cmd = [
      'cf', 'login',
      '-a', "api.#{settings.system_domain}",
      '-u', 'admin',
      '-p', cf_password,
      '-o', settings.org,
      '-s', settings.space,
      '--skip-ssl-validation'
    ]

    exec(bosh_env, cmd, silent: true)
  end

  def delete_log_emitters!
    Logger.step('Removing existing log emitters')
    apps = exec(bosh_env, ['cf', 'apps']).scan(/(log_emitter-\d*)/).flatten

    threads = []
    apps.each do |name|
      threads << Thread.new do
        exec(bosh_env, ['cf', 'delete', name, '-f', '-r'])
      end
    end

    threads.map { |t| t.join }
  end

  def delete_services!
    Logger.step("Deleting services")
    exec(bosh_env, ['cf', 'delete-service', settings.syslog_service_name, '-f'])
  end

  def create_service!
    Logger.step("Creating service")
    cmd = [
      'cf', 'create-user-provided-service', settings.syslog_service_name,
      '-l', settings.syslog_service_url,
    ]
    exec(bosh_env, cmd)
  end

  def push_log_emitters!
    dir = "#{Dir.pwd}/loggregator-capacity-planning-release/src/code.cloudfoundry.org/log_emitter"

    Logger.step("Building log emitter")
    exec(bosh_env, ['go', 'build'], dir)

    threads = []
    (1..settings.log_emitter_count).each do |i|
      Logger.step("Deploying log emitter #{i}")

      flags = [
        "--logs-per-second='#{settings.logs_per_second}'",
        "--log-bytes='#{settings.log_size}'",
        "--datadog-api-key='#{datadog_api_key}'",
        "--client-id='capacity_planning_authenticator'",
        "--client-secret='#{client_secret}'",
      ]

      push_cmd = [
        'cf', 'push', "log_emitter-#{i}",
        '-b', 'binary_buildpack',
        '-c', "./log_emitter #{flags.join(' ')}",
        '-i', settings.log_emitter_instance_count.to_s,
        '-m', '64M',
        '-k', '128M',
        '-u', 'none',
        '-p', dir,
      ]

      bind_cmd = [
        'cf', 'bind-service', "log_emitter-#{i}", settings.syslog_service_name
      ]

      threads << Thread.new do
        exec(bosh_env, push_cmd)
        exec(bosh_env, bind_cmd)
      end
    end

    threads.map { |t| t.join }
  end

  def create_datadog_event!
    Logger.step("Creating datadog event")
    title = 'Capacity Planning Scale'
    text = %Q{Capacity Planning environment has been configured with the following:

Step: #{settings.step} of #{settings.steps}
Start RPS: #{settings.start_rps}
End RPS: #{settings.end_rps}
Current RPS: #{settings.requests_per_second}
Test Duration: #{settings.test_execution_minutes}

#{JSON.pretty_generate(settings.to_h)}
    }

    tags = settings.to_h

    puts "Title: #{title}"
    puts "Text:  #{text}"
    puts "Tags:  #{tags.inspect}"

    client = DataDog::Client.new(datadog_api_key)
    resp = client.create_event(title, text, tags)

    if !resp.kind_of?(Net::HTTPAccepted)
      puts "Failed to create event: #{resp.inspect}"
      puts resp.body
      raise
    end
  end

  def git_clean?
    exec(bosh_env, ['git', 'status', '--porcelain'], 'updated-vars-store') == ""
  end
end

class Logger
  class << self
    def heading(msg)
      puts ""
      puts "\e[95m##### #{msg} #####\e[0m"
    end

    def step(msg)
      puts "\e[33m#{msg}\e[0m"
    end

    def fatal(msg)
      if !msg.is_a?(Array)
        msg = [msg]
      end

      msg.each do |l|
        puts "\e[31m#{l}\e[0m"
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    Logger.heading("Loading settings from file")
    settings = Settings.from_file('deployment-settings/settings.json')
    settings.validate!
    deployer = Deployer.new

    Logger.heading("Starting automated rampup test. #{settings.steps} steps for #{settings.test_execution_minutes} minutes each.")

    (1..settings.steps).each do |step|
      step_settings = settings.for(step)

      Logger.heading("Starting deploy for step #{step}. #{step_settings.requests_per_second} requests per second.")
      deployer.deploy!(step_settings, new_release: step==1)

      # TODO: Create Datadog Event

      Logger.heading("Deploy for step #{step} complete. Waiting #{settings.test_execution_minutes} minutes")
      sleep(60 * settings.test_execution_minutes)
    end
  rescue => e
    Logger.fatal(e.message)
    Logger.fatal(e.backtrace)

    abort("failed")
  end
end
