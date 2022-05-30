
# Reverse proxy (based on openresty) (POC)

### Build container image
```
make build
```
### Start container
```
make start
```
or you can add some environment variables for customization
```
make start \
    FRONT_PORT=8080 \
    FRONT_SPORT=4430 \
    FRONT_DOMAIN="www.frontdomain.com" \
    UPSTREAM_DOMAIN="www.google.com" \
    UPSTREAM_HEADER_ORIGIN="https://www.google.com" \
    SSL_COMMON_NAME="www.frontdomain.com" \
    SSL_EMAIL="info@frontdomain.com"
```
**Please add dns record for your "FRONT_DOMAIN" before accessing the web site**
Example for /etc/hosts file.
`echo "192.0.2.10 www.frontdomain.com" >> /etc/hosts`

## All Variables

| Variable       | Default Value                | Description
|----------------|-------------------------------|-----------------|
| PORT           | 80
| SPORT          | 443
| FRONT_PORT     | 80 | (If you are publishing with different port)
| FRONT_SPORT     | 443| (If you are publishing with different port)
| CONTAINER_NAME  | orp|
| WORKER_CONNECTIONS | 2048|
| DNS_SERVER          | none
| FRONT_DOMAIN         | www.frontdomain.com
| UPSTREAM_DOMAIN         |  www.google.com
| UPSTREAM_SCHEME         | https
| UPSTREAM_HEADER_ORIGIN  | https://www.google.com
| SSL_VERIFY         | off
| SSL_COMMON_NAME    | www.frontdomain.com
| SSL_EMAIL          | info@frontdomain.com
| SSL_COUNTRY_CODE   | TR
| SSL_PROVINCE       | Istanbul
| SSL_LOCALITY       | Somewhere
| SSL_ORG_NAME       | lab
| SSL_ORG_UNIT_NAME  | infra


## All make commands
```
make help
Build openresty-1.19.9.1
  make build                  => Create openresty container image
  make buildnocache           => Create openresty container image wihtout build cache
  make rm                     => Remove container image
  make start                  => Start container
  make stop                   => Stop container
  make restart                => Restart container
  make help                   => This message

```

