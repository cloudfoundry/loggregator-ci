require_relative '../../automated-rampup-test.rb'
require 'spec_helper'

describe 'Settings' do
  let(:settings) do
    Settings.new({
      start_rps: 800,
      end_rps: 1600,
      steps: 4,
      metric_emitter_count: 2,
      log_emitter_count: 2,
      log_emitter_instance_count: 2,
    })
  end

  context 'when current step is 1' do
    let(:step) { settings.for(1) }

    it 'sets logs per second' do
      expect(step.logs_per_second).to equal(200)
    end

    it 'sets metrics per second' do
      expect(step.metrics_per_second).to equal(100)
    end
  end

  context 'when current step is 2' do
    let(:step) { settings.for(2) }

    it 'sets logs per second' do
      expect(step.logs_per_second).to equal(266)
    end

    it 'sets metrics per second' do
      expect(step.metrics_per_second).to equal(133)
    end
  end

  context 'when current step is 3' do
    let(:step) { settings.for(3) }

    it 'sets logs per second' do
      expect(step.logs_per_second).to equal(333)
    end

    it 'sets metrics per second' do
      expect(step.metrics_per_second).to equal(166)
    end
  end

  context 'when current step is 4' do
    let(:step) { settings.for(4) }

    it 'sets logs per second' do
      expect(step.logs_per_second).to equal(400)
    end

    it 'sets metrics per second' do
      expect(step.metrics_per_second).to equal(200)
    end
  end
end
