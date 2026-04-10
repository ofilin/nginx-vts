FROM alpine:3.21 AS builder

ARG NGINX_VERSION=1.29.8
ARG VTS_VERSION=v0.2.4

RUN apk add --no-cache \
    git gcc libc-dev make openssl-dev pcre-dev zlib-dev linux-headers curl

RUN mkdir -p /usr/src && \
    cd /usr/src && \
    curl -fSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx.tar.gz && \
    tar -xzf nginx.tar.gz && \
    mv nginx-${NGINX_VERSION} nginx

RUN git clone --depth 1 --branch ${VTS_VERSION} \
    https://github.com/vozlt/nginx-module-vts.git /usr/src/nginx-module-vts

WORKDIR /usr/src/nginx

# Собираем Nginx с модулем VTS (статическая сборка)
RUN ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --add-module=/usr/src/nginx-module-vts && \
    make && \
    make install

FROM alpine:3.21

# Копируем собранный Nginx и всё необходимое
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx

RUN apk add --no-cache openssl pcre zlib ca-certificates && \
    mkdir -p /var/cache/nginx /var/log/nginx /etc/nginx/conf.d && \
    adduser -D -H -s /sbin/nologin -u 1000 nginx

# Создаем минимальный nginx.conf с поддержкой VTS
RUN cat > /etc/nginx/nginx.conf <<'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    keepalive_timeout 65;
    gzip on;
    
    # Включаем VTS
    vhost_traffic_status_zone;
    vhost_traffic_status_filter_by_host on;
    
    include /etc/nginx/conf.d/*.conf;
}
EOF

# Создаем простой location для метрик
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