#!/bin/bash
#
# Add user (same as user who run the build) and
#
# * install its ssh pubkey
# * add it to sudoers
# * add it to the `sudo` and `adm` groups
#
source "$(dirname $(realpath ${BASH_SOURCE[0]}))/../functions.sh"
config "$(dirname $0)/../config.sh" || error "Cannot read config.sh: $1"
config "$(dirname $0)/../config-local.sh"
ensure_ROOT $1

#
# Config variables.
#
# NEVER, EVER put CONFIG_USER_PASS to config.sh and commit!
# Alpine uses sha-256 - to generate password hash, use:
#
#     mkpasswd -m sha-512
#
#
: ${CONFIG_USER_NAME:=$USER}
: ${CONFIG_USER_ID:=$(id --user $CONFIG_USER_NAME)}
: ${CONFIG_USER_PASS:=$(sudo grep $CONFIG_USER_NAME /etc/shadow | cut -d : -f 2)} 

: ${CONFIG_GROUP_NAME:=$(id --group --name $CONFIG_USER_NAME)}
: ${CONFIG_GROUP_ID:=$(id --group $CONFIG_USER_NAME)}
#
# Create and setup user
#
env
apk --root "$ROOT" add sudo

if [ "$CONFIG_USER_NAME" != "root" ]; then
        echo "Creating group $CONFIG_GROUP_NAME..."
        echo "Creating user $CONFIG_USER_NAME..."
        groupadd --root "${ROOT}" --gid=$CONFIG_GROUP_ID $CONFIG_GROUP_NAME || true
        usermod --root "${ROOT}" \
                 --uid $(id --user $CONFIG_USER_ID) \
                 --gid=$(id --group $CONFIG_GROUP_ID) \
                 --groups wheel,adm \
                 --password "$CONFIG_USER_PASS" \
                 $CONFIG_USER_NAME
        #
        # No, do not expire the password since user cannot
        # set the same password again.
        #
        # chroot "${ROOT}" /usr/bin/passwd --expire $USER
        HOME_IN_ROOT="$ROOT/$(grep $USER "${ROOT}/etc/passwd" | cut -d : -f 6)"

        #
        # Automatically start tmux when logging in over SSH
        #
        cat >> "$HOME_IN_ROOT/.profile" <<EOF

# Attach / run 'tmux' if we're connecting
# via SSH and 'tmux' is installed.
if [ ! -z "\$SSH_CLIENT" -a -z "\$TMUX" ]; then
    if which tmux; then
        exec tmux new-session -A -s main
    fi
fi
EOF

        #
        # Allow $USER to sudo as any user
        #
        cat >${ROOT}/etc/sudoers.d/$CONFIG_USER_NAME <<EOF
${CONFIG_USER_NAME}     ALL=(ALL:ALL) ALL
EOF
        #
        # Install SSH keys
        #
        for pubkey in id_rsa.pub id_dsa.pub; do
                if [ -r "$HOME/.ssh/$pubkey" ]; then
                        mkdir -p "$HOME_IN_ROOT/.ssh"
                        cat "$HOME/.ssh/$pubkey" >> "$HOME_IN_ROOT/.ssh/authorized_keys"
                        chmod -R go-rwx "$HOME_IN_ROOT/.ssh"
                fi
        done
        #
        # Disable root login
        #
        chroot "$ROOT" passwd -l root

        #
        # Finally, make sure all files are owned by $CONFIG_USER_NAME
        #
        chown -R $CONFIG_USER_NAME:$CONFIG_GROUP_NAME "$HOME_IN_ROOT"
fi