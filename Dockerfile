FROM hersheltheodorelayton/hhvm-full:beta
ENV COMPOSER=composer.dev.json

WORKDIR /mnt/project

COPY . .
COPY .hhconfig /etc/hh.conf
CMD composer update && bin/pha-linters-server.sh -s -e
