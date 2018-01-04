require 'rubygems'
require 'bundler'

Bundler.require(:default)
require "./nginx_proxy_zero"
run NginxProxyZero
