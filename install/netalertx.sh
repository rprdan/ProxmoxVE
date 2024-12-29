#!/usr/bin/env bash

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get -y install \
  sudo \
  curl \
  git \
  nginx \
  sqlite3 \
  python3 \
  python3-pip \
  php-fpm \
  php-sqlite3 \
  php-curl \
  arp-scan \
  nmap \
  net-tools \
  nbtscan \
  iproute2 \
  bind9-utils \
  wakeonlan \
  zip \
  traceroute \
  avahi-utils \
  dnsutils \
  net-snmp-tools
msg_ok "Installed Dependencies"

msg_info "Installing Python Dependencies"
$STD pip3 install openwrt-luci-rpc graphene flask netifaces tplink-omada-client \
  wakeonlan pycryptodome requests paho-mqtt scapy cron-converter pytz \
  json2table dhcp-leases pyunifi speedtest-cli chardet python-nmap dnspython \
  librouteros git+https://github.com/foreign-sub/aiofreepybox.git
msg_ok "Installed Python Dependencies"

msg_info "Installing NetAlertX"
# Remove existing installation if present
rm -rf /app
# Create new app directory
mkdir -p /app

# Clone the repository
git clone https://github.com/jokob-sk/NetAlertX.git /app

# Create required directories
mkdir -p /app/{config,db,log}
mkdir -p /var/www/html/netalertx

# Setup nginx configuration
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    mv /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default.backup
fi

ln -sf /app/install/netalertx.debian.conf /etc/nginx/conf.d/netalertx.conf

# Setup permissions
chown -R www-data:www-data /app
chmod -R 750 /app
find /app -type f -exec chmod 640 {} \;
find /app -type f \( -name '*.sh' -o -name '*.py' -o -name 'speedtest-cli' \) -exec chmod 750 {} \;

# Create log files
touch /app/log/{app.log,execution_queue.log,app_front.log,app.php_errors.log,stderr.log,stdout.log,db_is_locked.log}
touch /app/api/user_notifications.json

chown -R www-data:www-data /app/{config,log,db,api}
chmod 750 /app/{config,log,db}
find /app/{config,log,db} -type f -exec chmod 640 {} \;

# Copy default configuration
cp -na /app/back/app.conf /app/config/
cp -na /app/back/app.db /app/db/

# Setup timezone if needed
if [ -n "${TZ}" ]; then
    sed -i "\#^TIMEZONE=#c\TIMEZONE='${TZ}'" /app/config/app.conf
fi

# Run initial vendor update
if [ -f "/app/back/update_vendors.sh" ]; then
    /app/back/update_vendors.sh
fi

msg_ok "Installed NetAlertX"

msg_info "Setting up startup script"
cp /app/install/start.debian.sh /usr/local/bin/netalertx-start
chmod +x /usr/local/bin/netalertx-start
msg_ok "Setup startup script"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"

echo "NetAlertX has been installed. To start it, run: netalertx-start"
echo "The web interface will be available at http://YOUR_IP:20211"
