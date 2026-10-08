FROM debian:oldstable

RUN <<EOF
apt update
apt install -y nginx openssl
rm -rf /var/lib/apt/lists/*
EOF

COPY conf/nginx.conf /etc/nginx/nginx.conf

COPY tools/init.sh /init.sh
RUN chmod +x /init.sh

EXPOSE 443

ENTRYPOINT [ "/init.sh" ]