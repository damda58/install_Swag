#!/usr/bin/env bash
if [ "$VERBOSE" == "yes" ]; then set -x; fi
YW=$(echo "\033[33m")
RD=$(echo "\033[01;31m")
BL=$(echo "\033[36m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
RETRY_NUM=10
RETRY_EVERY=3
NUM=$RETRY_NUM
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
BFR="\\r\\033[K"
HOLD="-"
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
silent() { "$@" > /dev/null 2>&1; }
function error_exit() {
  trap - ERR
  local reason="Unknown failure occurred."
  local msg="${1:-$reason}"
  local flag="${RD}‼ ERROR ${CL}$EXIT@$LINE"
  echo -e "$flag $msg" 1>&2
  exit $EXIT
}

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

msg_info "Setting up Container OS "
sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen
locale-gen >/dev/null
while [ "$(hostname -I)" = "" ]; do
  echo 1>&2 -en "${CROSS}${RD} No Network! "
  sleep $RETRY_EVERY
  ((NUM--))
  if [ $NUM -eq 0 ]; then
    echo 1>&2 -e "${CROSS}${RD} No Network After $RETRY_NUM Tries${CL}"
    exit 1
  fi
done
msg_ok "Set up Container OS"
msg_ok "Network Connected: ${BL}$(hostname -I)"

set +e
alias die=''
if nc -zw1 8.8.8.8 443; then msg_ok "Internet Connected"; else
  msg_error "Internet NOT Connected"
    read -r -p "Would you like to continue anyway? <y/N> " prompt
    if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]; then
      echo -e " ⚠️  ${RD}Expect Issues Without Internet${CL}"
    else
      echo -e " 🖧  Check Network Settings"
      exit 1
    fi
fi
RESOLVEDIP=$(nslookup "github.com" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)
if [[ -z "$RESOLVEDIP" ]]; then msg_error "DNS Lookup Failure"; else msg_ok "DNS Resolved github.com to $RESOLVEDIP"; fi
alias die='EXIT=$? LINE=$LINENO error_exit'
set -e

msg_info "Updating Container OS"
$STD apt update
#$STD apt upgrade
msg_ok "Updated Container OS"
export DHLEVEL=2048
export ONLY_SUBDOMAINS=false
export AWS_CONFIG_FILE=/config/dns-conf/route53.ini
export S6_BEHAVIOUR_IF_STAGE2_FAILS=2
export CERTBOT_VERSION=2.2.0

msg_info "**** install build packages ****"
apt install -y cargo g++ gcc libffi-dev libxml2-dev libxslt-dev openssl python3-dev
msg_info "**** install runtime packages ****"
apt install -y curl fail2ban gnupg memcached nginx libnginx-mod-http-dav-ext libnginx-mod-http-echo libnginx-mod-http-fancyindex libnginx-mod-http-geoip2 libnginx-mod-http-image-filter libnginx-mod-http-perl libnginx-mod-http-xslt-filter libnginx-mod-mail libnginx-mod-rtmp libnginx-mod-stream libnginx-mod-stream-geoip2 libnginx-mod-http-uploadprogress libnginx-mod-http-headers-more-filter
msg_info "**** install php extensions ****"
$STD apt install -y php-bcmath php-bz2 php-ctype php-curl php-dom php-exif php-ftp php-gd php-gmp php-iconv php-imap php-intl php-ldap php-mysqli php-mysqlnd php-opcache php-pear php-apcu-bc dh-php php-pgsql php-phar php-posix php-soap php-sockets php-sqlite3 php-tokenizer php-xml php-xmlreader php-xsl php-zip php-xmlrpc
msg_info "**** install python modules ****"
$STD apt install -y python3-cryptography python3-future python3-pip whois
msg_info "**** install certbot and plugin****"
$STD pip install certbot certbot-dns-acmedns certbot-dns-aliyun certbot-dns-azure certbot-dns-cloudflare certbot-dns-cpanel certbot-dns-desec certbot-dns-digitalocean certbot-dns-directadmin certbot-dns-dnsimple certbot-dns-dnsmadeeasy certbot-dns-dnspod certbot-dns-do certbot-dns-domeneshop certbot-dns-duckdns certbot-dns-dynu certbot-dns-gehirn certbot-dns-godaddy certbot-dns-google certbot-dns-he certbot-dns-hetzner certbot-dns-infomaniak certbot-dns-inwx certbot-dns-ionos certbot-dns-linode certbot-dns-loopia certbot-dns-luadns certbot-dns-netcup certbot-dns-njalla certbot-dns-nsone certbot-dns-ovh certbot-dns-porkbun certbot-dns-rfc2136 certbot-dns-route53 certbot-dns-sakuracloud certbot-dns-standalone certbot-dns-transip certbot-dns-vultr certbot-plugin-gandi cryptography requests
msg_info "**** Download defaults files****"
$STD mkdir /DC
$STD mkdir /defaults
$STD cd /DC 
$STD wget https://github.com/linuxserver/docker-swag/archive/refs/heads/master.zip
$STD apt install -y unzip
$STD unzip master.zip
$STD rm master.zip
$STD mv /DC/docker-swag-master/root/defaults /
$STD mv /DC/docker-swag-master/root/app /
$STD mv -u /DC/docker-swag-master/root/etc/logrotate.d/fail2ban /etc/logrotate.d/
$STD mv -u /DC/docker-swag-master/root/etc/logrotate.d/lerotate /etc/logrotate.d/
$STD mv -u /DC/docker-swag-master/root/etc/crontabs/root /etc/crontabs/root
$STD mv -u /DC/docker-swag-master/root/etc/services.d/ /etc

msg_info "**** remove unnecessary fail2ban filters ****"
$STD rm /etc/fail2ban/jail.d/defaults-debian.conf
$STD rm -r /defaults/fail2ban/filter.d
msg_info "**** copy fail2ban default action and filter to /defaults ****"
$STD mv /etc/fail2ban/action.d /defaults/fail2ban/
$STD mv /etc/fail2ban/filter.d /defaults/fail2ban/

echo "**** copy proxy confs to /defaults ****"
$STD mkdir -p /defaults/nginx/proxy-confs
$STD curl -o /tmp/proxy-confs.tar.gz -L "https://github.com/linuxserver/reverse-proxy-confs/tarball/master"
$STD tar xf /tmp/proxy-confs.tar.gz -C /defaults/nginx/proxy-confs --strip-components=1 --exclude=linux*/.editorconfig --exclude=linux*/.gitattributes --exclude=linux*/.github --exclude=linux*/.gitignore --exclude=linux*/LICENSE

