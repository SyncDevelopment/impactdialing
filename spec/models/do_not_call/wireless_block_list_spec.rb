require 'spec_helper'

describe 'DoNotCall::WirelessBlockList' do
  def r7
    s = ''
    7.times{ s << "#{rand(9)}" }
    s
  end

  def redis
    @redis ||= Redis.new
  end

  subject{ DoNotCall::WirelessBlockList }
  let(:parser) do
    instance_double('DoNotCall::WirelessBlockParser')
  end
  let(:file) do
    double('FakeFile')
  end

  before do
    stub_const('DoNotCall::WirelessBlockParser', Class.new)
    allow(DoNotCall::WirelessBlockParser).to receive(:new){ parser }
  end

  it 'caches a set of 7 digit numbers (xxx) xxx-x' do
    to_yield = [r7,r7,r7,r7,r7]
    expect(parser).to receive(:in_batches).and_yield(to_yield)
    subject.cache(file)
    expect(redis.scard(subject.key)).to eq to_yield.size
  end

  it 'does not retain entries between cache refreshes' do
    pre_exist = [r7,r7,r7]
    expect(parser).to receive(:in_batches).and_yield(pre_exist)
    subject.cache(file)

    fresh = [r7,r7,r7,r7]
    expect(parser).to receive(:in_batches).and_yield(fresh)
    subject.cache(file)
    expect(redis.scard(subject.key)).to eq fresh.size
    expect(redis.smembers(subject.key)).to match_array fresh.flatten
  end

  it 'checks for existence of a 7 digit number' do
    m        = [r7,r7,r7,r7,r7,r7]
    existing = m[2]
    missing  = r7
    allow(parser).to receive(:in_batches).and_yield(m)
    subject.cache(file)
    expect( subject.exists?(missing) ).to be_falsy
    expect( subject.exists?(existing) ).to be_truthy
  end
end