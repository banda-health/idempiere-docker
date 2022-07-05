#!/usr/bin/env bash

if [[ $HEALTHY_AFTER_PLUGINS_START == "true" ]]; then
    if [[ -f "/tmp/bundles" ]]; then
        rm /tmp/osgi_bundle_status > /dev/null 2>&1 || true
        touch /tmp/osgi_bundle_status
        eval "$(cat /tmp/bundles)" | telnet localhost 12612 2>&1 | grep -i "_" >> /tmp/osgi_bundle_status
        if [[ $(cat /tmp/osgi_bundle_status | wc -l) == 0 ]] || [[ $(cat /tmp/osgi_bundle_status | wc -l) != $(cat /tmp/osgi_bundle_status | grep -i "active\|resolved" | wc -l) ]]; then
            exit 1
        fi
    else
        exit 1
    fi
else
    if [[ -f "/opt/idempiere/.unhealthy" ]]; then
        exit 1
    fi
fi

exit 0
