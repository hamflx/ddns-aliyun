#!/bin/bash

function do_install () {
    HOME_DIR="$(cat /etc/passwd | grep -P ""^$1:"" | cut -d: -f6)"
    DDNS_CONF_DIR="$HOME_DIR/.ddns"
    SCRIPT_PATH="$(readlink -f ""$0"")"
    SOURCE_DIR="$(dirname ""$SCRIPT_PATH"")"

    if [[ ! -d "$HOME_DIR" ]]; then
        echo "Home directory $HOME_DIR not found"
        return 1
    fi

    mkdir -p "$DDNS_CONF_DIR" 2>/dev/null                                           && \
        cp -r "$SOURCE_DIR/bin/"* /usr/bin 2>/dev/null                              && \
        cp -r "$SOURCE_DIR/.ddns/"* "$DDNS_CONF_DIR" 2>/dev/null                    && \
        cp -r "$SOURCE_DIR/lib/systemd/system/"* /lib/systemd/system 2>/dev/null    && \
        chown -R "$1.$1" "$DDNS_CONF_DIR" 2>/dev/null                               && \
        chmod 0755 /usr/bin/ddns.sh 2>/dev/null                                     && \
        chmod 0700 "$DDNS_CONF_DIR" 2>/dev/null                                     && \
        chmod 0600 "$DDNS_CONF_DIR/"* 2>/dev/null

    if [[ "$?" != "0" ]]; then
        echo 'Failed to copy files to system.'
        return 1
    fi

    return 0
}

function do_uninstall () {
    HOME_DIR="$(cat /etc/passwd | grep -P ""^$1:"" | cut -d: -f6)"
    DDNS_CONF_DIR="$HOME_DIR/.ddns"
    SCRIPT_PATH="$(readlink -f ""$0"")"
    SOURCE_DIR="$(dirname ""$SCRIPT_PATH"")"

    if [[ ! -d "$HOME_DIR" ]]; then
        echo "Home directory $HOME_DIR not found"
        return 1
    fi

    rm -f /lib/systemd/system/ddns.service 2>/dev/null
    rm -f /usr/bin/ddns.sh 2>/dev/null
    rm -f "$DDNS_CONF_DIR/"* 2>/dev/null
    rmdir "$DDNS_CONF_DIR" 2>/dev/null

    return 0
}

function usage () {
    echo "Usage:"
    echo "    ddns.sh install <username>"
    echo "    ddns.sh uninstall <username>"
}

if [[ "$#" != "2" ]]; then
    usage
    exit 0
fi

COMMAND="$1"
shift
USERNAME="$1"
shift

if [[ "$COMMAND" == "--help" || "$COMMAND" == "-h" ]]; then
    usage
    exit 0
fi

if ! id "$USERNAME" >/dev/null 2>&1; then
    echo "User $USERNAME not exists"
    exit 1
fi

if [[ "$(id -u)" != "0" ]]; then
    echo "Require root permission."
    exit 1
fi

if [[ "$COMMAND" == "uninstall" ]]; then
    do_uninstall "$USERNAME"
    echo "Uninstalled successfully"
else
    do_install "$USERNAME"

    if [[ "$?" == "0" ]]; then
        echo "Installed successfully"
    else
        echo "Failed to install."
        echo "Uninstalling ..."

        do_uninstall "$USERNAME"

        exit 1
    fi
fi
