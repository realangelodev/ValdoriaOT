# MyAAC 1.9.5: the website where players create accounts and characters. Apache with PHP 8.3 on Ubuntu 24.04.
FROM ubuntu:24.04
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    apache2 libapache2-mod-php php-cli php-mysql php-gd php-zip php-xml php-mbstring php-curl php-intl \
    unzip curl ca-certificates tzdata \
 && a2enmod rewrite \
 && sed -ri 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf \
 && ln -sf /dev/stdout /var/log/apache2/access.log \
 && ln -sf /dev/stderr /var/log/apache2/error.log \
 && rm -rf /var/lib/apt/lists/* /var/www/html/index.html
ADD --checksum=sha256:6154aecd52359a788e8681027b7b58feca7ab2521442760d1e41925104dba1e7 \
    https://github.com/slawkens/myaac/releases/download/v1.9.5/myaac-1.9.5.zip /tmp/myaac.zip
RUN unzip -q /tmp/myaac.zip -d /tmp \
 && cp -a /tmp/myaac-1.9.5/. /var/www/html/ \
 && rm -rf /tmp/myaac.zip /tmp/myaac-1.9.5 \
 && chown -R www-data:www-data /var/www/html
COPY entrypoint.sh install-myaac.sh /usr/local/bin/
# Strip Windows line endings in case the repo was checked out with them.
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh /usr/local/bin/install-myaac.sh \
 && chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/install-myaac.sh
EXPOSE 80
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
