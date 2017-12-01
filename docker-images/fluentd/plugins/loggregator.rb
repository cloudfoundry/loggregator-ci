require 'fluent/output'

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
        env.source_id = record.fetch("kubernetes", {}).fetch("pod_name", "")
        env.instance_id = record.fetch("kubernetes", {}).fetch("pod_id", "")
        batch.batch << env

        @stub.send(batch)
      }
    end
  end
end
