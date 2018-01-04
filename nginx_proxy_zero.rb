require "sinatra"
require "sinatra/reloader"
require 'honeybadger'
require 'json'
require_all 'lib'

class NginxProxyZero < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
    also_reload './lib/**/*'
  end

  post '/update_deployment' do
    # deployment payload will look something like this
    # { 
    #   name: "container_name",
    #   network: "nginxproxyzero_default",
    #   image: "container/image",
    #   virtual_host: "container_virtual_host"
    # }
    payload = params
    payload = JSON.parse(request.body.read).symbolize_keys unless payload[:network]
    docker_network = Docker::Network.get(payload[:network])
    new_container = Docker::Container.create(
      'Image' => payload[:image],
      'Env' => ["VIRTUAL_HOST=#{payload[:virtual_host]}"]
    )
    new_container.start
    docker_network.connect(new_container.id)
    old_container = Docker::Container.get(payload[:name])
    old_container.stop
    old_container.remove
    new_container.rename(payload[:name])
  end

  get '/' do
    'Hello Zero'
  end
end
