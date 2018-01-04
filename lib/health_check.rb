class HealthCheck
  attr_reader :container_name, :health_check
  def initialize(container_name, health_check = nil)
    raise ArgumentError unless container_name
    @container = Docker::Container.get(container_name)
    @health_check = health_check
  end

  def top; @container.top end

  def healthy?
    @container.top.any? do |process| 
      process['COMMAND'] == @health_check
    end
  end

  def wait_until_healthy
    while !healthy? do sleep(1) end
    yield
  end
end