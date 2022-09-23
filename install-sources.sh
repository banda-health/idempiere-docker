#!/usr/bin/env bash

echo "Installing sources..."

# Copy the plugins to the plugin directory, if there are any
rm /tmp/bundles > /dev/null 2>&1 || true
if [[ -d "/home/src/plugins" ]] && [[ $(ls /home/src/plugins | wc -l) > 0 ]]; then
    echo "Copying plugins..."
    cp -r /home/src/plugins/* /opt/idempiere/plugins
    # Create commands to run through telnet so we can make sure all plugins are active or resolved!
    echo "Creating commands to check plugin activity..."
    touch /tmp/bundles
    ls /home/src/plugins | sed 's/\(.*\)\(-..\?\...\?\...\?-SNAPSHOT\.jar\)/echo ss \1/' > /tmp/bundles
    echo "sleep 1" >> /tmp/bundles

    # Generate bundle info, if need be
    if [[ -f "/opt/idempiere/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info" ]]; then
        if [[ $GENERATE_PLUGIN_BUNDLE_INFO == "true" ]]; then
            echo "Adding plugins to bundles.info..."
            ls /home/src/plugins | sed 's/\(.*\)\(-..\?\...\?\...\?-SNAPSHOT\.jar\)/\1,1.0.0,plugins\/\1\2,4,false/' | sed 's/\(.*test.*\),4,false/\1,5,true/' >> /opt/idempiere/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info
            # Make sure the "rest" plugin is set to auto-start
            sed -i 's/\(banda.*rest,.*\)4,false/\14,true/' /opt/idempiere/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info
        elif [[ -f "/home/src/bundles.info" ]]; then
            echo "Ensuring bundles installed..."
            cat /home/src/bundles.info >>/opt/idempiere/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info
        else
            echo "No plugins to auto-start..."
        fi
    else
        echo "No iDempiere bundles config found..."
    fi

    if [[ $REMOVE_SOURCES_AFTER_COPY == "true" ]]; then
        echo "Removing source plugins after copy..."
        rm -r /home/src/plugins/*
    fi
fi

# Copy the reports, if there are any
if [[ -d "/home/src/reports" ]]; then
    echo "Copying reports..."
    cp -R /home/src/reports /opt/idempiere

    if [[ $REMOVE_SOURCES_AFTER_COPY == "true" ]]; then
        echo "Removing source reports after copy..."
        rm -r /home/src/reports/*
    fi
fi

# Copy any data
if [[ -d "/home/src/data" ]]; then
    echo "Copying data..."
    cp -R /home/src/data /opt/idempiere

    if [[ $REMOVE_SOURCES_AFTER_COPY == "true" ]]; then
        echo "Removing source data after copy..."
        rm -r /home/src/data/*
    fi
fi

echo "Finished installing sources!"
