require "sinatra"
require "sinatra/reloader"
require 'honeybadger'
require 'json'
require_all 'lib'
Docker::API_VERSION = '1.21'
class NginxProxyZero < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
    also_reload './lib/**/*'
  end

  post '/update_deployment' do
    # deployment @payload will look something like this
    # { 
    #   name: "nginxproxyzero_some-zerodowntime-service_1",
    #   network: "nginxproxyzero_default",
    #   image: "jwilder/whoami",
    #   virtual_host: "whoami.deve"
    # }
    @payload = params
    @payload = JSON.parse(request.body.read).symbolize_keys unless @payload[:network]

    docker_network = Docker::Network.get(@payload[:network])
    old_container = Docker::Container.get(@payload[:name])
    new_container = Docker::Container.create(
      'Image' => @payload[:image],
      'Env' => ["VIRTUAL_HOST=#{@payload[:virtual_host]}"]
    )
    new_container.start
    health_check = HealthCheck.new(new_container)
    Thread.new do
      health_check.wait_until_healthy do
        docker_network.connect(new_container.id)
        old_container.stop
        old_container.remove
        new_container.rename(@payload[:name])
      end
    end
    'Ok'
  end

  post '/top' do
    @payload = params
    @payload = JSON.parse(request.body.read).symbolize_keys unless @payload[:name]
    HealthCheck.new(@payload[:name]).top.to_json.to_s
  end

  post '/health_check' do
    @payload = params
    @payload = JSON.parse(request.body.read).symbolize_keys unless @payload[:name]
    container = Docker::Container.get(@payload[:name])
    puts container.info
    health_check = HealthCheck.new(container)
    health_check.healthy?.to_s
  end

  get '/' do
    'Hello Zero'
  end
end
