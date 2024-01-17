#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM debian:bookworm-slim

# roughly, https://salsa.debian.org/haproxy-team/haproxy/-/blob/732b97ae286906dea19ab5744cf9cf97c364ac1d/debian/haproxy.postinst#L5-6
RUN set -eux; \
        groupadd --gid 99 --system haproxy; \
        useradd \
                --gid haproxy \
                --home-dir /var/lib/haproxy \
                --no-create-home \
                --system \
                --uid 99 \
                haproxy \
        ; \
        mkdir /var/lib/haproxy; \
        chown haproxy:haproxy /var/lib/haproxy

# see https://sources.debian.net/src/haproxy/jessie/debian/rules/ for some helpful navigation of the possible "make" arguments
RUN set -eux; \
        \
        savedAptMark="$(apt-mark showmanual)"; \
        apt-get update && apt-get install -y --no-install-recommends \
                ca-certificates \
                gcc \
                git \
                libc6-dev \
                liblua5.3-dev \
                libpcre3-dev \
                libssl-dev \
                make \
                zlib1g-dev \
        ; \
        rm -rf /var/lib/apt/lists/*; \
        \
        git clone https://github.com/quictls/openssl.git; \
        cd openssl; git checkout OpenSSL_1_1_1w+quic; \
        mkdir -p /opt/quictls; ./config --libdir=lib --prefix=/opt/quictls; \
        make; make install; \
        cd ..; git clone https://github.com/haproxy/haproxy.git; \
        cd haproxy; git checkout v2.9.0; \
        make \
                TARGET=linux-glibc \
                USE_GETADDRINFO=1 \
                USE_LUA=1 \
                USE_PCRE=1 \
                USE_ZLIB=1 \
                USE_PROMEX=1 \
                USE_QUIC=1 \
                USE_OPENSSL=1 \
                SSL_INC=/opt/quictls/include \
                SSL_LIB=/opt/quictls/lib \
                LDFLAGS="-Wl,-rpath,/opt/quictls/lib" \
        ; \
        make install-bin; mkdir -p /usr/local/etc/haproxy; \
        # clean up build deps \
        cd ..; rm -rf openssl/ haproxy/; \
        apt-get purge -y --auto-remove gcc git make; \
        apt-get clean; rm -rf /var/lib/apt/lists/*; \
        \
        # smoke test \
        haproxy -v

STOPSIGNAL SIGUSR1

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

USER haproxy

WORKDIR /var/lib/haproxy

CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
