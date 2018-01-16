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
    bridge_network = Docker::Network.get('bridge')
    begin
      old_container = Docker::Container.get(@payload[:name])
    rescue Docker::Error::NotFoundError
      old_container = false
    end

    begin
      bridge_network.connect(ENV['HOSTNAME'])
    rescue Excon::Error::Forbidden
    end
    environment_variables = old_container ? old_container.info['Config']['Env'] : []
    new_env = environment_variables + ["VIRTUAL_HOST=#{@payload[:virtual_host]}"]
    volumes = old_container.info['Config']['Volumes']
    # mounts = old_container.info['Mounts']
    cmd = old_container.info['Config']['Cmd']
    entrypoint = old_container.info['Config']['Entrypoint']
    labels = old_container.info['Config']['Labels']
    links = old_container.info['HostConfig']['Links']
    image = Docker::Image.create('fromImage' => @payload[:image], 'tag' => @payload[:tag] || 'latest')
    new_container = Docker::Container.create(
      'Image' =>      image.id,
      'Env' =>        new_env,
      'Labels' =>     labels,
      'Cmd' =>        cmd,
      'Entrypoint' => entrypoint,
      'Volumes' =>    volumes,
      'HostConfig' => {
        'Links' => links
      }
    )
    new_container.start
    health_check = HealthCheck.new(new_container)
    Thread.new do
      health_check.wait_until_healthy do
        docker_network.connect(new_container.id)

        if old_container
          old_container.stop
          old_container.remove
        end
        
        new_container.rename(@payload[:name])
      end
    end
    'Ok'
  end

  post '/top' do
    @payload = params
    @payload = JSON.parse(request.body.read).symbolize_keys unless @payload[:name]
    HealthCheck.new(@payload[:name]).top.to_json
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
