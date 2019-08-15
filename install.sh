#!/bin/bash

function do_install () {
    cp -r bin/* /usr/bin 2>/dev/null &&
        cp -r etc/* /etc 2>/dev/null &&
        cp -r lib/systemd/system/* /lib/systemd/system 2>/dev/null &&
        chmod 0755 /usr/bin/ddns.sh 2>/dev/null &&
        chmod 0660 /etc/ddns/aliyun/config.json 2>/dev/null

    return $?
}

function do_uninstall () {
    rm -f /lib/systemd/system/ddns.service 2>/dev/null
    rm -rf /etc/ddns 2>/dev/null
    rm -f /usr/bin/ddns.sh 2>/dev/null

    return 0
}

if [[ "$(id -u)" != "0" ]]; then
    echo "Require root permission!"
    exit 1
fi

if [[ "$1" == "uninstall" ]]; then

    do_uninstall

    echo "Uninstalled successfully"

else

    do_install

    if [[ "$?" == "0" ]]; then
        echo "Installed successfully"
    else
        echo "Failed to install!"
        echo "Uninstalling ..."

        do_uninstall

        exit 1
    fi

fi
