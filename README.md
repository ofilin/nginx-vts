# NGINX with VTS (Virtual Host Traffic Status)

[![Docker Pulls](https://img.shields.io/docker/pulls/ofilin/nginx-vts)](https://hub.docker.com/r/ofilin/nginx-vts)
[![GitHub Actions](https://github.com/ofilin/nginx-vts/actions/workflows/build.yml/badge.svg)](https://github.com/ofilin/nginx-vts/actions)

Automated Docker build of NGINX with the [nginx-module-vts](https://github.com/vozlt/nginx-module-vts) for detailed per-host traffic monitoring.

## ✨ Features

- ✅ Fully compatible with the official `nginx:latest` image
- ✅ VTS module dynamically linked (no extra downloads)
- ✅ Automatic builds on new NGINX releases
- ✅ Multi-arch support: `linux/amd64`, `linux/arm64`
- ✅ Minimal image size (~25MB)
- ✅ Prometheus-formatted metrics at `/status` endpoint

## 🚀 Quick Start

### Replace official image

```yaml
# docker-compose.yaml
services:
  nginx:
    image: ofilin/nginx-vts:latest
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
```

## Run with Docker CLI
```bash
docker run -d -p 80:80 ofilin/nginx-vts:latest
```

## ⚙️ VTS Configuration
### 1. Add to nginx.conf
```

load_module modules/ngx_http_vhost_traffic_status_module.so;

http {
    # ... your settings ...
    
    # Enable VTS
    vhost_traffic_status_zone;
    vhost_traffic_status_filter_by_host on;  # Group by domain
    
    # ... rest of your config ...
}
```

### 2. Add metrics endpoint
```
server {
    listen 80;
    server_name _;
    
    location /status {
        vhost_traffic_status_display;
        vhost_traffic_status_display_format prometheus;
        
        # Optional: restrict access
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        deny all;
    }
}
```

## 📊 Prometheus Metrics

### Scrape configuration
```
scrape_configs:
  - job_name: 'nginx-vts'
    static_configs:
      - targets: ['nginx:80']
    metrics_path: '/status'
    params:
      format: ['prometheus']
```

## 🔧 Manual Build
```bash
git clone https://github.com/ofilin/nginx-vts.git
cd nginx-vts
docker build \
  --build-arg NGINX_VERSION=1.29.8 \
  --build-arg VTS_VERSION=v0.2.5 \
  -t nginx-vts .
```

## 🔄 Automated Builds

This image is rebuilt daily via GitHub Actions when new NGINX versions are released.

- Source code: [github.com/ofilin/nginx-vts](https://github.com/ofilin/nginx-vts)

- Docker Hub: [hub.docker.com/r/ofilin/nginx-vts](https://hub.docker.com/r/ofilin/nginx-vts)

## 📝 License

- NGINX: [2-clause BSD-like license](https://nginx.org/LICENSE)

- nginx-module-vts: [BSD 2-Clause](https://github.com/vozlt/nginx-module-vts/blob/master/LICENSE)

