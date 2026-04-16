ARG NGINX_VERSION=1.30.0
ARG VTS_VERSION=v0.2.5
ARG ALPINE_VERSION=3.23

FROM alpine:${ALPINE_VERSION} AS builder
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

WORKDIR /usr/src/nginx

RUN ./configure --with-compat --add-dynamic-module=/usr/src/nginx-module-vts && \
    make modules

FROM nginx:${NGINX_VERSION}-alpine

# Копируем модуль
COPY --from=builder /usr/src/nginx/objs/ngx_http_vhost_traffic_status_module.so \
    /etc/nginx/modules/

# Загружаем модуль
RUN sed -i '1i load_module /etc/nginx/modules/ngx_http_vhost_traffic_status_module.so;\n' \
    /etc/nginx/nginx.conf

# Добавляем VTS настройки в http блок
RUN sed -i '/http {/a \    vhost_traffic_status_zone;\n    vhost_traffic_status_filter_by_host on;' \
    /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
