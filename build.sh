#!/bin/bash
#
# Bootstrap the debian
#
source "$(dirname $(realpath ${BASH_SOURCE[0]}))/functions.sh"
config "$(dirname $0)/config.sh"
config "$(dirname $0)/config-local.sh"

#
# Config variables
#
: ${CONFIG_ALPINE_ARCH:=x86_64}
: ${CONFIG_ALPINE_REPOSITORY:=http://dl-cdn.alpinelinux.org/alpine}
: ${CONFIG_ALPINE_VERSION:=v3.24}
: ${CONFIG_MACHINE_ID:=}
: ${CONFIG_BUILD_TMP_DIR:="$(dirname $0)/tmp"}
: ${CONFIG_BUILD_HOOK_DIR:="$(dirname $0)/build-hooks"}

if [ -z "$1" ]; then
    echo "usage: $(basename $0) <ROOT>"
    exit 1
fi

ensure_ROOT "$1"

if [ -d "${ROOT}/lost+found" ]; then
    if [ -z "$(ls -A ${ROOT}/lost+found)" ]; then
        sudo \
        rmdir "${ROOT}/lost+found"
    fi
fi

# ...and check then check again.
if [ ! -z "$(ls -A ${ROOT})" ]; then
    echo "Root directory is not empty: ${ROOT}"
    echo "Please remove all files an retry"
    exit 2
fi

#
# Make CONFIG_BUILD_TMP_DIR visisible to hooks
#
mkdir -p "$CONFIG_BUILD_TMP_DIR"
export CONFIG_BUILD_TMP_DIR

#
# Download APK tools
#
apkdir="$CONFIG_BUILD_TMP_DIR/apktools"
if [ ! -x "$apkdir//sbin/apk.static" ]; then
    mkdir -p "$apkdir"
    wget -qO- "$CONFIG_ALPINE_REPOSITORY/latest-stable/main/x86/apk-tools-static-3.0.8-r0.apk" \
        | tar -xz -C $apkdir || \
        { echo "couldn't download apk-tools, the version might have changed..." >&2; exit 1; }
fi
apk="$apkdir/sbin/apk.static"

sudo $apk \
    -X $CONFIG_ALPINE_REPOSITORY/$CONFIG_ALPINE_VERSION/main -U --arch $CONFIG_ALPINE_ARCH \
    --allow-untrusted --root "${ROOT}" \
    --initdb add alpine-base

#
# Configure repositories
#
echo "
$CONFIG_ALPINE_REPOSITORY/$CONFIG_ALPINE_VERSION/main
$CONFIG_ALPINE_REPOSITORY/$CONFIG_ALPINE_VERSION/community
" | sudo tee "${ROOT}/etc/apk/repositories"

#
# Disable getty on ttys (there are no ttys when running as container)
# and enable getty console (/dev/console) which should always be available
#
sudo sed '/tty[0-9]:/ s/^/#/' -i "${ROOT}"/etc/inittab
echo '
console::respawn:/sbin/getty 38400 console
' | sudo tee -a "${ROOT}"/etc/inittab

#
# Enable minimal boot services. Not sure yet why this is
# needed :-)
#
for s in hostname bootmisc syslog; do
    ln -s /etc/init.d/$s "${ROOT}/etc/runlevels/boot/$s"
done
for s in killprocs savecache; do
    ln -s /etc/init.d/$s "${ROOT}/etc/runlevels/shutdown/$s"
done