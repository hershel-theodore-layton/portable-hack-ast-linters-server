FROM hersheltheodorelayton/hhvm-full:25.7.0
ENV COMPOSER=composer.dev.json

WORKDIR /mnt/project

COPY . .
COPY .hhconfig /etc/hh.conf
CMD composer update && \
    bin/pha-linters-server.sh -s -g -b bin/portable-hack-ast-linters-server-bundled.resource
