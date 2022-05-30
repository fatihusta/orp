FROM amd64/ubuntu:focal as builder
LABEL maintainer="Fatih USTA <fatihusta86@gmail.com>"

ARG OPENRESTY_VERSION="1.19.9.1"

WORKDIR /tmp

# Update package repository and install build requierments
RUN export DEBIAN_FRONTEND=noninteractive
RUN apt update -y && \
    apt-get install -y \
      libpcre3-dev \
      libssl-dev \
      perl \
      make \
      build-essential \
      curl \
      zlib1g-dev

# Get openresty
RUN curl -#JOSL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz

# Extract
RUN tar -xf openresty-${OPENRESTY_VERSION}.tar.gz

# Change directory
WORKDIR /tmp/openresty-${OPENRESTY_VERSION}

# Configure openresty
RUN ./configure \
        --with-threads \
	--with-file-aio \
	--with-http_ssl_module \
        --with-http_v2_module \
        --with-http_gzip_static_module \
        --with-http_stub_status_module \
        --with-http_sub_module

# Build 
RUN make -j$(nproc)

# Install
RUN mkdir -p /tmp/_install && \
    make DESTDIR=/tmp/_install install

# Clean image
FROM amd64/ubuntu:focal

ENV PORT=80 \
    SPORT=443 \
    FRONT_PORT=80 \
    FRONT_SPORT=443 \
    FRONT_DOMAIN="www.frontdomain.com" \
    UPSTREAM_DOMAIN="www.google.com" \
    UPSTREAM_SCHEME="https" \
    UPSTREAM_HEADER_ORIGIN="https://www.google.com" \
    WORKER_CONNECTIONS=2048 \
    DNS_SERVER="" \
    \
    SSL_VERIFY="off" \
    SSL_COMMON_NAME="www.frontdomain.com" \
    SSL_EMAIL="info@frontdomain.com" \
    SSL_COUNTRY_CODE="TR" \
    SSL_PROVINCE="Istanbul" \
    SSL_LOCALITY="Somwhere" \
    SSL_ORG_NAME="lab" \
    SSL_ORG_UNIT_NAME="infra"

# Install runtime dependencies
RUN export DEBIAN_FRONTEND=noninteractive
RUN apt update -y && \
      apt-get install -y --no-install-recommends \
      libpcre3 \
      openssl \
      luajit \
      zlib1g \
      tini

# Clean repository cache
RUN apt clean all && \
    rm -rf /var/lib/apt/lists/*

# Copy from builder
COPY --from=builder /tmp/_install/* /usr/

# Copy entrypoint script into container
COPY docker_entrypoint.sh /docker_entrypoint.sh

# Give executable permission 
RUN chmod +x /docker_entrypoint.sh

VOLUME /data

EXPOSE 80
EXPOSE 443

# Handle signals with tini
ENTRYPOINT ["/usr/bin/tini", "--"]

# Run openresty
CMD ["/docker_entrypoint.sh"]

