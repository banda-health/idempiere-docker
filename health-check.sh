#!/usr/bin/env bash

if [[ $HEALTHY_AFTER_PLUGINS_START == "true" ]]; then
    if [[ -f "$IDEMPIERE_HOME/banda/bundles" ]]; then
        rm -f /tmp/osgi_bundle_status
        touch /tmp/osgi_bundle_status
        eval "$(cat $IDEMPIERE_HOME/banda/bundles)" | telnet localhost 12612 2>&1 | grep -i "_" >> /tmp/osgi_bundle_status
        if [[ $(cat /tmp/osgi_bundle_status | wc -l) == 0 ]] || [[ $(cat /tmp/osgi_bundle_status | wc -l) != $(cat /tmp/osgi_bundle_status | grep -i "active\|resolved" | wc -l) ]]; then
            exit 1
        fi
    else
        exit 1
    fi
else
    if [[ -f "$IDEMPIERE_HOME/.unhealthy" ]]; then
        exit 1
    fi
fi

exit 0
