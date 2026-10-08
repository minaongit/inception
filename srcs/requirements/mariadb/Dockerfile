FROM debian:oldstable

# install mariadb-server
RUN <<EOF
apt update
apt install -y mariadb-server
rm -rf /var/lib/apt/lists/*
EOF

# copy conf
COPY conf/my.cnf /etc/mysql/mariadb.conf.d/99-custom.cnf

# copy init.sh
COPY tools/init.sh /init.sh
RUN chmod +x /init.sh

# expose the port
EXPOSE 3306

ENTRYPOINT [ "/init.sh" ]