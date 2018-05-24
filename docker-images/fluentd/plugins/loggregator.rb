require 'fluent/output'
require 'fluent/filter'

require 'ingress_services_pb'
require 'envelope_pb'

module Fluent
  class LoggregatorOutput < Output
    Fluent::Plugin.register_output('loggregator', self)

    def load_certs(conf)
      files = [
        conf["loggregator_ca_file"],
        conf["loggregator_key_file"],
        conf["loggregator_cert_file"],
      ]
      files.map { |f| File.open(f).read }
    end

    def configure(conf)
      super
      creds = GRPC::Core::ChannelCredentials.new(*(load_certs(conf)))
      @stub = Loggregator::V2::Ingress::Stub.new(conf["loggregator_target"], creds)
    end

    def emit(tag, es, chain)
      chain.next
      es.each {|time,record|
        batch = Loggregator::V2::EnvelopeBatch.new
        env = Loggregator::V2::Envelope.new
        log = Loggregator::V2::Log.new

        log.payload = record["log"]
        if record["stream"] == "stderr"
          log.type = :ERR
        end

        env.log = log
        env.timestamp = (Time.now.to_f * (10 ** 9)).to_i
        env.source_id = record.fetch("kubernetes", {}).fetch("owner", "")
        env.instance_id = record.fetch("kubernetes", {}).fetch("pod_id", "")
        batch.batch << env

        begin
          retries ||= 0
          @stub.send(batch)
        rescue GRPC::Unavailable => e
          if (retries += 1) < 3
            sleep 2
            retry
          else
            raise e
          end
        end
      }
    end
  end
end

module Fluent
  class SourceIDFilter < Fluent::Filter
    Fluent::Plugin.register_filter('source_id', self)

    def configure(conf)
      @client = KubernetesClient.new()
    end

    def filter(tag, time, record)
      k8s = record.fetch("kubernetes")
      if not k8s
        return record
      end

      owner = resolve_owner(
        k8s.fetch("namespace_name", ""),
        "Pod",
        k8s.fetch("pod_name", ""),
      )
      k8s["owner"] = owner

      record
    end

    def resolve_owner(namespace_name, resource_type, resource_name)
      id_fmt = "%s/%s/%s"

      case resource_type
      when "Pod"
        obj = @client.get_pod(resource_name, namespace_name)
      when "ReplicationController"
        obj = @client.get_replicationcontroller(resource_name, namespace_name)
      when "ReplicaSet"
        obj = @client.get_replicaset(resource_name, namespace_name)
      when "Deployment"
        obj = @client.get_deployment(resource_name, namespace_name)
      when "DaemonSet"
        obj = @client.get_daemonset(resource_name, namespace_name)
      when "StatefulSet"
        obj = @client.get_statefulset(resource_name, namespace_name)
      when "Job"
        obj = @client.get_job(resource_name, namespace_name)
      when "CronJob"
        obj = @client.get_cronjob(resource_name, namespace_name)
      else
        obj = nil
      end

      if obj == nil
        return id_fmt % [
          namespace_name,
          resource_type.downcase,
          resource_name,
        ]
      end

      ownerReferences = obj.fetch("metadata", {}).fetch("ownerReferences", [])
      if ownerReferences.length == 0
        return id_fmt % [
          namespace_name,
          resource_type.downcase,
          resource_name,
        ]
      end

      resolve_owner(
        namespace_name,
        ownerReferences[0]["kind"],
        ownerReferences[0]["name"],
      )
    end
  end
end

require 'net/http'
require 'net/https'
require 'uri'
require 'json'

class KubernetesClient
  def initialize
    @url = "https://kubernetes.default.svc.cluster.local"
    token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    @token = File.read(token_file)

    uri = URI.parse(@url)
    @http = Net::HTTP.new(uri.host, uri.port)
    @http.use_ssl = true
    @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    @http.ca_file = ca_file
  end

  def resource_url(namespace_name, resource_type, resource_name)
    {
      Pod: "%s/api/v1/namespaces/%s/pods/%s",
      ReplicationController: "%s/api/v1/namespaces/%s/replicationcontrollers/%s",
      ReplicaSet: "%s/apis/apps/v1/namespaces/%s/replicasets/%s",
      Deployment: "%s/apis/apps/v1/namespaces/%s/deployments/%s",
      DaemonSet: "%s/apis/apps/v1/namespaces/%s/daemonsets/%s",
      StatefulSet: "%s/apis/apps/v1/namespaces/%s/statefulsets/%s",
      Job: "%s/apis/batch/v1/namespaces/%s/jobs/%s",
      CronJob: "%s/apis/batch/v1beta1/namespaces/%s/cronjobs/%s",
    }[resource_type] % [@url, namespace_name, resource_name]
  end

  def make_request(namespace_name, resource_type, resource_name)
    uri = URI.parse(resource_url(namespace_name, resource_type, resource_name))
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Authorization'] = "Bearer " + @token
    request
  end

  def get_pod(resource_name, namespace_name)
    request = make_request(namespace_name, :Pod, resource_name)
    response = @http.request(request)
    JSON.parse(response.body)
  end

  def get_replicationcontroller(resource_name, namespace_name)
    request = make_request(namespace_name, :ReplicationController, resource_name)
    response = @http.request(request)
    JSON.parse(response.body)
  end

  def get_replicaset(resource_name, namespace_name)
    request = make_request(namespace_name, :ReplicaSet, resource_name)
    response = @http.request(request)
    JSON.parse(response.body)
  end

  def get_deployment(resource_name, namespace_name)
    request = make_request(namespace_name, :Deployment, resource_name)
    response = @http.request(request)
    JSON.parse(response.body)
  end

  def get_daemonset(resource_name, namespace_name)
    request = make_request(namespace_name, :DaemonSet, resource_name)
    response = @http.request(request)
    JSON.parse(response.body)
  end

  def get_statefulset(resource_name, namespace_name)
    request = make_request(namespace_name, :StatefulSet, resource_name)
    response = @http.request(request)
    JSON.parse(response.body)
  end

  def get_job(resource_name, namespace_name)
    request = make_request(namespace_name, :Job, resource_name)
    response = @http.request(request)
    JSON.parse(response.body)
  end

  def get_cronjob(resource_name, namespace_name)
    request = make_request(namespace_name, :CronJob, resource_name)
    response = @http.request(request)
    JSON.parse(response.body)
  end
end
