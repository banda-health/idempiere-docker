#!/usr/bin/env bash

echo "Installing sources..."

# Copy the plugins to the plugin directory, if there are any
rm -rf "$IDEMPIERE_HOME/banda"
if [[ -d "$INSTALLATION_HOME/plugins" ]] && [[ $(ls "$INSTALLATION_HOME/plugins" | wc -l) > 0 ]]; then
    echo "Copying plugins..."
    cp -r "$INSTALLATION_HOME/plugins/." "$IDEMPIERE_HOME/plugins"
    # Create commands to run through telnet so we can make sure all plugins are active or resolved!
    echo "Creating commands to check plugin activity..."
    mkdir "$IDEMPIERE_HOME/banda"
    touch "$IDEMPIERE_HOME/banda/bundles"
    ls "$INSTALLATION_HOME/plugins" | sed 's/\(.*\)\(-..\?\...\?\...\?-SNAPSHOT\.jar\)/echo ss \1/' > "$IDEMPIERE_HOME/banda/bundles"
    echo "sleep 1" >> "$IDEMPIERE_HOME/banda/bundles"

    # Generate bundle info, if need be
    if [[ -f "$IDEMPIERE_HOME/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info" ]]; then
        if [[ $GENERATE_PLUGIN_BUNDLE_INFO == "true" ]]; then
            echo "Adding plugins to bundles.info..."
            ls "$INSTALLATION_HOME/plugins" | sed 's/\(.*\)\(-..\?\...\?\...\?-SNAPSHOT\.jar\)/\1,1.0.0,plugins\/\1\2,4,false/' | sed 's/\(.*test.*\),4,false/\1,5,true/' >> "$IDEMPIERE_HOME/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info"
            # Make sure the "rest" plugin is set to auto-start
            sed -i 's/\(banda.*rest,.*\)4,false/\14,true/' "$IDEMPIERE_HOME/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info"
            # Make sure the "graphql" plugin is set to auto-start
            sed -i 's/\(banda.*graphql,.*\)4,false/\14,true/' "$IDEMPIERE_HOME/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info"
        elif [[ -f "$INSTALLATION_HOME/bundles.info" ]]; then
            echo "Ensuring bundles installed..."
            cat "$INSTALLATION_HOME/bundles.info" >>"$IDEMPIERE_HOME/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info"
        else
            echo "No plugins to auto-start..."
        fi
    else
        echo "No iDempiere bundles config found..."
    fi

    if [[ $REMOVE_SOURCES_AFTER_COPY == "true" ]]; then
        echo "Removing source plugins after copy..."
        rm -fr "$INSTALLATION_HOME/plugins"
    fi
fi

# Copy the reports, if there are any
if [[ -d "$INSTALLATION_HOME/reports" ]]; then
    echo "Copying reports..."
    cp -R "$INSTALLATION_HOME/reports" "$IDEMPIERE_HOME"

    if [[ $REMOVE_SOURCES_AFTER_COPY == "true" ]]; then
        echo "Removing source reports after copy..."
        rm -rf "$INSTALLATION_HOME/reports"
    fi
fi

# Copy any data
if [[ -d "$INSTALLATION_HOME/data" ]]; then
    echo "Copying data..."
    cp -R "$INSTALLATION_HOME/data" "$IDEMPIERE_HOME"

    if [[ $REMOVE_SOURCES_AFTER_COPY == "true" ]]; then
        echo "Removing source data after copy..."
        rm -fr "$INSTALLATION_HOME/data"
    fi
fi

# Copy any migrations
if [[ -d "$INSTALLATION_HOME/migration" ]]; then
    echo "Copying migrations..."
    cp -R "$INSTALLATION_HOME/migration" "$IDEMPIERE_HOME"

    if [[ $REMOVE_SOURCES_AFTER_COPY == "true" ]]; then
        echo "Removing source migrations after copy..."
        rm -fr "$INSTALLATION_HOME/migration"
    fi
fi

echo "Finished installing sources!"
