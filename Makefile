#Openresty reverse proxy application
#Author: Fatih USTA <fatihusta86@gmail.com>

CWD              = $(shell pwd)

VERSION          = 1.19.9.1
PROJECT          = openresty
VOLUME          ?= $(CWD)/certs
DOCKERFILE      ?= Dockerfile

PORT            ?= 80
SPORT           ?= 443
FRONT_PORT      ?= 80
FRONT_SPORT     ?= 443
CONTAINER_NAME  ?= orp

WORKER_CONNECTIONS      ?= 2048
DNS_SERVER              ?= 
FRONT_DOMAIN            ?= www.frontdomain.com
UPSTREAM_DOMAIN         ?= www.google.com
UPSTREAM_SCHEME         ?= https
UPSTREAM_HEADER_ORIGIN  ?= https://www.google.com

SSL_VERIFY         ?= off
SSL_COMMON_NAME    ?= www.frontdomain.com
SSL_EMAIL          ?= info@frontdomain.com
SSL_COUNTRY_CODE   ?= TR
SSL_PROVINCE       ?= Istanbul
SSL_LOCALITY       ?= Somwhere
SSL_ORG_NAME       ?= lab
SSL_ORG_UNIT_NAME  ?= infra




all: help

help:
	@echo "Build $(PROJECT)-$(VERSION)"
	@echo "  make build                  => Create openresty container image"
	@echo "  make buildnocache           => Create openresty container image wihtout build cache"
	@echo "  make rm                     => Remove container image"
	@echo "  make start                  => Start container"
	@echo "  make stop                   => Stop container"
	@echo "  make restart                => Restart container"
	@echo "  make help                   => This message"

build:
	@docker build \
		--file $(DOCKERFILE) \
		--tag $(PROJECT):$(VERSION) \
		.
		
buildnocache:
	@docker build \
		--no-cache \
		--file $(DOCKERFILE) \
		--tag $(PROJECT):$(VERSION)

start: 
	@[ ! -d $(VOLUME) ] && mkdir -p $(VOLUME) || true
	@docker run \
		--interactive \
		--tty \
		--detach \
		--name $(CONTAINER_NAME) \
		--hostname $(CONTAINER_NAME) \
		--env PORT=$(PORT) \
		--env SPORT=$(SPORT) \
		--env FRONT_PORT=$(FRONT_PORT) \
		--env FRONT_SPORT=$(FRONT_SPORT) \
		--env WORKER_CONNECTIONS=$(WORKER_CONNECTIONS) \
		--env DNS_SERVER=$(DNS_SERVER) \
		--env FRONT_DOMAIN=$(FRONT_DOMAIN) \
		--env UPSTREAM_DOMAIN=$(UPSTREAM_DOMAIN) \
		--env UPSTREAM_SCHEME=$(UPSTREAM_SCHEME) \
		--env UPSTREAM_HEADER_ORIGIN=$(UPSTREAM_HEADER_ORIGIN) \
		--env SSL_VERIFY=$(SSL_VERIFY) \
		--env SSL_COMMON_NAME=$(SSL_COMMON_NAME) \
		--env SSL_EMAIL=$(SSL_EMAIL) \
		--env SSL_COUNTRY_CODE=$(SSL_COUNTRY_CODE) \
		--env SSL_PROVINCE=$(SSL_PROVINCE) \
		--env SSL_LOCALITY=$(SSL_LOCALITY) \
		--env SSL_ORG_NAME=$(SSL_ORG_NAME) \
		--env SSL_ORG_UNIT_NAME=$(SSL_ORG_UNIT_NAME) \
	        --publish $(FRONT_PORT):$(PORT) \
		--publish $(FRONT_SPORT):$(SPORT) \
		--volume $(VOLUME):/data \
		$(PROJECT):$(VERSION)
	@printf "\nContainer is ready\n"
	@printf "Site: %s:%s\n" $(FRONT_DOMAIN) $(FRONT_SPORT)
	@printf "\nPlease define dns record before accessing the web site\n"
	@printf "Example for /etc/hosts => 192.0.2.10 %s\n" $(FRONT_DOMAIN)

stop:
	@docker container stop $(CONTAINER_NAME) \
		&& docker container rm $(CONTAINER_NAME) || true

restart: stop start

rm:
	@docker image rm \
		$(PROJECT):$(VERSION)

.PHONY: all help build start stop remove
