#!/bin/sh

conf="/usr/local/openresty/nginx/conf/nginx.conf"

CERT_DIR=/usr/local/openresty/nginx/conf/certs
VOLUME_DIR=/data
CRT_KEY=${VOLUME_DIR}/server.key

rm -vrf ${CERT_DIR}
ln -vsf ${VOLUME_DIR} ${CERT_DIR}

# Create self-signed Certificate
if [ ! -f ${CERT_DIR}/server.key ]; then
    echo "Creating SSL certificate..."
    cat > ${CERT_DIR}/openssl.conf <<EOF
[req]
default_bits=4096
encrypt_key=no
default_md=sha256
distinguished_name=req_sub
prompt=no

[req_sub]
commonName="${SSL_COMMON_NAME:-"www.frontdomain.com"}"
emailAddress="${SSL_EMAIL:-"info@frontdomain.com"}"
countryName="${SSL_COUNTRY_CODE:-"TR"}"
stateOrProvinceName="${SSL_PROVINCE:-"Istanbul"}"
localityName="${SSL_LOCALITY:-"Somwhere"}"
organizationName="${SSL_ORG_NAME:-"lab"}"
organizationalUnitName="${SSL_ORG_UNIT_NAME:-"open"}"
EOF

    openssl req -x509 -days 3650 -new \
        -config ${CERT_DIR}/openssl.conf \
        -keyout ${CERT_DIR}/server.key \
        -out ${CERT_DIR}/server.crt
        chmod 644 ${CERT_DIR}/server.key ${CERT_DIR}/server.crt
fi

echo "Setting Nginx configuration..."
export DNS_SERVER=${DNS_SERVER:-$(grep -i '^nameserver' /etc/resolv.conf|head -n1|cut -d ' ' -f2)}

cat > $conf <<EOF
pid /var/run/nginx.pid;
worker_processes auto;

events {
    worker_connections ${WORKER_CONNECTIONS};
    use epoll;
    multi_accept on;
}

http {
    include mime.types;

    default_type application/octet-stream;

    aio threads;
    sendfile on;
    large_client_header_buffers 4 16k;

    ## Timeouts
    client_body_timeout   60;
    client_header_timeout 60;
    keepalive_timeout     10 10;
    send_timeout          60;

    ## TCP options
    tcp_nopush  on;
    tcp_nodelay on;

    ## Hide the Nginx version number
    server_tokens off;

    ## Body size
    client_max_body_size 16M;
    client_body_buffer_size 128k;

    ## Compression
    gzip on;
    gzip_comp_level 5;
    gzip_min_length 256;
    gzip_proxied any;
    gzip_vary on;
    gzip_types
        application/atom+xml
        application/javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rss+xml
        application/vnd.geo+json
        application/vnd.ms-fontobject
        application/x-font-ttf
        application/x-web-app-manifest+json
        application/xhtml+xml
        application/xml
        font/opentype
        image/bmp
        image/svg+xml
        image/x-icon
        text/cache-manifest
        text/css
        text/plain
        text/vcard
        text/vnd.rim.location.xloc
        text/vtt
        text/x-component
        text/x-cross-domain-policy;

    ## Serve already compressed files directly, bypassing on-the-fly compression
    gzip_static on;



    server {
        listen ${PORT};
        listen [::]:${PORT};
    
        resolver ${DNS_SERVER} valid=5s;
        server_name ${FRONT_DOMAIN};
    
        return 301 https://\$server_name:${SPORT}\$request_uri;
    }
   

    server {
        listen ${SPORT} ssl http2;
        listen [::]:${SPORT} ssl http2;
    
        error_log /proc/self/fd/2;
        access_log /proc/self/fd/1;

        resolver ${DNS_SERVER} valid=5s;
        server_name ${FRONT_DOMAIN};

        if (\$scheme = http) {
            return 301 https://\$server_name:\$server_port\$request_uri;
        }
    
        ssl_certificate ${CERT_DIR}/server.crt;
        ssl_certificate_key ${CERT_DIR}/server.key;
        ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;
        ssl_prefer_server_ciphers on;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_verify_client ${SSL_VERIFY};

        location / {
            if (\$request_method = 'OPTIONS') {
                 add_header 'Content-Length' 0;
                 add_header 'Access-Control-Max-Age' 1728000;
                 add_header 'Content-Type' 'text/plain charset=UTF-8';
                 add_header 'access-control-allow-origin' '*';
                 add_header 'Access-Control-Allow-Methods' 'GET,PUT,POST,DELETE,OPTIONS';
                 add_header 'Access-Control-Allow-Headers' 'authorization,ty-web-client-async-mode';
                 return 204;
            }

            set \$proxy '';

            access_by_lua_block
            {
                local headers = ngx.req.get_headers()
                local host = headers['host']

                ngx.var.proxy = string.lower(string.gsub(host, "${FRONT_DOMAIN}.*", "")) .. "${UPSTREAM_DOMAIN}" 

		ngx.header['host'] = string.lower(string.gsub(host, "${FRONT_DOMAIN}.*", "${UPSTREAM_DOMAIN}"))
                ngx.header['origin'] = '${UPSTREAM_HEADER_ORIGIN}'
                ngx.header['access-control-allow-origin'] = '${UPSTREAM_HEADER_ORIGIN}'
                ngx.header['access-control-allow-credentials'] = 'true'
                ngx.header['access-control-allow-headers'] = 'authorization,ty-web-client-async-mode'
                ngx.header['Access-Control-Allow-Methods'] = 'GET,PUT,POST,DELETE,OPTIONS'
            }

            proxy_redirect    off;
            proxy_set_header  Accept-Encoding "";
            proxy_set_header  X-Real-IP \$remote_addr;
            proxy_set_header  X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header  Origin ${UPSTREAM_HEADER_ORIGIN};
            proxy_pass ${UPSTREAM_SCHEME}://\$proxy\$request_uri;

            add_header 'access-control-allow-origin' '\$http_origin';
            add_header 'Access-Control-Allow-Methods' 'GET,PUT,POST,DELETE,OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'authorization,ty-web-client-async-mode';

            header_filter_by_lua_block { 
                ngx.header.content_length = nil
	    }

            body_filter_by_lua_block {
                local body = ngx.arg[1]
                if body then
                        body = ngx.re.gsub(body, "${UPSTREAM_DOMAIN}", "${FRONT_DOMAIN}:${FRONT_SPORT}")
                end
                ngx.arg[1] = body
            }

        }

        location /health {
            access_log off;
            add_header Content-Type text/plain;
            return 200 "OK";
        }

        location /metrics/nginx {
            access_log off;
            allow all;
            proxy_store off;
            stub_status;
        }
    }
}
EOF

/usr/local/openresty/bin/openresty -c $conf -t && \
exec /usr/local/openresty/bin/openresty -c $conf -g "daemon off;"
