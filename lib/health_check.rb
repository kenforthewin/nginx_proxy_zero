require 'net/http'

class HealthCheck
  attr_reader :container, :container_name, :network_name
  def initialize(container)
    raise ArgumentError unless container
    @container = container.refresh!
  end

  def top; container.top end

  def healthy?
    return false unless container.info['NetworkSettings']
    port = container.info['NetworkSettings']['Ports'].first.first.split('/').first
    ip_address = @container.info['NetworkSettings']['Networks']['bridge']['IPAddress']
    url = "http://#{ip_address}:#{port}"
    puts "pinging #{url}..."
    uri = URI.parse(url)

    begin
      response = Net::HTTP.get_response(uri)
    rescue Errno::ECONNREFUSED
      return false
    end

    response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPFound)
  end

  def wait_until_healthy
    while !healthy? do 
      puts "#{container.id} failed, sleeping..."
      sleep(5)
      @container = container.refresh!
    end
    yield
  end
end