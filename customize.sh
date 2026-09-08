#!/bin/sh

set -eu

source_root="${1:-openwrt}"
config_generate="$source_root/package/base-files/files/bin/config_generate"
default_settings="$source_root/package/lean/default-settings/files/zzz-default-settings"
default_network="$source_root/package/base-files/files/etc/board.d/99-default_network"

require_file() {
  if [ ! -f "$1" ]; then
    echo "customize.sh: required upstream file not found: $1" >&2
    exit 1
  fi
}

require_exact_line() {
  file="$1"
  line="$2"
  description="$3"

  if ! grep -Fqx "$line" "$file"; then
    echo "customize.sh: upstream $description changed in $file" >&2
    exit 1
  fi
}

require_single_match() {
  file="$1"
  text="$2"
  description="$3"
  count="$(grep -Fc "$text" "$file" || true)"

  if [ "$count" -ne 1 ]; then
    echo "customize.sh: expected one $description match in $file, found $count" >&2
    exit 1
  fi
}

require_file "$config_generate"
require_file "$default_settings"
require_file "$default_network"

# Keep the generic x86 network assignment unchanged: eth0 is LAN, eth1 is WAN.
require_exact_line "$default_network" "ucidef_set_interface_lan 'eth0'" \
  'generic LAN interface assignment'
require_exact_line "$default_network" "[ -d /sys/class/net/eth1 ] && ucidef_set_interface_wan 'eth1'" \
  'generic WAN interface assignment'

# Change only the generated LAN address. Requiring the exact upstream line makes
# an upstream rewrite fail loudly instead of silently leaving 192.168.1.1 behind.
old_lan='lan) ipad=${ipaddr:-"192.168.1.1"} ;;'
new_lan='lan) ipad=${ipaddr:-"192.168.5.1"} ;;'
require_single_match "$config_generate" "$old_lan" 'default LAN address expression'
sed -i 's|192\.168\.1\.1|192.168.5.1|' "$config_generate"
require_single_match "$config_generate" "$new_lan" 'customized LAN address expression'

# LEDE currently injects its default root password through this hash twice, for
# the shadow formats used by opkg and apk images. Removing the hash preserves an
# empty root password. Fail if the upstream mechanism changes.
password_hash='$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.'
password_hash_count="$(grep -Foc "$password_hash" "$default_settings" || true)"
if [ "$password_hash_count" -ne 2 ]; then
  echo "customize.sh: expected the LEDE root password hash twice, found $password_hash_count" >&2
  exit 1
fi
sed -i 's|\$1\$V4UetPzk\$CYXluq4wUazHjmCDBCqXF\.||g' "$default_settings"
if grep -Fq "$password_hash" "$default_settings"; then
  echo 'customize.sh: failed to clear the LEDE root password hash' >&2
  exit 1
fi

echo 'Applied x86_64 defaults: LAN 192.168.5.1, eth0 LAN, eth1 WAN, empty root password.'
