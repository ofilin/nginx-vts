FROM alpine:3.23 AS builder

ARG NGINX_VERSION
ARG VTS_VERSION

RUN apk add --no-cache \
    git gcc libc-dev make openssl-dev pcre-dev zlib-dev linux-headers curl

RUN mkdir -p /usr/src && \
    cd /usr/src && \
    curl -fSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx.tar.gz && \
    tar -xzf nginx.tar.gz && \
    mv nginx-${NGINX_VERSION} nginx

RUN git clone --depth 1 --branch ${VTS_VERSION} \
    https://github.com/vozlt/nginx-module-vts.git /usr/src/nginx-module-vts

WORKDIR /usr/src/nginx-module-vts

RUN ./configure \
    --add-module=/usr/src/nginx-module-vts \
    --with-cc-opt='-O2 -pipe' && \
    make

FROM nginx:${NGINX_VERSION}-alpine

COPY --from=builder /usr/src/nginx-module-vts/objs/ngx_http_vhost_traffic_status_module.so \
    /usr/lib/nginx/modules/

RUN echo "load_module /usr/lib/nginx/modules/ngx_http_vhost_traffic_status_module.so;" \
    > /etc/nginx/modules-enabled/50-vts.conf

RUN sed -i '/http {/a \    vhost_traffic_status_zone;\n    vhost_traffic_status_filter_by_host on;' \
    /etc/nginx/nginx.conf

RUN cat > /etc/nginx/conf.d/status.conf <<'EOF'
server {
    listen 80 default_server;
    server_name _;
    location /status {
        vhost_traffic_status_display;
        vhost_traffic_status_display_format prometheus;
        allow all;
    }
}
EOF

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

