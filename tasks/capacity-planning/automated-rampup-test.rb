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

    validate!

    Logger.step("Settings: #{JSON.pretty_generate(settings.to_h)}")
  end

  def for(step)
    copy = OpenStruct.new(settings.to_h)

    copy.requests_per_second = rps(step)
    copy.logs_per_second = calculate_logs_per_second(step)
    copy.metrics_per_second = calculate_metrics_per_second(step)

    copy
  end

  private

  attr_accessor :settings

  def validate!
    required = [
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

  def calculate_logs_per_second(step)
    lps = rps(step) / 2 / settings.metric_emitter_count
    lps.floor
  end

  def calculate_metrics_per_second(step)
    mps = rps(step) / 2 / settings.log_emitter_count / settings.log_emitter_instance_count
    mps.floor
  end

  def rps(step)
    settings.start_rps + ((step - 1) * step_size)
  end

  def step_size
    (settings.end_rps - settings.start_rps) / ((settings.steps - 1) * 1.0)
  end
end

class Deployer
  def deploy!(settings)
    self.settings = settings

    build_ops_file!
    create_release!
    upload_release!
    bosh_deploy!
    commit!
    cf_login!
    delete_log_emitters!
    push_log_emitters!
    create_datadog_event!
  end

  def commit!
    if !git_clean
      dir = 'updated-vars-store'

      exec(bosh_env, ['git', 'config', 'user.email', 'cf-loggregator@pivotal.io'], dir)
      exec(bosh_env, ['git', 'config', 'user.name', 'Loggregator CI'], dir)
      exec(bosh_env, ['git', 'add', '.'], dir)
      exec(bosh_env, ['git', 'commit', '-m', 'Updating capacity planning deployment vars'], dir)
    else
      puts 'No changes to commit'
    end

    exec(bosh_env, ['rsync', '-a', 'updated-vars-store/', 'updated-capacity-planning-vars-store'], Dir.pwd)
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
    @client_secret ||= exec(bosh_env, cmd, dir)
  end

  def datadog_api_key
    dir = 'updated-vars-store/gcp/loggregator-capacity-planning'
    cmd = ['bosh', 'int', 'datadog-vars.yml', '--path', '/datadog_key']

    @datadog_api_key ||= exec(bosh_env, cmd, dir)
  end

  def cf_password
    dir = 'updated-vars-store/gcp/loggregator-capacity-planning'
    cmd = ['bosh', 'int', 'deployment-vars.yml', '--path', '/cf_admin_password']

    @cf_password ||= exec(bosh_env, cmd, dir)
  end

  def bosh_env
    if @bosh_env
      return @bosh_env
    end

    dir = 'updated-vars-store/gcp/loggregator-capacity-planning'

    director_creds = {
      'BOSH_CLIENT' => exec(ENV.to_h, ['bbl', 'director-username'], dir),
      'BOSH_CLIENT_SECRET' => exec(ENV.to_h, ['bbl', 'director-password'], dir),
      'BOSH_CA_CERT' => exec(ENV.to_h, ['bbl', 'director-ca-cert'], dir),
      'BOSH_ENVIRONMENT' => exec(ENV.to_h, ['bbl', 'director-address'], dir),
      'GOPATH' => "#{Dir.pwd}/loggregator-capacity-planning-release"
    }

    @bosh_env = ENV.to_h.merge(director_creds)
  end

  def create_release!
    Logger.step('Creating release')
    cmd = ['bosh', 'create-release']
    exec(bosh_env, cmd, 'loggregator-capacity-planning-release')
  end

  def upload_release!
    Logger.step('Uploading release')
    cmd = ['bosh', 'upload-release', '--rebase']
    exec(bosh_env, cmd, 'loggregator-capacity-planning-release')
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

    exec(bosh_env, cmd, Dir.pwd)
  end

  def delete_log_emitters!
    Logger.step('Removing existing log emitters')
    apps = exec(bosh_env, ['cf', 'apps'], Dir.pwd).scan(/(log_emitter-\d*)/).flatten

    threads = []
    apps.each do |name|
      threads << Thread.new do
        exec(bosh_env, ['cf', 'delete', name, '-f', '-r'], Dir.pwd)
      end
    end

    threads.map { |t| t.join }
  end

  def push_log_emitters!
    dir = 'loggregator-capacity-planning-release/src/code.cloudfoundry.org/log_emitter'

    threads = []
    (1..settings.log_emitter_count).each do |i|
      Logger.step("Deploying log emitter #{i}")

      flags = [
        "--logs-per-second=#{settings.logs_per_second}",
        "--log-bytes=#{settings.log_bytes}",
        "--datadog-api-key=#{datadog_api_key}",
        "--client-id=capacity_planning_authenticator",
        "--client-secret=#{client_secret}",
      ]

      cmd = [
        'cf', 'push', "log_emitter-#{i}",
        '-b', 'binary_buildpack',
        '-c', "./log_emiter #{flags.join(' ')}",
        '-i', settings.log_emitter_instance_count,
        '-m', '64M',
        '-k', '128M',
        '-u', 'none'
      ]

      threads << Thread.new do
        exec(bosh_env, cmd, dir)
      end
    end

    threads.map { |t| t.join }
  end

  def create_datadog_event!
    Logger.step("Creating datadog event")
    title = 'Capacity Planning Scale'
    text = %Q{Capacity Planning environment has been configured with the following:

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

  def exec(env, cmd, dir)
    output = ""
    process = nil

    Dir.chdir(dir) do
      IO.popen(env, cmd, err: [:child, :out]) do |io|
        io.each_line do |l|
          output << l
          puts l
        end
      end
      process = $?
    end

    if !process.success?
      raise "Failed to execute command: #{cmd.join(' ')}"
    end

    output.chomp
  end
end

class Logger
  class << self
    def heading(msg)
      puts ""
      puts "\e[95m##### #{msg} #####\e[0m"
    end

    def step(msg)
      puts "\e[34m#{msg}\e[0m"
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

begin
  Logger.heading("Loading settings from file")
  settings = Settings.from_file('deployment-settings/settings.json')
  deployer = Deployer.new

  Logger.heading("Starting automated rampup test. #{settings.steps} steps for #{settings.test_execution_minutes} each.")

  (1..settings.steps).each do |step|
    step_settings = settings.for(step)

    Logger.heading("Starting deploy for step #{step}. #{step_settings.rps} requests per second.")
    deployer.deploy!(step_settings)

    # TODO: Create Datadog Event

    Logger.heading("Deploy for step #{step} complete. Waiting #{settings.test_execution_minutes} minutes")
    sleep(60 * settings.test_execution_minutes)
  end
rescue => e
  Logger.fatal(e.message)
  Logger.fatal(e.backtrace)

  abort("failed")
end
