FROM debian:oldstable

# instal dependencies
RUN <<EOF
apt update
apt install -y php8.2-fpm php8.2-mysql wget mariadb-server
rm -rf /var/lib/mysql/*
rm -rf /var/lib/apt/lists/*
EOF

# install wordpress easier way
RUN <<EOF
wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp
EOF

# needed because php-fpm expects that
RUN mkdir -p /run/php

# copy conf file (https://devanswers.net/php-fpm-configuration-file-location/)
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

# copy init file
COPY tools/init.sh /init.sh
RUN chmod +x /init.sh

# open 9000 port
EXPOSE 8080

# executes init.sh from the container created
ENTRYPOINT [ "/init.sh" ]
