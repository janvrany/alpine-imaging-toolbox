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
: ${CONFIG_ALPINE_MIRROR:=http://dl-cdn.alpinelinux.org/alpine}
: ${CONFIG_ALPINE_VERSION:=latest-stable}
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
# Bootstrap
#
sudo /usr/sbin/alpine-chroot-install \
    -a "$CONFIG_ALPINE_ARCH" \
    -b "$CONFIG_ALPINE_VERSION" \
    -m "$CONFIG_ALPINE_MIRROR" \
    -p "alpine-base" \
    -d "$(realpath ${ROOT})" \
    -t "$(realpath ${CONFIG_BUILD_TMP_DIR})"

#
# Disable getty on ttys (there are no ttys when running as container)
# and enable getty console (/dev/console) which should always be available
#
sudo sed '/tty[0-9]:/ s/^/#/' -i "${ROOT}"/etc/inittab
echo '
console::respawn:/sbin/getty 38400 console
' | sudo tee -a "${ROOT}"/etc/inittab


#
# Run hooks
#
for hook in $(run-parts --list --regex "customize.*\.sh" "$CONFIG_BUILD_HOOK_DIR"); do
    echo "---"
    echo "Running hook $hook"
    echo ""
    sudo -E "$hook" "$ROOT"
done