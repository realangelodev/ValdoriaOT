#!/usr/bin/env bash
# Starts Apache. On the very first start, the MyAAC installer runs in the background with the
# settings from your .env file, so the website is ready without clicking through the wizard.
set -euo pipefail

if [ ! -f /var/www/html/install/install.lock ]; then
  /usr/local/bin/install-myaac.sh &
fi

exec apachectl -D FOREGROUND
