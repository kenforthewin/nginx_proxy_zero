# nginx_proxy_zero

Idiomatic API for zero-downtime docker deploys. Not secure - don't give public access.

## dev setup

1. Add `127.0.0.1 zero.deve` to your Hosts file.
1. Optionally, add `127.0.0.1 whoami.deve` to test deployment with a simple http server.
1. run `docker-compose up -d`

## perform a rolling update

Make a POST request to `http://zero.deve/update_deployment`. The body of your request should be a JSON payload which conforms to the following format:

```json
    {
      "name": "nginxproxyzero_some-zerodowntime-service_1",
      "network": "nginxproxyzero_default",
      "image": "jwilder/whoami",
      "virtual_host": "whoami.deve"
    }
```
