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
  mc \
  curl \
  apt-utils \
  avahi-utils \
  lighttpd \
  sqlite3 \
  mmdb-bin \
  arp-scan \
  dnsutils \
  net-tools \
  nbtscan \
  libwww-perl \
  nmap \
  zip \
  aria2 \
  wakeonlan \
  traceroute \
  net-snmp-tools
msg_ok "Installed Dependencies"

msg_info "Installing PHP Dependencies"
$STD apt-get -y install \
  php \
  php-cgi \
  php-fpm \
  php-curl \
  php-xml \
  php-sqlite3 \
  php-session
$STD lighttpd-enable-mod fastcgi-php
service lighttpd force-reload
msg_ok "Installed PHP Dependencies"

msg_info "Installing Python Dependencies"
$STD apt-get -y install \
  python3-pip \
  python3-requests \
  python3-tz \
  python3-tzlocal \
  python3-venv
$STD pip3 install openwrt-luci-rpc graphene flask netifaces tplink-omada-client \
  wakeonlan pycryptodome requests paho-mqtt scapy cron-converter pytz \
  json2table dhcp-leases pyunifi speedtest-cli chardet python-nmap dnspython \
  librouteros git+https://github.com/foreign-sub/aiofreepybox.git
msg_ok "Installed Python Dependencies"

msg_info "Installing NetAlertX"
TEMP_DIR=$(mktemp -d)
curl -sL https://api.github.com/repos/jokob-sk/NetAlertX/tarball/ -o "${TEMP_DIR}/netalertx.tar.gz"
tar xzf "${TEMP_DIR}/netalertx.tar.gz" -C "${TEMP_DIR}"
EXTRACTED_DIR=$(ls "${TEMP_DIR}" | grep "jokob-sk-NetAlertX")
mv "${TEMP_DIR}/${EXTRACTED_DIR}" /opt/netalertx
rm -rf "${TEMP_DIR}" /var/www/html/index.html

# Setup web interface
mv /var/www/html/index.lighttpd.html /var/www/html/index.lighttpd.html.old
ln -s /opt/netalertx/install/index.html /var/www/html/index.html
ln -s /opt/netalertx/front /var/www/html/netalertx

# Set permissions
chmod -R 750 /opt/netalertx
find /opt/netalertx -type f -exec chmod 640 {} \;
find /opt/netalertx -type f \( -name '*.sh' -o -name '*.py' -o -name 'speedtest-cli' \) -exec chmod 750 {} \;
chgrp -R www-data /opt/netalertx/db /opt/netalertx/front/reports /opt/netalertx/config
chmod -R 775 /opt/netalertx/db /opt/netalertx/config /opt/netalertx/front/reports

# Create and link log files
mkdir -p /opt/netalertx/log
touch /opt/netalertx/log/netalert.vendors.log /opt/netalertx/log/netalert.IP.log \
      /opt/netalertx/log/netalert.1.log /opt/netalertx/log/netalert.cleanup.log \
      /opt/netalertx/log/netalert.webservices.log

for file in netalert.vendors.log netalert.IP.log netalert.1.log netalert.cleanup.log netalert.webservices.log; do
    ln -s "/opt/netalertx/log/$file" "/opt/netalertx/front/php/server/$file"
done

# Setup configuration
sed -i 's#NETALERT_PATH\s*=\s*'\''/home/pi/netalert'\''#NETALERT_PATH = '\''/opt/netalertx'\''#' /opt/netalertx/config/netalert.conf
sed -i 's/$HOME/\/opt/g' /opt/netalertx/install/netalert.cron
crontab /opt/netalertx/install/netalert.cron

# Create convenience commands
echo "python3 /opt/netalertx/back/netalert.py 1" >/usr/bin/scan
chmod +x /usr/bin/scan
echo "/opt/netalertx/back/netalert-cli set_permissions --lxc" >/usr/bin/permissions
chmod +x /usr/bin/permissions
echo "/opt/netalertx/back/netalert-cli set_sudoers --lxc" >/usr/bin/sudoers
chmod +x /usr/bin/sudoers
msg_ok "Installed NetAlertX"

msg_info "Start NetAlertX Scan (Patience)"
$STD python3 /opt/netalertx/back/netalert.py update_vendors
$STD python3 /opt/netalertx/back/netalert.py internet_IP
$STD python3 /opt/netalertx/back/netalert.py 1
msg_ok "Finished NetAlertX Scan"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
