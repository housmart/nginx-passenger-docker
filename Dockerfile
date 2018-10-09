FROM debian:jessie

### Set target versions
ENV DEBIAN_FRONTEND=noninteractive \
  HOME=/root \
  PATH=/usr/local/rvm/bin:$PATH \
  MORE_HERADER_VERSION=0.33 \
  RUBY_VERSION=2.4.4

WORKDIR /root

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
  echo 'APT::Get::Clean=always;' >> /etc/apt/apt.conf.d/99AutomaticClean
RUN apt-get update && apt-get install -y sudo build-essential unzip uuid-dev zlib1g-dev libpcre3 libpcre3-dev unzip wget curl libcurl4-openssl-dev nodejs tzdata

ENV TZ=Asia/Tokyo

### Download nginx and headers-more-nginx-module source
RUN wget https://github.com/openresty/headers-more-nginx-module/archive/v${MORE_HERADER_VERSION}.zip && \
  unzip v${MORE_HERADER_VERSION}.zip && \
  rm v${MORE_HERADER_VERSION}.zip

### Install RVM and passenger
RUN curl -sSL https://rvm.io/mpapis.asc | gpg --import - && \
  curl -L https://get.rvm.io | /bin/bash -s stable && \
  echo 'source /etc/profile.d/rvm.sh' >> /etc/profile && \
  echo 'source /etc/profile.d/rvm.sh' >> /root/.bashrc && \
  rvm requirements && \
  rvm install ${RUBY_VERSION} && \
  bash -l -c "rvm use --default ${RUBY_VERSION} && \
  gem install passenger --no-rdoc --no-ri"

### Build nginx & ngx_pagespeed by passenger-install-nginx-module
RUN adduser --system --no-create-home --disabled-login --disabled-password --group nginx && \
  usermod -g www-data nginx && \
  mkdir -p /var/cache/nginx && \
  bash -l -c "rvmsudo passenger-install-nginx-module --auto-download --auto \
  --extra-configure-flags=\"\
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log --group=nginx \
  --http-client-body-temp-path=/var/cache/nginx/client_temp \
  --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  --http-log-path=/var/log/nginx/access.log \
  --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  --lock-path=/var/run/nginx.lock --pid-path=/var/run/nginx.pid \
  --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --user=nginx \
  --with-file-aio --with-http_addition_module \
  --with-http_auth_request_module --with-http_dav_module \
  --with-http_flv_module --with-http_gunzip_module \
  --with-http_gzip_static_module --with-http_mp4_module \
  --with-http_random_index_module --with-http_realip_module \
  --with-http_secure_link_module --with-http_slice_module \
  --with-http_ssl_module --with-http_stub_status_module \
  --with-http_sub_module --with-http_v2_module --with-ipv6 --with-mail \
  --with-mail_ssl_module --with-stream --with-stream_ssl_module \
  --with-threads --with-cc-opt='-g -O2 -fstack-protector \
  --param=ssp-buffer-size=4 -Wformat -Werror=format-security \
  -Wp,-D_FORTIFY_SOURCE=2' --with-ld-opt='-Wl,-Bsymbolic-functions \
  -Wl,-z,relro -Wl,--as-needed' \
  --add-module=$HOME/headers-more-nginx-module-${MORE_HERADER_VERSION}\""

# Clean up APT when done.
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 80

STOPSIGNAL SIGTERM
